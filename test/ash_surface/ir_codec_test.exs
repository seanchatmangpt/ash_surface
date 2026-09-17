defmodule AshSurface.IrCodecTest do
  @moduledoc """
  State rows of the single-canon reconciliation (chicago-codec-canon-034):
  `AshSurface.IR.Codec` round-trips the REAL five-section IR assembled by
  `AshSurface.Compiler.compile` from a live fixture (the real shared
  `AshSurface.Fixtures.VolunteerMilestone` resource), in both directions, and
  its digest canon is pinned to the fixture surface's own digest.

  No test doubles: manifest generation, surface verification, IR assembly,
  and the codec under test are the real admitted subjects; assertions hit
  returned values only. The declared sub-shape row feeds a real
  `AshSurface.IR` struct to the pure staging law — it is an input, not a
  stand-in for the subject.

  The former subject of this suite — the codec's parallel
  `AshSurface.IR.Surface` staging struct (`actions | identity | profile |
  resources | transports`) and its fail-closed reader — is retired: there is
  ONE IR canon (`AshSurface.IR`) and one codec for it. Unknown-key tolerance
  is the admitted `from_map/1` law (golden suite pins it); what stays
  fail-closed is typed: non-map subjects, missing sections, wrong-typed
  values, and non-JSON-isomorphic leaves are refused.

  Falsifier on record: introduce key-order dependence into `digest/1`'s
  canonical term (invert the key sort, so the preimage carries assembly order
  instead of the normalized key order) and the row
  "digest pinned to the fixture surface digest" goes RED — the codec stops
  agreeing with `AshSurface`'s own sorted canon; restore the sort and it goes
  GREEN. (Merely dropping the sort was tried first and is invisible on this
  runtime: flatmaps iterate key-sorted and >32-key HAMT order is a function
  of the key set, so construction history never reaches the preimage — the
  inversion is the minimal mutation that makes key order observable.)
  """

  use ExUnit.Case, async: false

  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.IR
  alias AshSurface.IR.Codec

  # Deliberately not id-sorted: the codec rows below must hold regardless of
  # assembly order (the compiler id-sorts; the codec never depends on it).
  @entrypoints [
    {VolunteerMilestone, :record},
    {VolunteerMilestone, :read}
  ]

  describe "one canon" do
    test "the codec serves the admitted five-section IR; the parallel staging struct is retired" do
      assert IR.sections() == [:ash, :semantic, :capability, :presentation, :schema]
      assert match?({:error, :nofile}, Code.ensure_loaded(AshSurface.IR.Surface))
    end
  end

  describe "round-trip of the real five-section IR from a live fixture (both directions)" do
    test "struct -> staging map -> struct closes, with recomputed digest agreement" do
      for ir <- live_irs!() do
        staged = Codec.to_map(ir)

        assert Map.keys(staged) == ~w(ash capability presentation schema semantic version)

        assert {:ok, rebuilt} = Codec.from_map(staged)

        # Direction 1: the staging map is a fixed point of the round trip.
        assert Codec.to_map(rebuilt) == staged

        # from_map recomputes the digest from the admitted content.
        assert rebuilt.digest == Codec.digest(staged)

        # The five sections come back as admitted: honestly nil when the real
        # compile admitted no facts (the bare fixture carries only the ash
        # section), the declared struct when present.
        for section <- IR.sections() do
          value = Map.get(rebuilt, section)

          assert value == nil or value.__struct__ == IR.section(section),
                 "expected #{section} to be nil or an admitted #{inspect(IR.section(section))}"
        end

        assert %IR.Ash{} = rebuilt.ash
        assert rebuilt.version == ir.version
      end
    end

    test "direction 2: from_map(to_map(ir)) is an exact involution on rebuilt IRs" do
      for ir <- live_irs!() do
        {:ok, rebuilt} = Codec.from_map(Codec.to_map(ir))
        assert {:ok, ^rebuilt} = Codec.from_map(Codec.to_map(rebuilt))
      end
    end

    test "the real IR's staging map is byte-stable JSON across decode/re-encode" do
      for ir <- live_irs!() do
        staged = Codec.to_map(ir)
        json = Jason.encode!(staged)

        assert {:ok, from_json} = Codec.from_map(Jason.decode!(json))
        assert Codec.to_map(from_json) == staged
        assert from_json.digest == Codec.digest(staged)
      end
    end

    test "staging renders the real ash section's admitted facts (atoms as source-alias strings)" do
      irs = live_irs!()
      by_id = Enum.map(irs, &{&1.ash.action, &1}) |> Map.new()

      assert MapSet.new(Map.keys(by_id)) == MapSet.new([:read, :record])

      for {action, ir} <- by_id do
        ash = Codec.to_map(ir)["ash"]

        assert ash["resource"] == "AshSurface.Fixtures.VolunteerMilestone"
        assert ash["action"] == Atom.to_string(action)
        assert ash["action_type"] == Atom.to_string(ir.ash.action_type)
        assert is_list(ash["inputs"]) and is_list(ash["policies"])
      end
    end

    test "declared sub-shapes stage to field-complete string-keyed maps" do
      ir = %IR{
        version: "26.9.17",
        ash: %IR.Ash{
          resource: VolunteerMilestone,
          action: :record,
          action_type: :create,
          inputs: [%IR.Input{name: :member_id, type: "string", required: true, default: nil}],
          outputs: [%IR.Output{returns: :string}],
          policies: [
            %IR.Policy{
              bypass: false,
              conditions: [%{check: "action_types", opts: %{types: [:create]}}],
              checks: [%{check: "actor_present", kind: :simple}]
            }
          ]
        }
      }

      ash = Codec.to_map(ir)["ash"]

      assert ash["resource"] == "AshSurface.Fixtures.VolunteerMilestone"

      assert ash["inputs"] == [
               %{"name" => "member_id", "type" => "string", "required" => true, "default" => nil}
             ]

      assert ash["outputs"] == [%{"returns" => "string"}]

      assert ash["policies"] == [
               %{
                 "bypass" => false,
                 "conditions" => [
                   %{"check" => "action_types", "opts" => %{"types" => ["create"]}}
                 ],
                 "checks" => [%{"check" => "actor_present", "kind" => "simple"}]
               }
             ]

      # The staged map is admitted back, digest-agreeing and staging-stable.
      assert {:ok, rebuilt} = Codec.from_map(Codec.to_map(ir))
      assert rebuilt.digest == Codec.digest(Codec.to_map(ir))
      assert Codec.to_map(rebuilt) == Codec.to_map(ir)
    end
  end

  describe "digest pinned to the fixture surface digest" do
    test "the codec digest canon agrees with the live fixture surface's own digest" do
      surface = surface!()
      assert surface.digest =~ ~r/^[0-9a-f]{64}$/
      assert Codec.digest(surface.contract) == surface.digest
    end

    test "codec digests of the real staging maps are deterministic and 64-char lowercase hex" do
      for ir <- live_irs!() do
        staged = Codec.to_map(ir)
        digest = Codec.digest(staged)

        assert digest =~ ~r/^[0-9a-f]{64}$/
        assert Enum.uniq(for(_ <- 1..7, do: Codec.digest(staged))) == [digest]
      end
    end

    test "content-addresses content, not map construction history (falsifier target)" do
      staged = Codec.to_map(hd(live_irs!()))

      # Construction history of the staging map itself is irrelevant.
      shuffled = staged |> Map.to_list() |> Enum.reverse() |> Map.new()
      assert Codec.digest(shuffled) == Codec.digest(staged)

      # A >32-key member crosses the flatmap/HAMT boundary: iteration order of
      # a hash-array-mapped trie must not move the digest.
      wide = Map.new(1..40, &{"pred_#{String.pad_leading(Integer.to_string(&1), 2, "0")}", &1})
      assert map_size(wide) > 32

      reversed_wide = wide |> Enum.reverse() |> Map.new()

      # The real fixture admits no semantic facts, so the section is honestly
      # nil; the wide map replaces it wholesale (a declared-field subset —
      # forward-tolerant readers admit it).
      with_wide = Map.put(staged, "semantic", %{"predicates" => wide})

      assert Codec.digest(Map.put(staged, "semantic", %{"predicates" => reversed_wide})) ==
               Codec.digest(with_wide)

      # and the wide map is still admitted by the reader, digest-agreeing on
      # the canonical (field-complete) re-staging.
      assert {:ok, rebuilt} = Codec.from_map(with_wide)
      assert rebuilt.digest == Codec.digest(Codec.to_map(rebuilt))
    end
  end

  describe "from_map typed refusals over the real staging map" do
    test "non-map subjects are refused" do
      for bad <- [:nope, "nope", 42, nil, [ash: nil]] do
        assert {:error, {:ir_map_required, ^bad}} = Codec.from_map(bad)
      end
    end

    test "missing section keys are named" do
      staged = Codec.to_map(hd(live_irs!()))
      dropped = Map.drop(staged, ["presentation", "semantic"])

      assert {:error, {:missing_ir_sections, ["presentation", "semantic"]}} =
               Codec.from_map(dropped)
    end

    test "sections that are neither maps nor nil are typed-rejected" do
      staged = Codec.to_map(hd(live_irs!()))

      assert {:error, {:section_must_be_map_or_nil, "schema", "nope"}} =
               Codec.from_map(Map.put(staged, "schema", "nope"))
    end

    test "non-JSON-isomorphic leaves are typed-rejected (staging never fabricates)" do
      staged = Codec.to_map(hd(live_irs!()))

      poisoned = Map.put(staged, "semantic", %{"predicates" => %{"tuple" => {:ok, :tuple}}})

      assert {:error, {:not_json_isomorphic, "semantic", {:ok, :tuple}}} =
               Codec.from_map(poisoned)
    end

    test "forward tolerance: unknown keys and a carried digest are ignored" do
      staged = Codec.to_map(hd(live_irs!()))

      future =
        Map.merge(staged, %{
          "futureFacet" => %{"x" => 1},
          "digest" => String.duplicate("0", 64)
        })

      assert {:ok, plain} = Codec.from_map(staged)
      assert {:ok, ^plain} = Codec.from_map(future)
    end

    test "wrong-typed version is typed-rejected" do
      staged = Codec.to_map(hd(live_irs!()))

      assert {:error, {:version_must_be_string_or_nil, 26.9}} =
               Codec.from_map(Map.put(staged, "version", 26.9))
    end
  end

  ## helpers

  # The real manufacturing pass over the live fixture: manifest generation
  # from the compiled Ash resource, then surface verification.
  defp surface! do
    assert {:ok, manifest} =
             Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: @entrypoints)

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})
    surface
  end

  # The real five-section IRs: the compiler's assembly over the fixture's
  # manifest, one IR per action, id-sorted.
  defp live_irs! do
    surface = surface!()
    assert {:ok, irs} = AshSurface.Compiler.compile(surface.manifest)
    assert length(irs) == 2
    assert Enum.map(irs, & &1.ash.action) == [:read, :record]
    irs
  end
end
