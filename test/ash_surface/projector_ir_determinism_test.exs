defmodule AshSurface.ProjectorIRDeterminism.IR do
  @moduledoc false

  # Test-local double for the absent lib/ash_surface/ir.ex sibling: a
  # normalized intermediate representation between a verified surface and the
  # projectors that consume it, with a canonical (map-order invariant) digest.
  # To be replaced wholesale when the real module is admitted; until then it
  # exists only to pin the determinism contract IR consumers may rely on.

  @enforce_keys [:version, :nodes, :presentation, :digest]
  defstruct [:version, :nodes, :presentation, :digest]

  @ir_version "ir.26.9.15"

  def from_surface(%AshSurface.Surface{} = surface) do
    actions = get_in(surface.contract, ["surface", "actions"]) || []

    nodes =
      Enum.map(actions, fn action ->
        %{
          "id" => action["id"],
          "semanticId" => action["semanticId"],
          "resource" => action["resource"],
          "action" => action["action"],
          "authorityBoundary" => action["authorityBoundary"],
          "doAuthority" => action["doAuthority"],
          "profile" => action["profile"] || %{}
        }
      end)

    presentation =
      case get_in(surface.contract, ["surface", "profile", "presentation"]) do
        p when is_map(p) -> p
        _ -> %{}
      end

    ir = %__MODULE__{
      version: @ir_version,
      nodes: nodes,
      presentation: presentation,
      digest: nil
    }

    %{ir | digest: digest(ir)}
  end

  # The presentation-declared order, with nodes the order does not mention
  # appended in sorted id order: deterministic fallback, never map order.
  def resolved_order(%__MODULE__{} = ir) do
    ids = Enum.map(ir.nodes, & &1["id"])
    id_set = MapSet.new(ids)

    ordered =
      ir
      |> presentation_order()
      |> Enum.filter(&MapSet.member?(id_set, &1))

    ordered ++ Enum.sort(MapSet.difference(id_set, MapSet.new(ordered)))
  end

  def presentation_order(%__MODULE__{} = ir) do
    case Map.get(ir.presentation, "order") do
      order when is_list(order) -> order
      _ -> ir.nodes |> Enum.map(& &1["id"]) |> Enum.sort()
    end
  end

  # Canonical digest mirroring AshSurface's private digest/1: recursively
  # string-keyed, key-sorted pairs, so construction history cannot leak in.
  def digest(%__MODULE__{} = ir) do
    %{version: ir.version, nodes: ir.nodes, presentation: ir.presentation}
    |> canonical()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # Canonical JSON with recursively sorted keys: identical bytes for any two
  # structurally equal maps, independent of map construction history (flatmap
  # or >32-key HAMT). finish-replay-020 promoted this encoder into lib; the
  # double now delegates so the suite pins the lib-owned law, not a local copy.
  def to_canonical_json(map) when is_map(map), do: AshSurface.CanonicalJSON.encode(map)

  def to_canonical_json(list) when is_list(list), do: AshSurface.CanonicalJSON.encode(list)

  def to_canonical_json(scalar), do: AshSurface.CanonicalJSON.encode(scalar)

  defp canonical(term) when is_map(term) do
    term
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp canonical(term) when is_list(term), do: Enum.map(term, &canonical/1)
  defp canonical(term), do: term
end

defmodule AshSurface.ProjectorIRDeterminism.ProjectorIR do
  @moduledoc false

  # Test-local double for the absent lib/ash_surface/projector/ir.ex sibling:
  # the JSON artifact kind. Emits one canonical-JSON document whose node list
  # follows presentation order exactly.

  @behaviour AshSurface.Projector

  def project(input, opts \\ [])

  @impl true
  def project(%AshSurface.Surface{} = surface, opts) do
    surface
    |> AshSurface.ProjectorIRDeterminism.IR.from_surface()
    |> project(opts)
  end

  def project(%AshSurface.ProjectorIRDeterminism.IR{} = ir, opts) do
    prefix = Keyword.get(opts, :prefix, "surface_ir")

    order = AshSurface.ProjectorIRDeterminism.IR.resolved_order(ir)
    nodes_by_id = Map.new(ir.nodes, &{&1["id"], &1})

    document = %{
      "version" => ir.version,
      "digest" => ir.digest,
      "order" => order,
      "nodes" => Enum.map(order, &nodes_by_id[&1]),
      "presentation" => ir.presentation
    }

    artifacts = %{
      "#{prefix}.ir.json" =>
        AshSurface.ProjectorIRDeterminism.IR.to_canonical_json(document) <> "\n"
    }

    write!(artifacts, Keyword.get(opts, :target_dir))

    {:ok, artifacts,
     %{kind: :ir_json, digest: ir.digest, order: order, node_count: length(order)}}
  end

  defp write!(_artifacts, nil), do: :ok

  defp write!(artifacts, dir) do
    File.mkdir_p!(dir)
    Enum.each(artifacts, fn {filename, body} -> File.write!(Path.join(dir, filename), body) end)
  end
