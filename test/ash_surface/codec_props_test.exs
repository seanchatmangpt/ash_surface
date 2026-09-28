defmodule AshSurface.CodecPropsTest do
  @moduledoc """
  Property-based codec/digest laws (chicago-props-codec-042), Chicago school:
  the REAL subjects are exercised — `AshSurface.CanonicalJSON`
  (lib/ash_surface/canonical_json.ex) and `AshSurface.IR.Codec`
  (lib/ash_surface/ir/codec.ex) — with no test doubles, and every assertion
  lands on an observable outcome: returned bytes, returned digests, returned
  `{:ok, ir}` values. Generators are bounded (depth, length, magnitude), and
  runs are seeded-stable: a fixed `--seed` reproduces the same cases.

  The three laws:

    1. Canonical key-order invariance — two construction histories of the
       same structurally-equal map (shuffled-key insertion, crossing the
       32-key flatmap/HAMT boundary) always yield identical canonical JSON
       bytes and identical digests. Construction history can never leak into
       a digest.
    2. Value sensitivity — changing any single value (at any depth, via the
       total deterministic `mutate/1`) always moves the canonical bytes and
       the digest: these are content addresses, not shape addresses.
    3. Five-section IR round-trip identity — over bounded generators of
       realistic section shapes (ash resource projections, semantic IRIs and
       digests, capability authority boundaries and refusals, presentation
       audience/flags, transport selections), `from_map/1` admits shuffled
       insertion orders to one identical struct, `from_map(to_map(ir))` is
       `{:ok, ir}` with the digest field in agreement, and a real Jason
       byte round-trip preserves the IR structurally.

  Falsifier discipline (executed in ticket History): injecting
  order-dependence into `CanonicalJSON.encode/1` (dropping the key sort)
  turns property 1 RED; restoring the sort turns it GREEN. The RED is
  carried by the sortedness pin inside property 1: on OTP 26+ the VM
  iterates maps in content-determined term order, so equality between two
  construction histories alone cannot see a dropped sort — the pin's
  mixed-type-key map (VM term order ≠ stringified-sorted order) can.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.CanonicalJSON
  alias AshSurface.IR.Codec
  alias AshSurface.IR

  # build_section atomizes field names against existing atoms; the section
  # struct modules load lazily, so force-load them before generated sections
  # reach the codec (034 law: atomization is binary_to_existing_atom).
  setup do
    Enum.each(
      [IR.Ash, IR.Semantic, IR.Capability, IR.Presentation, IR.Schema],
      &Code.ensure_loaded!/1
    )

    :ok
  end

  @section_keys ~w(ash capability presentation schema semantic)
  @max_runs 100

  # ────────────────────────────────────────────────────────────────────────
  # Bounded generators
  # ────────────────────────────────────────────────────────────────────────

  # Key space small enough to collide harmlessly, large enough that 2..40
  # pairs yield mostly-distinct keys. Zero-padded so lexicographic and
  # numeric orders differ — the sort cannot hide behind single digits.
  # Mixed key TYPES (integer / atom / binary) are load-bearing: since
  # OTP 26 small maps iterate in TERM order (integers < atoms < binaries),
  # which differs from the stringified-sorted order the encode law demands,
  # so a dropped key sort is observable rather than silently absorbed.
  defp json_key do
    one_of([
      map(integer(1..500), fn n -> "k" <> String.pad_leading(Integer.to_string(n), 3, "0") end),
      integer(1..500),
      map(integer(1..50), fn n ->
        String.to_atom("a" <> String.pad_leading(Integer.to_string(n), 3, "0"))
      end)
    ])
  end

  defp json_scalar do
    one_of([
      integer(-1_000_000..1_000_000),
      # Bounded magnitude: within ±1.0e6 the ulp is far below 1.0, so
      # mutate/1's +1.0 bump is guaranteed to change the value.
      float(min: -1.0e6, max: 1.0e6),
      boolean(),
      constant(nil),
      string(:printable, max_length: 16)
    ])
  end

  defp json_value(0), do: json_scalar()

  defp json_value(depth) do
    frequency([
      {5, json_scalar()},
      {2, list_of(json_value(depth - 1), max_length: 3)},
      {2, map(list_of({json_key(), json_value(depth - 1)}, max_length: 4), &Map.new/1)}
    ])
  end

  # Distinct keys zipped one-to-one with values: Map.new over any permutation
  # of these pairs yields structurally equal maps.
  defp distinct_pairs do
    bind(uniq_list_of(json_key(), min_length: 2, max_length: 40), fn keys ->
      map(list_of(json_value(2), length: length(keys)), fn values ->
        Enum.zip(keys, values)
      end)
    end)
  end

  defp maybe(gen), do: frequency([{1, constant(nil)}, {4, gen}])

  # An honest five-section pair list in a generated rotation — insertion
  # order varies, content stays realistic. from_map/1 must admit any order.
  defp ir_sections do
    gen all(
          ash <-
            maybe(section(["action", "action_type", "inputs", "outputs", "policies", "resource"])),
          semantic <-
            maybe(
              section(["capability_iri", "ontology", "predicates", "shape_id", "subject_iri"])
            ),
          capability <-
            maybe(
              section([
                "authority_required",
                "capability_id",
                "consequence_class",
                "receipt_required"
              ])
            ),
          presentation <- maybe(section(["format", "group", "label", "order", "widget"])),
          schema <- maybe(section(["aria", "input", "output", "zod"])),
          rotation <- integer(0..4)
        ) do
      sections = [
        {"ash", ash},
        {"semantic", semantic},
        {"capability", capability},
        {"presentation", presentation},
        {"schema", schema}
      ]

      Enum.drop(sections, rotation) ++ Enum.take(sections, rotation)
    end
  end

  # One admitted-canon section generator: every codec-declared field drawn from
  # the bounded JSON value generator (fields may be any JSON term; the codec
  # stages them nil-honestly and ignores unknowns).
  #
  # The scalar facts projectors read (`resource`, `action`, `action_type`,
  # `order`, `aria`) are typed at the decode boundary
  # (`Codec.validate_facts/1`), so they are drawn from their declared domains;
  # the refusal of wrong-typed values is pinned in `fuzz_ir_codec_test.exs`.
  defp section(fields) do
    gen all(values <- fields |> Enum.map(&fact/1) |> fixed_list()) do
      fields |> Enum.zip(values) |> Map.new()
    end
  end

  defp fact(name) when name in ["resource", "action", "action_type"],
    do: one_of([constant(nil), string(:alphanumeric, max_length: 8)])

  defp fact("order"), do: one_of([constant(nil), integer(0..99)])

  defp fact("aria"),
    do:
      one_of([
        constant(nil),
        map(list_of({member_of(["role", "live"]), json_iso(1)}, max_length: 2), &Map.new/1)
      ])

  defp fact(_name), do: json_iso(2)

  # JSON-isomorphic terms only (string keys): the codec's require_section_shapes
  # refuses atom-keyed maps as non-staging shapes (034 law).
  defp json_iso(0), do: json_scalar()

  defp json_iso(depth) do
    frequency([
      {5, json_scalar()},
      {2, list_of(json_iso(depth - 1), max_length: 3)},
      {2,
       map(
         list_of(
           {map(integer(1..500), fn n ->
              "k" <> String.pad_leading(Integer.to_string(n), 3, "0")
            end), json_iso(depth - 1)},
           max_length: 4
         ),
         &Map.new/1
       )}
    ])
  end

  # ────────────────────────────────────────────────────────────────────────
  # The deterministic total mutation behind property 2: same structural
  # position, different canonical bytes. Recursion descends the first
  # element/key; leaves are bumped in a way Jason cannot confuse.
  # ────────────────────────────────────────────────────────────────────────

  defp mutate(map) when is_map(map) and map_size(map) > 0 do
    [{key, value} | _rest] = Enum.to_list(map)
    Map.put(map, key, mutate(value))
  end

  defp mutate(map) when is_map(map), do: %{"δ" => 1}

  defp mutate([head | tail]), do: [mutate(head) | tail]
  defp mutate([]), do: [1]

  defp mutate(binary) when is_binary(binary), do: binary <> "!"
  defp mutate(int) when is_integer(int), do: int + 1
  defp mutate(float) when is_float(float), do: float + 1.0
  defp mutate(true), do: false
  defp mutate(false), do: true
  defp mutate(nil), do: false

  # ────────────────────────────────────────────────────────────────────────
  # Properties
  # ────────────────────────────────────────────────────────────────────────

  property "canonical key-order invariance: shuffled-key maps yield identical CanonicalJSON bytes and digest" do
    # 2..40 pairs crosses the 32-key flatmap/HAMT boundary; reverse is a
    # deterministic permutation of construction history.
    check all(
            # distinct_keys/0: distinct keys zipped one-to-one with values, so
            # both Map.new constructions are structurally equal maps (the
            # law's precondition).
            pairs <- distinct_pairs(),
            max_runs: @max_runs
          ) do
      shuffled = Map.new(pairs)
      reversed = Map.new(Enum.reverse(pairs))

      assert shuffled == reversed,
             "generator invariant: both constructions are structurally equal"

      assert CanonicalJSON.encode(shuffled) == CanonicalJSON.encode(reversed),
             "canonical bytes must not depend on map construction history"

      assert CanonicalJSON.sha256_hex(shuffled) == CanonicalJSON.sha256_hex(reversed),
             "the digest must not depend on map construction history"

      # Sortedness pin (falsifier load-bearing element). On OTP 26+ the VM
      # iterates maps in content-determined order, so the shuffled/reversed
      # equality alone cannot detect a dropped key sort: the runtime already
      # normalizes history away. The pin observes the law DIRECTLY — a fixed
      # mixed-type-key map whose VM term order (2, 10, :b, "1", "a") differs
      # from the stringified-sorted order — asserting the exact canonical
      # bytes and digest the sort produces. Drop the sort and this goes RED.
      pinned = Map.new([{2, 1}, {10, 4}, {"1", 2}, {"a", 5}, {:b, 3}])

      assert CanonicalJSON.encode(pinned) == ~s({"1":2,"10":4,"2":1,"a":5,"b":3}),
             "canonical bytes must emit keys in ascending stringified order"

      assert CanonicalJSON.sha256_hex(pinned) ==
               "f2162ce0c3e343ede5ed732f512c7fda756281fbf4333b45258cff43fd373536",
             "the digest content-addresses the sorted canonical bytes"
    end
  end

  property "value sensitivity: any single value change moves the CanonicalJSON bytes and digest" do
    check all(value <- json_value(3), max_runs: @max_runs) do
      mutated = mutate(value)

      assert CanonicalJSON.encode(mutated) != CanonicalJSON.encode(value),
             "a changed value must change the canonical bytes"

      assert CanonicalJSON.sha256_hex(mutated) != CanonicalJSON.sha256_hex(value),
             "a changed value must change the digest"
    end
  end

  property "five-section IR round-trip identity over bounded realistic generators" do
    check all(sections <- ir_sections(), max_runs: @max_runs) do
      # Order-invariant admission: two construction histories of the same
      # five-section map yield one identical struct, digest included.
      assert {:ok, %IR{} = ir} = Codec.from_map(Map.new(sections))
      assert {:ok, reversed_ir} = Codec.from_map(Map.new(Enum.reverse(sections)))
      assert ir == reversed_ir, "admission must not depend on section insertion order"

      # The digest field content-addresses the canonical map.
      assert ir.digest == Codec.digest(Codec.to_map(ir))

      # Round-trip identity through the codec's own projection.
      assert {:ok, ^ir} = Codec.from_map(Codec.to_map(ir))

      # A real Jason byte round-trip preserves the IR structurally.
      json = Jason.encode!(Codec.to_map(ir))
      assert {:ok, ^ir} = Codec.from_map(Jason.decode!(json))

      # The projection is the canonical sorted five-key map, digest-free.
      assert Map.keys(Codec.to_map(ir)) == Enum.sort(@section_keys ++ ["version"])
      refute Map.has_key?(Codec.to_map(ir), "digest")
    end
  end
end
