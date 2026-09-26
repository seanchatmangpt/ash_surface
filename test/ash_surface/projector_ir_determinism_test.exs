defmodule AshSurface.ProjectorIRDeterminism.CanonicalJson do
  @moduledoc """
  Sorted-key canonical JSON encoding (recursively string-keyed, key-sorted
  pairs), used as the rendering engine of the injected projector doubles
  below.

  This helper predates the lib promotion tracked by finish item F1; when the
  canonical encoder is admitted into lib, this module retires and the doubles
  re-point at it. No lib module is shadowed today.
  """

  def encode(map) when is_map(map) do
    pairs =
      map
      |> Enum.map(fn {key, value} -> {to_string(key), value} end)
      |> Enum.sort_by(fn {key, _value} -> key end)

    "{" <>
      Enum.map_join(pairs, ",", fn {key, value} ->
        Jason.encode!(key) <> ":" <> encode(value)
      end) <> "}"
  end

  def encode(list) when is_list(list) do
    "[" <> Enum.map_join(list, ",", &encode/1) <> "]"
  end

  def encode(scalar), do: Jason.encode!(scalar)
end

defmodule AshSurface.ProjectorIRDeterminism.JsonProjector do
  @moduledoc """
  Injected projector double over the legacy `AshSurface.Projector` behaviour —
  the seam TESTING.md admits for projectors (the projector module passed to
  `AshSurface.project/3`). State-based, no mocks: it renders one JSON artifact
  from admitted surface facts only.

  Canonical modules it drives: `AshSurface.IR.Codec.digest/1` (the production
  digest canon, pinned against the surface's own digest by the suite) and the
  contract's admitted action entries. The IR-era dispatch path drives this same
  double through `AshSurface.Projector.IR.ManifestProjector`.
  """

  @behaviour AshSurface.Projector

  alias AshSurface.IR.Codec
  alias AshSurface.ProjectorIRDeterminism.CanonicalJson

  @impl true
  def project(%AshSurface.Surface{} = surface, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "surface_ir")

    actions =
      surface.contract
      |> get_in(["surface", "actions"])
      |> Enum.map(&Map.take(&1, ["id", "semanticId", "authorityBoundary", "doAuthority"]))

    document = %{
      "digest" => surface.digest,
      "codecDigest" => Codec.digest(surface.contract),
      "actionIds" => surface.action_ids,
      "presentationOrder" =>
        get_in(surface.contract, ["surface", "profile", "presentation", "order"]) || [],
      "actions" => actions
    }

    artifacts = %{"#{prefix}.ir.json" => CanonicalJson.encode(document) <> "\n"}

    write!(artifacts, Keyword.get(opts, :target_dir))

    {:ok, artifacts,
     %{kind: :ir_json, digest: surface.digest, action_count: length(surface.action_ids)}}
  end

  defp write!(_artifacts, nil), do: :ok

  defp write!(artifacts, dir) do
    File.mkdir_p!(dir)
    Enum.each(artifacts, fn {filename, body} -> File.write!(Path.join(dir, filename), body) end)
  end
end

defmodule AshSurface.ProjectorIRDeterminism.DescriptorProjector do
  @moduledoc """
  Injected projector double implementing the IR-era
  `AshSurface.Projector.IR` behaviour (`project_ir/2`) — the canonical
  dispatch target exercised through `AshSurface.Projector.IR.project/3`.

  It renders one text descriptor from the `ash_surface.surface` node's
  admitted facts: digest and contract from `ash`, and the delegated facts
  (`semanticId`, `authorityBoundary`, `doAuthority`) read through the
  canonical `AshSurface.IR.delegated/2` — read, never derived. Ordering is
  the repo law: entries are id-sorted, never list or map construction order.
  """

  @behaviour AshSurface.Projector.IR

  alias AshSurface.IR
  alias AshSurface.IR.Codec

  @impl true
  def project_ir(irs, opts \\ []) do
    prefix = Keyword.get(opts, :prefix, "surface_ir")
    %{ash: ash} = surface_node(irs)

    numbered =
      ash.manifest.entrypoints
      |> Enum.map(&{AshSurface.action_id(&1), &1})
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.with_index(1)
      |> Enum.map(fn {{id, entrypoint}, index} ->
        "#{index}. #{id} :: #{IR.delegated(entrypoint, "semanticId")} " <>
          "[#{IR.delegated(entrypoint, "authorityBoundary")}] do=#{IR.delegated(entrypoint, "doAuthority")}"
      end)

    lines =
      [
        "# ash_surface ir #{ash.digest}",
        "codec: #{Codec.digest(ash.contract)}"
      ] ++ numbered

    artifacts = %{"#{prefix}.ir.txt" => Enum.join(lines, "\n") <> "\n"}

    write!(artifacts, Keyword.get(opts, :target_dir))

    {:ok, artifacts, %{kind: :ir_descriptor, digest: ash.digest}}
  end

  defp surface_node(irs) when is_list(irs), do: surface_node(List.first(irs))
  defp surface_node(%{kind: "ash_surface.surface"} = node), do: node

  defp write!(_artifacts, nil), do: :ok

  defp write!(artifacts, dir) do
    File.mkdir_p!(dir)
    Enum.each(artifacts, fn {filename, body} -> File.write!(Path.join(dir, filename), body) end)
  end