end

defmodule AshSurface.ProjectorIRDeterminism.ProjectorIR.Descriptor do
  @moduledoc false

  # Test-local double: the text descriptor projector kind. Same ordering and
  # digest laws as the JSON kind, rendered as numbered human-readable lines.

  @behaviour AshSurface.Projector

  def project(input, opts \\ [])

  @impl true
  def project(%AshSurface.Surface{} = surface, opts) do
    surface
    |> AshSurface.ProjectorIRDeterminism.IR.from_surface()
    |> project(opts)
  end

  def project(%AshSurface.ProjectorIRDeterminism.IR{} = ir, opts) do
    prefix = Keyword.get(opts, :prefix, "surface_ir")

    order = AshSurface.ProjectorIRDeterminism.IR.resolved_order(ir)
    nodes_by_id = Map.new(ir.nodes, &{&1["id"], &1})

    numbered =
      order
      |> Enum.with_index(1)
      |> Enum.map(fn {id, index} ->
        node = nodes_by_id[id]

        "#{index}. #{node["id"]} :: #{node["semanticId"]} " <>
          "[#{node["authorityBoundary"]}] do=#{node["doAuthority"]}"
      end)

    lines = ["# ash_surface ir #{ir.version}", "digest: #{ir.digest}"] ++ numbered

    artifacts = %{"#{prefix}.ir.txt" => Enum.join(lines, "\n") <> "\n"}

    write!(artifacts, Keyword.get(opts, :target_dir))

    {:ok, artifacts,
     %{kind: :ir_descriptor, digest: ir.digest, order: order, node_count: length(order)}}
  end

  defp write!(_artifacts, nil), do: :ok

  defp write!(artifacts, dir) do
    File.mkdir_p!(dir)
    Enum.each(artifacts, fn {filename, body} -> File.write!(Path.join(dir, filename), body) end)
  end
end

defmodule AshSurface.ProjectorIRDeterminism.LedgerDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ProjectorIRDeterminism.Ledger)
  end
end

defmodule AshSurface.ProjectorIRDeterminism.Ledger do
  @moduledoc false

  use Ash.Resource,
    domain: AshSurface.ProjectorIRDeterminism.LedgerDomain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:member_id, :string, public?: true, allow_nil?: false)
    attribute(:entry, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])

    read(:list_all)
    create(:record)
  end
end

