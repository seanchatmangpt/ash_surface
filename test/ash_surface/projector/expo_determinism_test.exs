defmodule AshSurface.Projector.ExpoDeterminism.WideDomain do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Projector.ExpoDeterminism.WideResource)
  end
end

defmodule AshSurface.Projector.ExpoDeterminism.WideResource do
  @moduledoc """
  Determinism fixture with more than 32 public attributes.

  The serialized `fields` map of this resource exceeds the 32-key small-map
  boundary, so projector rendering (`render_schemas/2` iterates the fields map,
  Jason encodes maps in raw `Map.to_list/1` order) exercises large-map
  iteration, where key order is at stake rather than guaranteed by flatmap
  term ordering.
  """

  use Ash.Resource,
    domain: AshSurface.Projector.ExpoDeterminism.WideDomain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)

    for i <- 1..40 do
      attribute(:"field_#{i}", :string, public?: true)
    end
  end

  actions do
    defaults([:read])

    create(:record)
  end
end

defmodule AshSurface.Projector.ExpoDeterminismTest do
  @moduledoc """
  Determinism proofs for the full `AshSurface.Projector.Expo` manufacturing
  pass (`Manifest.generate` -> `AshSurface.from_manifest` -> `project`).

  Zero env, zero db, zero network: the pass is exercised purely in memory with
  artifacts materialized into per-test temporary directories.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Projector.Expo

  @prefix "zoela_surface"

  # The artifact list documented in AshSurface.Projector.Expo's @moduledoc.
  @documented_artifacts Enum.sort([
                          "#{@prefix}.schemas.mjs",
                          "#{@prefix}.actions.mjs",
                          "#{@prefix}.events.mjs",
                          "#{@prefix}.receipts.mjs",
                          "#{@prefix}.human.mjs",
                          "#{@prefix}.demo.mjs",
                          "#{@prefix}.mjs",
                          "#{@prefix}.tanstack.mjs"
                        ])

  @action_entrypoints [
    {AshSurface.Fixtures.VolunteerMilestone, :record},
    {AshSurface.Fixtures.VolunteerMilestone, :read},
    {AshSurface.Projector.ExpoDeterminism.WideResource, :record},
    {AshSurface.Projector.ExpoDeterminism.WideResource, :read}
  ]

  # Nested 40-key map ("wide") keeps the profile above the small-map boundary
  # so the ACTIONS JSON encoding also crosses the large-map iteration path.
  @profile %{
    "audience" => :zoe_kingdom,
    "actions" => %{
      "AshSurface.Fixtures.VolunteerMilestone#record" => %{
        "semanticId" => "zoe:SelectOption",
        "authorityBoundary" => "SELECT",
        "doAuthority" => false,
        "receiptRequired" => true,
        "evidenceRequired" => true,
        "possibleRefusals" => ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED", "UNKNOWN_AFTER_DISPATCH"]
      },
      "AshSurface.Projector.ExpoDeterminism.WideResource#record" => %{
        "semanticId" => "zoe:ConstructWide",
        "authorityBoundary" => "CONSTRUCT",
        "doAuthority" => false,
        "receiptRequired" => true,
        "evidenceRequired" => false,
        "possibleRefusals" => ["AUTHORITY_REFUSED", "UNKNOWN_AFTER_DISPATCH"],
        "wide" => Map.new(1..40, &{"wide_key_#{&1}", "value_#{&1}"})
      }
    }
  }

  @tag :tmp_dir
  test "full manufacturing pass is byte-identical across repeated runs",
       %{tmp_dir: tmp_dir} do
    runs =
      for i <- 1..5 do
        {manifest, surface, artifacts, meta} = full_pass!(Path.join(tmp_dir, "run_#{i}"))
        {manifest, surface, artifacts, meta, read_dir(Path.join(tmp_dir, "run_#{i}"))}
      end

    [{manifest0, surface0, artifacts0, meta0, files0} | rest] = runs

    for {manifest, surface, artifacts, meta, files} <- rest do
      assert manifest == manifest0
      assert surface == surface0
      assert meta == meta0
      assert artifacts == artifacts0
      assert files == files0
    end

    # The surface digest emitted by the manufacturing pass is stable.
    assert runs |> Enum.map(fn {_, s, _, _, _} -> s.digest end) |> Enum.uniq() |> length() == 1

    # The artifact map is exactly the documented artifact list.
    assert artifacts0 |> Map.keys() |> Enum.sort() == @documented_artifacts

    # On-disk bytes are exactly the in-memory artifact bytes: no strays, no
    # rewrites, no transient files.
    assert Map.keys(files0) |> Enum.sort() == @documented_artifacts
    assert files0 == artifacts0

    assert meta0 == %{
             prefix: @prefix,
             action_count: length(@action_entrypoints),
             human_surface: true
           }
  end

  @tag :tmp_dir
  test "structurally equal surfaces with rebuilt map ordering project to byte-identical artifacts",
       %{tmp_dir: tmp_dir} do
    {_, surface0, artifacts0, meta0} = full_pass!(Path.join(tmp_dir, "baseline"))

    for rotation <- [0, 1, 2, 3] do
      variant = %{surface0 | contract: reorder_maps(surface0.contract, rotation)}

      # The variant differs only in map construction history, not in content.
      assert variant.contract == surface0.contract

      assert {:ok, artifacts, meta} = AshSurface.project(variant, Expo, prefix: @prefix)
      assert artifacts == artifacts0
      assert meta == meta0

      dir = Path.join(tmp_dir, "variant_#{rotation}")

      assert {:ok, ^artifacts0, ^meta0} =
               AshSurface.project(variant, Expo, prefix: @prefix, target_dir: dir)

      assert read_dir(dir) == artifacts0
    end
  end

  @tag :tmp_dir
  test "re-projection overwrites previously written artifacts cleanly in place",
       %{tmp_dir: tmp_dir} do
    dir = Path.join(tmp_dir, "target")

    {_, surface, artifacts, _meta} = full_pass!(dir)
    snapshot = read_dir(dir)
    assert snapshot == artifacts

    # Corrupt one artifact to prove re-projection overwrites instead of
    # skipping existing files.
    File.write!(Path.join(dir, "#{@prefix}.schemas.mjs"), "// corrupted projection\n")
    assert read_dir(dir) != snapshot

    {_, _surface, artifacts2, _meta2} = full_pass!(dir)

    assert artifacts2 == artifacts
    assert read_dir(dir) == snapshot

    # A structurally equal variant re-projected into the same directory leaves
    # exactly the same bytes and file set.
    variant = %{surface | contract: reorder_maps(surface.contract, 1)}

    assert {:ok, ^artifacts, _} =
             AshSurface.project(variant, Expo, prefix: @prefix, target_dir: dir)

    assert read_dir(dir) == snapshot

    assert dir |> File.ls!() |> Enum.sort() == @documented_artifacts
  end

  # Runs the complete manufacturing pass: manifest generation, surface
  # verification, and projection to disk.
  defp full_pass!(target_dir) do
    assert {:ok, manifest} =
             Manifest.generate(otp_app: :ash_surface, action_entrypoints: @action_entrypoints)

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: @profile)

    assert {:ok, artifacts, meta} =
             AshSurface.project(surface, Expo, prefix: @prefix, target_dir: target_dir)

    {manifest, surface, artifacts, meta}
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
end