end

defmodule AshSurface.ProjectorIRDeterminismTest do
  @moduledoc """
  Determinism proofs for IR projection, driven entirely by the canonical IR
  modules (finish item F8: the former test-local `ProjectorIRDeterminism.IR` /
  `ProjectorIR` shadow doubles are retired — `lib/ash_surface/ir.ex`,
  `lib/ash_surface/ir/codec.ex`, and `lib/ash_surface/projector/ir.ex` exist
  and are the subjects under test).

  The pipeline under test is the real manufacturing pass:

      Manifest.generate -> AshSurface.from_manifest
        -> AshSurface.Compiler.compile        (canonical [%AshSurface.IR{}] assembly)
        -> AshSurface.Projector.IR.from_surface / to_surface   (IR round-trip)
        -> AshSurface.IR.Codec.digest         (the production digest canon)

  Projection dispatch is exercised through every canonical path: the legacy
  `AshSurface.project/3` seam and the IR-era `AshSurface.Projector.IR.project/3`
  (both the `ManifestProjector` adapter wrapping the legacy double and the
  native `project_ir/2` double). The doubles are the admitted injected seam
  only — they are real state-based renderers, not fakes of any lib module.

  Zero env, zero db, zero network: one fixture built from the real shared
  `AshSurface.Fixtures.VolunteerMilestone` resource, artifacts materialized
  into per-test temporary directories.
  """

  use ExUnit.Case, async: false

  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.IR.Codec
  alias AshSurface.Projector.IR
  alias AshSurface.Projector.IREntry
  alias AshSurface.ProjectorIRDeterminism.CanonicalJson
  alias AshSurface.ProjectorIRDeterminism.DescriptorProjector
  alias AshSurface.ProjectorIRDeterminism.JsonProjector

  @prefix "surface_ir"
  @ledger "AshSurface.Fixtures.VolunteerMilestone"

  # Deliberately not id-sorted: ordering in every artifact below must come
  # from the canonical id-sort laws, never from declaration coincidence.
  @entrypoints [
    {VolunteerMilestone, :record},
    {VolunteerMilestone, :read}
  ]

  @sorted_ids Enum.sort(["#{@ledger}#record", "#{@ledger}#read"])

  # Presentation order metadata is content: it rides the surface profile into
  # the contract (the digest preimage), so permuting it moves the identity.
  @order ["#{@ledger}#record", "#{@ledger}#read"]

  # Delegated facts per the v26.9.16 delegation law (v10): read from this
  # profile by `AshSurface.IR.delegated/2`, never derived from action type.
  # The "wide" member crosses the 32-key small-map boundary so the digest
  # canon is exercised over large-map (HAMT) iteration.
  @profile %{
    "presentation" => %{
      "order" => @order,
      "wide" => Map.new(1..40, &{"presentation_key_#{&1}", "value_#{&1}"})
    },
    "actions" => %{
      "#{@ledger}#record" => %{
        "semanticId" => "zoe:ConstructMilestone",
        "authorityBoundary" => "CONSTRUCT",
        "doAuthority" => false,
        "receiptRequired" => true
      },
      "#{@ledger}#read" => %{
        "semanticId" => "ash:#{@ledger}#read",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false,
        "receiptRequired" => false
      }
    }
  }

  @runs 7

  @tag :tmp_dir
  test "n runs of the canonical IR pipeline are byte-identical across every dispatch path",
       %{tmp_dir: tmp_dir} do
    runs =
      for i <- 1..@runs do
        {surface, compiler_irs, ir_node} = pass!()

        json_dir = Path.join(tmp_dir, "json_#{i}")
        adapter_dir = Path.join(tmp_dir, "adapter_#{i}")
        descriptor_dir = Path.join(tmp_dir, "descriptor_#{i}")

        assert {:ok, json_artifacts, json_meta} =
                 AshSurface.project(surface, JsonProjector,
                   prefix: @prefix,
                   target_dir: json_dir
                 )

        assert {:ok, adapter} = IR.from_manifest_projector(JsonProjector)

        assert {:ok, adapter_artifacts, adapter_meta} =
                 IR.project(adapter, ir_node, prefix: @prefix, target_dir: adapter_dir)

        assert {:ok, descriptor_artifacts, descriptor_meta} =
                 IR.project(DescriptorProjector, ir_node,
                   prefix: @prefix,
                   target_dir: descriptor_dir
                 )

        %{
          surface: surface,
          compiler_irs: compiler_irs,
          ir_node: ir_node,
          json: {json_artifacts, json_meta, read_dir(json_dir)},
          adapter: {adapter_artifacts, adapter_meta, read_dir(adapter_dir)},
          descriptor: {descriptor_artifacts, descriptor_meta, read_dir(descriptor_dir)}
        }
      end

    [first | rest] = runs

    for run <- rest do
      assert run.surface == first.surface
      assert run.compiler_irs == first.compiler_irs
      assert run.ir_node == first.ir_node
      assert run.json == first.json
      assert run.adapter == first.adapter
      assert run.descriptor == first.descriptor
    end

    surface = first.surface
    ir_node = first.ir_node
    {json_artifacts, json_meta, json_files} = first.json
    {adapter_artifacts, adapter_meta, _adapter_files} = first.adapter
    {descriptor_artifacts, descriptor_meta, descriptor_files} = first.descriptor

    # The production digest canon agrees with the surface identity on the real
    # fixture: the codec and AshSurface.from_manifest run the same pipeline.
    assert Codec.digest(surface.contract) == surface.digest

    # The canonical IR node carries exactly the verified surface's four facts.
    assert ir_node == %{
             kind: "ash_surface.surface",
             ash: %{
               manifest: surface.manifest,
               contract: surface.contract,
               digest: surface.digest,
               action_ids: surface.action_ids
             }
           }

    # The IR round-trip re-extracts the exact surface, byte for byte.
    assert {:ok, ^surface} = IR.to_surface(ir_node)

    # The adapter re-extracted the identical surface, so the wrapped legacy
    # projector emitted identical bytes through both dispatch paths.
    assert adapter_artifacts == json_artifacts
    assert adapter_meta == json_meta

    # Both artifact kinds agree on the fixture's IR identity.
    assert json_meta.digest == surface.digest
    assert descriptor_meta.digest == surface.digest
    assert json_artifacts["#{@prefix}.ir.json"] =~ surface.digest

    # On-disk bytes are exactly the in-memory artifact bytes: no strays.
    assert json_files == json_artifacts
    assert descriptor_files == descriptor_artifacts
    assert Enum.sort(Map.keys(json_artifacts)) == ["#{@prefix}.ir.json"]
    assert Enum.sort(Map.keys(descriptor_artifacts)) == ["#{@prefix}.ir.txt"]

    # The compiler's canonical IR assembly agrees with the IR node on the
    # fixture's identity and delegated facts.
    assert length(first.compiler_irs) == 2
    assert Enum.uniq(Enum.map(first.compiler_irs, & &1.digest)) |> length() == 1
  end

  test "structurally equal surfaces with permuted map construction history project identically" do
    surface = surface!()
    {:ok, ir_node} = IR.from_surface(surface)

    # An independent full rebuild of the surface yields the exact same struct —
    # manifest, contract, digest, and action ids: the fixture itself is stable
    # before projection begins.
    assert surface!() == surface

    baseline = %{
      json: AshSurface.project(surface, JsonProjector, prefix: @prefix),
      descriptor: IR.project(DescriptorProjector, ir_node, prefix: @prefix)
    }

    for rotation <- [0, 1, 2, 3, 5, 7] do
      permuted_contract = reorder_maps(surface.contract, rotation)

      # The variant differs only in map construction history, not in content —
      # including the 40-key wide profile member across the HAMT boundary.
      assert permuted_contract == surface.contract

      # The production digest canon is invariant under that history.
      assert Codec.digest(permuted_contract) == surface.digest

      # The canonical IR node is invariant too: it carries content, not
      # construction history.
      variant_surface = %{surface | contract: permuted_contract}
      assert {:ok, variant_node} = IR.from_surface(variant_surface)
      assert variant_node == ir_node

      # Both dispatch paths project the permuted history to the baseline bytes.
      assert AshSurface.project(variant_surface, JsonProjector, prefix: @prefix) ==
               baseline.json

      assert IR.project(DescriptorProjector, variant_node, prefix: @prefix) ==
               baseline.descriptor
    end
  end

  test "output ordering is the canonical id law, never declaration or construction order" do
    # Fixture guard: the entrypoints are declared out of id order, so sorted
    # output can only come from a sorting law acting on the facts.
    refute @entrypoints == Enum.sort(@entrypoints)

    surface = surface!()
    {:ok, ir_node} = IR.from_surface(surface)
    assert {:ok, compiler_irs} = AshSurface.Compiler.compile(surface.manifest)

    # Surface identity: action ids are id-sorted by from_manifest.
    assert surface.action_ids == @sorted_ids

    # Contract actions ride the same law.
    assert Enum.map(surface.contract["surface"]["actions"], & &1["id"]) == @sorted_ids

    # The canonical entry reader id-sorts regardless of input list order.
    entries = IREntry.entries(compiler_irs)
    ids = Enum.map(entries, & &1.id)
    assert ids == Enum.sort(ids)
    assert IREntry.entries(Enum.reverse(compiler_irs)) == entries

    # Artifacts follow the same law: the descriptor's lines are id-sorted even
    # though the fixture declares #record before #read.
    assert {:ok, descriptor_artifacts, _meta} =
             IR.project(DescriptorProjector, ir_node, prefix: @prefix)

    lines = descriptor_artifacts["#{@prefix}.ir.txt"] |> String.split("\n", trim: true)

    assert lines == [
             "# ash_surface ir #{surface.digest}",
             "codec: #{Codec.digest(surface.contract)}",
             "1. #{@ledger}#read :: ash:#{@ledger}#read [OBSERVE] do=false",
             "2. #{@ledger}#record :: zoe:ConstructMilestone [CONSTRUCT] do=false"
           ]

    assert {:ok, json_artifacts, _meta} =
             AshSurface.project(surface, JsonProjector, prefix: @prefix)

    assert json_artifacts["#{@prefix}.ir.json"] =~
             ~s("actionIds":["#{@ledger}#read","#{@ledger}#record"])
  end

  test "presentation order metadata is content: permutations move digests deterministically" do
    baseline = surface!()

    results =
      for permutation <- permutations(@order) do
        profile = put_in(@profile["presentation"]["order"], permutation)
        variant = surface!(profile)

        # Order is content: changing it changes the surface identity. The
        # identity permutation reproduces the original surface exactly.
        if permutation == @order do
          assert variant == baseline
        else
          assert variant.digest != baseline.digest
        end

        # The codec canon content-addresses the permutation.
        assert Codec.digest(variant.contract) == variant.digest

        assert {:ok, json_artifacts, json_meta} =
                 AshSurface.project(variant, JsonProjector, prefix: @prefix)

        assert {:ok, variant_node} = IR.from_surface(variant)

        assert {:ok, descriptor_artifacts, descriptor_meta} =
                 IR.project(DescriptorProjector, variant_node, prefix: @prefix)

        assert json_meta.digest == variant.digest
        assert descriptor_meta.digest == variant.digest

        # The declared order rides the artifact verbatim.
        assert json_artifacts["#{@prefix}.ir.json"] =~ CanonicalJson.encode(permutation)

        # Repeated projection of the same variant stays byte-identical.
        assert {:ok, ^json_artifacts, ^json_meta} =
                 AshSurface.project(variant, JsonProjector, prefix: @prefix)

        assert {:ok, ^descriptor_artifacts, ^descriptor_meta} =
                 IR.project(DescriptorProjector, variant_node, prefix: @prefix)

        {variant.digest, json_artifacts["#{@prefix}.ir.json"]}
      end

    assert length(results) == 2
    assert results |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() == 2
    assert results |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() == 2
  end

  ## helpers

  # One full manufacturing pass: manifest generation, surface verification,
  # canonical IR assembly, and the canonical surface-IR node.
  defp pass! do
    surface = surface!()
    assert {:ok, compiler_irs} = AshSurface.Compiler.compile(surface.manifest)
    assert {:ok, ir_node} = IR.from_surface(surface)
    {surface, compiler_irs, ir_node}
  end

  defp surface!(profile \\ @profile) do
    assert {:ok, manifest} =
             Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: @entrypoints)

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)
    surface
  end

  defp read_dir(dir) do
    dir
    |> File.ls!()
    |> Map.new(fn file -> {file, File.read!(Path.join(dir, file))} end)
  end

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