defmodule AshSurface.ProjectorIRDeterminismTest do
  @moduledoc """
  Determinism proofs for IR projection.

  The IR modules (`AshSurface.IR`, `AshSurface.Projector.IR`,
  `AshSurface.Projector.IR.Descriptor`) are test-local doubles declared inline
  because the lib siblings (ir.ex, projector/ir.ex) are absent; the projectors
  are driven through the real `AshSurface.project/3` seam where a surface is
  the input, and directly over one IR fixture elsewhere.

  Zero env, zero db, zero network: one IR fixture built through the real
  `Manifest.generate -> AshSurface.from_manifest` pass, artifacts materialized
  into per-test temporary directories.
  """

  use ExUnit.Case, async: false

  alias AshSurface.ProjectorIRDeterminism.IR
  alias AshSurface.ProjectorIRDeterminism.ProjectorIR, as: IRJson
  alias AshSurface.ProjectorIRDeterminism.ProjectorIR.Descriptor, as: IRDescriptor

  @prefix "surface_ir"
  @ledger "AshSurface.ProjectorIRDeterminism.Ledger"
  @entrypoints [
    {AshSurface.ProjectorIRDeterminism.Ledger, :record},
    {AshSurface.ProjectorIRDeterminism.Ledger, :list_all},
    {AshSurface.ProjectorIRDeterminism.Ledger, :read}
  ]

  # Deliberately not id-sorted: proves ordering follows presentation order,
  # not a sorted coincidence.
  @order ["#{@ledger}#record", "#{@ledger}#list_all", "#{@ledger}#read"]

  # The presentation map carries a >32-key member so canonical digesting and
  # canonical JSON cross the large-map (HAMT) iteration boundary.
  @profile %{
    "presentation" => %{
      "order" => @order,
      "wide" => Map.new(1..40, &{"presentation_key_#{&1}", "value_#{&1}"})
    },
    "actions" => %{
      "#{@ledger}#record" => %{
        "semanticId" => "zoe:ConstructLedger",
        "authorityBoundary" => "CONSTRUCT",
        "doAuthority" => false
      },
      # v26.9.16 delegation law (v10): these facts are DELEGATED by the
      # fixture profile, never derived from action type by the projector.
      "#{@ledger}#list_all" => %{
        "semanticId" => "ash:#{@ledger}#list_all",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false
      },
      "#{@ledger}#read" => %{
        "semanticId" => "ash:#{@ledger}#read",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false
      }
    }
  }

  @kinds [IRJson, IRDescriptor]

  @runs 7

  @tag :tmp_dir
  test "n runs of each projector kind over one ir fixture are byte-identical",
       %{tmp_dir: tmp_dir} do
    surface = surface!()
    ir = IR.from_surface(surface)

    # An independent full rebuild of the surface yields the same digest and
    # the same IR: the fixture itself is stable before projection begins.
    rebuilt = surface!()
    assert rebuilt.digest == surface.digest
    assert IR.from_surface(rebuilt) == ir

    for kind <- @kinds do
      runs =
        for i <- 1..@runs do
          dir = Path.join(tmp_dir, "#{inspect(kind)}_#{i}")

          assert {:ok, artifacts, meta} =
                   AshSurface.project(surface, kind, prefix: @prefix, target_dir: dir)

          {artifacts, meta, read_dir(dir)}
        end

      [{artifacts0, meta0, files0} | rest] = runs

      for {artifacts, meta, files} <- rest do
        assert artifacts == artifacts0
        assert meta == meta0
        assert files == files0
      end

      # On-disk bytes are exactly the in-memory artifact bytes: no strays.
      assert files0 == artifacts0
      assert Enum.sort(Map.keys(artifacts0)) == [expected_artifact(kind)]

      # Direct IR-level projection equals the surface-routed projection.
      assert {:ok, ^artifacts0, ^meta0} = kind.project(ir, prefix: @prefix)

      # Both projector kinds agree on the fixture's IR digest.
      assert meta0.digest == ir.digest
    end
  end

  test "structurally equal irs with permuted map ordering project identically" do
    ir = surface!() |> IR.from_surface()

    for rotation <- [0, 1, 2, 3, 5, 7] do
      permuted = %{
        ir
        | nodes: reorder_maps(ir.nodes, rotation),
          presentation: reorder_maps(ir.presentation, rotation)
      }

      # The variant differs only in map construction history, not in content.
      assert permuted.nodes == ir.nodes
      assert permuted.presentation == ir.presentation

      # The canonical digest is invariant under that history.
      assert IR.digest(permuted) == ir.digest

      for kind <- @kinds do
        assert {:ok, artifacts0, meta0} = kind.project(ir, prefix: @prefix)
        assert {:ok, ^artifacts0, ^meta0} = kind.project(permuted, prefix: @prefix)
      end
    end
  end

  test "output ordering follows presentation order deterministically" do
    ir = surface!() |> IR.from_surface()

    # Fixture guard: the declared order is not the sorted fallback.
    refute @order == Enum.sort(@order)
    assert IR.presentation_order(ir) == @order
    assert IR.resolved_order(ir) == @order

    assert {:ok, json_artifacts, json_meta} = IRJson.project(ir, prefix: @prefix)

    document = json_artifacts["#{@prefix}.ir.json"] |> Jason.decode!()

    assert document["order"] == @order
    assert Enum.map(document["nodes"], & &1["id"]) == @order
    assert document["digest"] == ir.digest
    assert json_meta.order == @order

    assert {:ok, txt_artifacts, txt_meta} = IRDescriptor.project(ir, prefix: @prefix)

    lines = txt_artifacts["#{@prefix}.ir.txt"] |> String.split("\n", trim: true)

    assert lines ==
             [
               "# ash_surface ir #{ir.version}",
               "digest: #{ir.digest}",
               "1. #{@ledger}#record :: zoe:ConstructLedger [CONSTRUCT] do=false",
               "2. #{@ledger}#list_all :: ash:#{@ledger}#list_all [OBSERVE] do=false",
               "3. #{@ledger}#read :: ash:#{@ledger}#read [OBSERVE] do=false"
             ]

    assert txt_meta.order == @order
  end

  test "permuting presentation order re-orders output and digests deterministically" do
    ir = surface!() |> IR.from_surface()

    results =
      for permutation <- permutations(@order) do
        presentation = %{ir.presentation | "order" => permutation}
        variant = %{ir | presentation: presentation}
        variant = %{variant | digest: IR.digest(variant)}

        # Order is content: changing it changes the IR identity. The identity
        # permutation is the original IR and keeps its digest.
        if permutation != @order do
          assert variant.digest != ir.digest
        end

        assert {:ok, json_artifacts, json_meta} = IRJson.project(variant, prefix: @prefix)
        assert {:ok, txt_artifacts, txt_meta} = IRDescriptor.project(variant, prefix: @prefix)

        document = json_artifacts["#{@prefix}.ir.json"] |> Jason.decode!()

        assert document["order"] == permutation
        assert Enum.map(document["nodes"], & &1["id"]) == permutation
        assert json_meta.order == permutation
        assert txt_meta.order == permutation
        assert json_meta.digest == variant.digest
        assert txt_meta.digest == variant.digest

        # Repeated projection of the same variant stays byte-identical.
        assert {:ok, ^json_artifacts, ^json_meta} = IRJson.project(variant, prefix: @prefix)
        assert {:ok, ^txt_artifacts, ^txt_meta} = IRDescriptor.project(variant, prefix: @prefix)

        {variant.digest, json_artifacts["#{@prefix}.ir.json"]}
      end

    assert length(results) == 6
    assert results |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 6
    assert results |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 6
  end

  test "nodes missing from presentation order append in sorted determinism" do
    ir = surface!() |> IR.from_surface()

    partial = ["#{@ledger}#read"]
    presentation = %{ir.presentation | "order" => partial}
    variant = %{ir | presentation: presentation}
    variant = %{variant | digest: IR.digest(variant)}

    expected = ["#{@ledger}#read", "#{@ledger}#list_all", "#{@ledger}#record"]

    assert IR.resolved_order(variant) == expected

    assert {:ok, json_artifacts, json_meta} = IRJson.project(variant, prefix: @prefix)
    assert {:ok, txt_artifacts, txt_meta} = IRDescriptor.project(variant, prefix: @prefix)

    document = json_artifacts["#{@prefix}.ir.json"] |> Jason.decode!()

    assert document["order"] == expected
    assert Enum.map(document["nodes"], & &1["id"]) == expected
    assert json_meta.order == expected
    assert txt_meta.order == expected

    # The fallback is itself map-order invariant.
    permuted = %{
      variant
      | nodes: reorder_maps(variant.nodes, 1),
        presentation: reorder_maps(variant.presentation, 1)
    }

    assert {:ok, ^json_artifacts, ^json_meta} = IRJson.project(permuted, prefix: @prefix)
    assert {:ok, ^txt_artifacts, ^txt_meta} = IRDescriptor.project(permuted, prefix: @prefix)
  end

  # Runs the real manufacturing pass to the verified surface: manifest
  # generation with presentation metadata carried through the profile.
  defp surface! do
    assert {:ok, manifest} =
             Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: @entrypoints)

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: @profile)
    surface
  end

  defp read_dir(dir) do
    dir
    |> File.ls!()
    |> Map.new(fn file -> {file, File.read!(Path.join(dir, file))} end)
  end

  defp expected_artifact(IRJson), do: "#{@prefix}.ir.json"
  defp expected_artifact(IRDescriptor), do: "#{@prefix}.ir.txt"

  # Rebuilds every map in the term from pairs in a different order, so that a
  # structurally equal term is produced with a different construction history.
  defp reorder_maps(map, rotation) when is_map(map) and not is_struct(map) do
    map
    |> Map.to_list()
    |> reorder_pairs(rotation)
    |> Map.new(fn {key, value} -> {key, reorder_maps(value, rotation)} end)
  end

  defp reorder_maps(list, rotation) when is_list(list) do
    Enum.map(list, &reorder_maps(&1, rotation))
  end

  defp reorder_maps(scalar, _rotation), do: scalar

  defp reorder_pairs(pairs, 0), do: Enum.reverse(pairs)

  defp reorder_pairs(pairs, rotation) do
    reversed = Enum.reverse(pairs)
    split = rem(rotation, max(length(pairs), 1))
    {front, back} = Enum.split(reversed, split)
    back ++ front
  end

  defp permutations([]), do: [[]]

  defp permutations(list) do
    for head <- list, rest <- permutations(list -- [head]), do: [head | rest]
  end
end
