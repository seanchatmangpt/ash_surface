defmodule AshSurface.ManifestSerializerTest do
  @moduledoc """
  State-based round-trip tests for the manifest JSON serialization and the
  surface envelope path.

  The serializer exercised is `Ash.Info.Manifest.JsonSerializer` (the one used
  by `AshSurface.from_manifest/2` via `contract/2`); the envelope wrapper is the
  `contract` map's `surface` layer. All tests are pure state checks over real
  generated manifests — no env, db, or network.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.JsonSerializer
  alias AshSurface
  alias AshSurface.Fixtures.VolunteerMilestone

  @record_id "AshSurface.Fixtures.VolunteerMilestone#record"
  @read_id "AshSurface.Fixtures.VolunteerMilestone#read"

  # Byte-exact golden serialization of an identical minimal manifest input.
  # Key order is Jason's deterministic flatmap key order; changing the manifest
  # shape MUST change this string consciously.
  @golden_json """
  {"entrypoints":[{"action":{"get":false,"inputs":[],"metadata":[],"primary":false,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]}\
  """

  setup do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      "audience" => :zoe_kingdom,
      "mx" => true,
      "actions" => %{
        @record_id => %{
          "semanticId" => "zoe:ServeMilestone",
          "authorityBoundary" => "SELECT",
          "doAuthority" => false,
          "receiptRequired" => true,
          "evidenceRequired" => true,
          "possibleRefusals" => ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED"],
          "transports" => ["http", "phoenix_channel"]
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    %{manifest: manifest, profile: profile, surface: surface}
  end

  test "manifest JSON round-trip preserves actions, inputs, and schema identity", %{
    manifest: manifest
  } do
    assert {:ok, json} = JsonSerializer.to_json(manifest)

    decoded = Jason.decode!(json)

    # Exact state round-trip: the JSON string decodes back to the canonical map.
    assert decoded == JsonSerializer.to_map(manifest)

    assert decoded["schema_version"] == Manifest.schema_version()
    assert decoded["schema_version"] == "1.0.0"

    # Both entrypoints share one resource; the serialized action's type is
    # what distinguishes them on the wire.
    actions_by_type =
      Map.new(decoded["entrypoints"], fn e -> {e["action"]["type"], e["action"]} end)

    record = Map.fetch!(actions_by_type, "create")
    assert record["primary"] == false

    assert Enum.map(record["inputs"], & &1["name"]) ==
             ["member_id", "milestone_id", "cost_physical", "reward_spiritual"]

    read = Map.fetch!(actions_by_type, "read")
    assert read["inputs"] == []

    resource = hd(decoded["resources"])
    assert resource["name"] == "VolunteerMilestone"
    assert resource["module"] == "AshSurface.Fixtures.VolunteerMilestone"
    assert resource["primary_key"] == ["id"]
  end

  test "identical manifest input always yields the byte-identical golden JSON string" do
    first = minimal_manifest()
    second = minimal_manifest()

    assert {:ok, json_first} = JsonSerializer.to_json(first)
    assert {:ok, json_second} = JsonSerializer.to_json(second)

    assert json_first == @golden_json
    assert json_second == @golden_json

    # The map form and the string form agree on the same canonical encoding.
    assert Jason.encode!(JsonSerializer.to_map(first)) == @golden_json
  end

  test "envelope adds the surface layer without losing base manifest fields", %{
    manifest: manifest,
    surface: surface
  } do
    contract = surface.contract

    # Base Ash semantics survive the wrapper byte-for-byte: the enveloped
    # manifest is exactly the serializer's projection of the raw manifest
    # (decoration only touches `custom`, which the serializer omits).
    assert contract["manifest"] == JsonSerializer.to_map(manifest)

    # The envelope adds its layer on top.
    assert contract["surfaceSchemaVersion"] == AshSurface.schema_version()
    assert contract["ashManifestSchemaVersion"] == Manifest.schema_version()
    assert contract["generatorIdentity"] == "ash_surface:v26.9.17"
    assert contract["manifestDigest"] =~ ~r/^[0-9a-f]{64}$/
    assert is_map_key(contract, "surface")

    actions = contract["surface"]["actions"]
    assert Enum.map(actions, & &1["id"]) == [@read_id, @record_id]

    read = Enum.find(actions, &(&1["id"] == @read_id))
    # v26.9.17 delegation: the unprofiled read action delegates no facts, so
    # authorityBoundary/doAuthority/semanticId surface as nil.
    assert read["authorityBoundary"] == nil
    assert read["doAuthority"] == nil
    assert read["semanticId"] == nil
    assert read["possibleRefusals"] == []
    assert read["profile"] == %{}

    record = Enum.find(actions, &(&1["id"] == @record_id))
    assert record["resource"] == "AshSurface.Fixtures.VolunteerMilestone"
    assert record["action"] == "record"
    assert record["semanticId"] == "zoe:ServeMilestone"
    assert record["authorityBoundary"] == "SELECT"
    assert record["doAuthority"] == false
    assert record["receiptRequired"] == true
    assert record["evidenceRequired"] == true
    assert record["possibleRefusals"] == ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED"]
  end

  test "contract round-trip preserves actions, transports, and metadata-under-custom", %{
    surface: surface
  } do
    decoded = surface.contract |> Jason.encode!() |> Jason.decode!()

    # `manifestDigest` addresses the embedded manifest (not the whole
    # contract); it must survive the wire round-trip byte-for-byte. That the
    # whole-contract `surface.digest` is reproducible from round-tripped
    # state is proven by the rebuild test below.
    assert decoded["manifestDigest"] == surface.contract["manifestDigest"]
    assert decoded["manifestDigest"] =~ ~r/^[0-9a-f]{64}$/
    assert decoded["surfaceSchemaVersion"] == AshSurface.schema_version()

    # Ash's serializer intentionally omits extension `custom` data from the
    # manifest map; the surface envelope is what carries it across the wire.
    refute Map.has_key?(decoded["manifest"], "custom")

    # In-memory, the decorated manifest holds the surface metadata under
    # `custom.ash_surface` ...
    root_custom = surface.manifest.custom[:ash_surface]
    assert root_custom["schemaVersion"] == AshSurface.schema_version()
    assert root_custom["profile"] == %{"audience" => "zoe_kingdom", "mx" => true}

    record_entrypoint =
      Enum.find(
        surface.manifest.entrypoints,
        &(&1.resource == VolunteerMilestone and &1.action.name == :record)
      )

    entry_custom = record_entrypoint.action.custom[:ash_surface]
    assert entry_custom["id"] == @record_id

    # ... and the round-tripped envelope preserves exactly that metadata.
    assert decoded["surface"]["profile"] == root_custom["profile"]

    record = Enum.find(decoded["surface"]["actions"], &(&1["id"] == @record_id))
    assert record["profile"] == entry_custom["profile"]

    # Transport declarations survive the round-trip and remain usable for
    # pure transport selection.
    declared = record["profile"]["transports"] |> Enum.map(&String.to_existing_atom/1)
    assert declared == [:http, :phoenix_channel]

    assert {:ok, %AshSurface.Transport.Decision{selected: :http, reason: :preferred_available}} =
             AshSurface.Transport.select(declared, [:http],
               preferred: :http,
               action_id: @record_id
             )
  end

  test "digest is content-addressed and stable across a full profile round-trip", %{
    manifest: manifest,
    profile: profile,
    surface: surface
  } do
    round_tripped = profile |> Jason.encode!() |> Jason.decode!()

    assert {:ok, rebuilt} = AshSurface.from_manifest(manifest, profile: round_tripped)

    # Identical input state rebuilds the identical contract and digest.
    assert rebuilt.digest == surface.digest
    assert rebuilt.contract == surface.contract
    assert Jason.encode!(rebuilt.contract) == Jason.encode!(surface.contract)
    assert rebuilt.action_ids == surface.action_ids

    # Falsifier: a different profile is a different contract, therefore a
    # different digest — the digest really addresses content.
    altered = put_in(round_tripped["audience"], "zoe_kingdom_ii")

    assert {:ok, other} = AshSurface.from_manifest(manifest, profile: altered)
    assert other.digest != surface.digest
  end

  defp minimal_manifest do
    %Manifest{
      resources: [],
      types: [],
      entrypoints: [
        %Manifest.Entrypoint{
          resource: VolunteerMilestone,
          action: %Manifest.Action{
            name: :ping,
            type: :read,
            primary?: false,
            get?: false,
            inputs: [],
            metadata: []
          }
        }
      ]
    }
  end
end
