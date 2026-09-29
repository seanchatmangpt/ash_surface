defmodule AshSurface.FuzzIRCodecTest do
  @moduledoc """
  Decode-boundary fuzzing of `AshSurface.IR.Codec.from_map/1`, the untrusted
  entry point for every staged IR (Chicago school: the real codec, no doubles,
  observable outcomes only).

  Laws pinned:

    1. `from_map/1` is total over ARBITRARY terms: it returns `{:ok, %IR{}}`
       or `{:error, _}` and never raises, whatever JSON-ish nesting, junk term
       (tuples, pids, refs, funs, invalid UTF-8, improper lists, structs) or
       non-string key it is handed.
    2. Whatever it admits is canonical: the recomputed digest is 64 lowercase
       hex, and `to_map/1 |> from_map/1` reproduces the identical IR (an
       admitted value is a fixed point of the codec).
    3. An admitted IR's canonical map is real JSON: it survives a Jason byte
       round-trip to an equal canonical map.

  Bounded: 300 cases per property, well under the 20s file budget.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.IR
  alias AshSurface.IR.Codec

  setup do
    Enum.each(
      [IR.Ash, IR.Semantic, IR.Capability, IR.Presentation, IR.Schema],
      &Code.ensure_loaded!/1
    )

    :ok
  end

  @runs 300
  @sections ~w(ash capability presentation schema semantic)
  @known_fields ~w(action action_type inputs outputs policies resource authority_required
                   capability_id consequence_class receipt_required format group label order
                   widget aria input output zod capability_iri ontology predicates shape_id
                   subject_iri)

  defp junk_leaf do
    one_of([
      integer(),
      float(),
      boolean(),
      constant(nil),
      atom(:alphanumeric),
      string(:printable, max_length: 12),
      binary(max_length: 8),
      constant(<<0xFF, 0xFE>>),
      constant({:a, "tuple"}),
      constant(self()),
      constant(make_ref()),
      constant(&Function.identity/1),
      constant(DateTime.from_unix!(0)),
      constant(MapSet.new([1])),
      constant(%IR.Input{name: :a, type: :string, required: true, default: nil})
    ])
  end

  defp key do
    one_of([
      member_of(@known_fields),
      string(:alphanumeric, max_length: 6),
      atom(:alphanumeric),
      integer(0..5),
      constant({:k, 1})
    ])
  end

  defp term(0), do: junk_leaf()

  defp term(depth) do
    frequency([
      {4, junk_leaf()},
      {2, list_of(term(depth - 1), max_length: 3)},
      {2, map(list_of({key(), term(depth - 1)}, max_length: 4), &Map.new/1)}
    ])
  end

  # JSON-isomorphic only (binary keys, UTF-8 leaves): the shape the codec is
  # designed to admit.
  defp json(0) do
    one_of([
      integer(),
      float(min: -1.0e6, max: 1.0e6),
      boolean(),
      constant(nil),
      string(:printable, max_length: 12)
    ])
  end

  defp json(depth) do
    frequency([
      {4, json(0)},
      {2, list_of(json(depth - 1), max_length: 3)},
      {2,
       map(
         list_of({string(:alphanumeric, max_length: 6), json(depth - 1)}, max_length: 3),
         &Map.new/1
       )}
    ])
  end

  defp json_section do
    frequency([
      {1, constant(nil)},
      {4,
       map(list_of({member_of(@known_fields ++ ["extra"]), json(2)}, max_length: 8), &Map.new/1)}
    ])
  end

  defp ir_map(section_gen) do
    gen all(
          sections <- list_of(section_gen, length: 5),
          version <- one_of([constant(nil), string(:alphanumeric, max_length: 8), integer()]),
          drop <- list_of(member_of(@sections ++ ["version"]), max_length: 1),
          extra <-
            map(
              list_of({string(:alphanumeric, max_length: 5), term(1)}, max_length: 2),
              &Map.new/1
            )
        ) do
      @sections
      |> Enum.zip(sections)
      |> Map.new()
      |> Map.put("version", version)
      |> Map.drop(drop)
      |> Map.merge(extra, fn k, v, _ -> if k in @sections, do: v, else: v end)
    end
  end

  property "from_map/1 is total over arbitrary terms (never raises)" do
    check all(input <- term(3), max_runs: @runs) do
      assert match?({:ok, %IR{}}, Codec.from_map(input)) or
               match?({:error, _}, Codec.from_map(input))
    end
  end

  property "from_map/1 is total over near-canonical maps salted with junk terms" do
    check all(input <- ir_map(term(2)), max_runs: @runs) do
      assert match?({:ok, %IR{}}, Codec.from_map(input)) or
               match?({:error, _}, Codec.from_map(input))
    end
  end

  property "admitted maps are canonical fixed points with a hex digest and real JSON bytes" do
    check all(input <- ir_map(json_section()), max_runs: @runs) do
      case Codec.from_map(input) do
        {:ok, %IR{} = ir} ->
          assert ir.digest =~ ~r/\A[0-9a-f]{64}\z/
          assert {:ok, ^ir} = Codec.from_map(Codec.to_map(ir))
          assert Codec.digest(Codec.to_map(ir)) == ir.digest

          canonical = Codec.to_map(ir)
          assert canonical |> Jason.encode!() |> Jason.decode!() |> Codec.from_map() == {:ok, ir}

        {:error, _reason} ->
          :ok
      end
    end
  end

  test "the generators are not vacuous: they reach both admission and refusal" do
    outcomes =
      json_section()
      |> ir_map()
      |> Enum.take(200)
      |> Enum.map(&elem(Codec.from_map(&1), 0))
      |> Enum.frequencies()

    assert outcomes[:ok] > 20
    assert outcomes[:error] > 5

    junk =
      term(2) |> Enum.take(200) |> Enum.map(&elem(Codec.from_map(&1), 0)) |> Enum.frequencies()

    assert junk[:error] > 100
  end

  test "an improper list inside a section is a typed rejection, not a raise" do
    input = %{
      "ash" => %{"action" => [1 | 2]},
      "capability" => nil,
      "presentation" => nil,
      "schema" => nil,
      "semantic" => nil,
      "version" => nil
    }

    assert {:error, _} = Codec.from_map(input)
  end

  test "non-map inputs are typed rejections, not raises" do
    for input <- [nil, 1, "x", [], [%{}], :atom, {:t}, %IR{}] do
      assert {:error, _} = Codec.from_map(input)
    end
  end
end
