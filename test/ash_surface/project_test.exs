defmodule AshSurface.ProjectTest do
  use ExUnit.Case, async: false

  # State-based tests of AshSurface.project/3: one Ash application model (a real
  # Ash.Info.Manifest plus real projection metadata) projects into many lawful
  # consumer projections. Each projection carries only the actions/transports
  # admitted to it, unknown projection kinds fail with a typed error, and every
  # projection's action identity composes with AshSurface.action_id/1.

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @record_id "AshSurface.Fixtures.VolunteerMilestone#record"
  @read_id "AshSurface.Fixtures.VolunteerMilestone#read"

  @record_profile %{
    "semanticId" => "zoe:SelectOption",
    "authorityBoundary" => "SELECT",
    "doAuthority" => false,
    "receiptRequired" => true,
    "evidenceRequired" => true,
    "possibleRefusals" => ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED"]
  }

  # A lawful second consumer kind (Phoenix-channel-shaped probe). Proves that
  # project/3 dispatches any module implementing AshSurface.Projector, not just
  # the shipped Expo projector, and that the transported state stays within its
  # admitted actions/transports.
  defmodule PhoenixChannelProbe do
    @behaviour AshSurface.Projector

    @impl true
    def project(%AshSurface.Surface{} = surface, opts) do
      {:ok,
       %{
         action_ids:
           surface.manifest.entrypoints |> Enum.map(&AshSurface.action_id/1) |> Enum.sort(),
         transports: Keyword.get(opts, :transports, [])
       }, %{consumer: :phoenix_channel}}
    end
  end

  test "one application model projects into many consumers with shared action identity" do
    surface = full_surface()

    assert {:ok, expo_artifacts, expo_meta} =
             AshSurface.project(surface, Expo, prefix: "expo")

    assert {:ok, phoenix_state, phoenix_meta} =
             AshSurface.project(surface, PhoenixChannelProbe,
               transports: [:http, :phoenix_channel]
             )

    # The projection identity is exactly action_id/1 over the admitted entrypoints.
    expected_ids =
      surface.manifest.entrypoints |> Enum.map(&AshSurface.action_id/1) |> Enum.sort()

    assert expected_ids == surface.action_ids
    assert expo_meta == %{prefix: "expo", action_count: 2}
    assert phoenix_meta == %{consumer: :phoenix_channel}

    # Both consumer kinds carry the same admitted action set, composed from
    # action_id/1, and the Expo artifacts restate the contract's action state.
    expo_actions = actions_state(expo_artifacts, "expo")
    assert Enum.map(expo_actions, & &1["id"]) == expected_ids
    assert expo_actions == surface.contract["surface"]["actions"]
    assert phoenix_state.action_ids == expected_ids
  end

  test "each projection carries only the actions admitted by its manifest" do
    record_only = record_only_surface()

    assert {:ok, narrow_artifacts, narrow_meta} =
             AshSurface.project(record_only, Expo, prefix: "narrow")

    narrow_ids = narrow_artifacts |> actions_state("narrow") |> Enum.map(& &1["id"])
    assert narrow_ids == [@record_id]
    assert narrow_meta.action_count == 1
    # The unadmitted action never leaks into the projection state.
    refute artifacts_code(narrow_artifacts, "narrow") =~ @read_id

    full = full_surface()

    assert {:ok, wide_artifacts, wide_meta} = AshSurface.project(full, Expo, prefix: "wide")

    wide_ids = wide_artifacts |> actions_state("wide") |> Enum.map(& &1["id"])
    assert wide_ids == [@read_id, @record_id]
    assert wide_meta.action_count == 2
  end

  test "a consumer projection carries only its admitted transports" do
    surface = full_surface()

    assert {:ok, http_only, _meta} =
             AshSurface.project(surface, PhoenixChannelProbe, transports: [:http])

    assert http_only.transports == [:http]

    assert {:ok, both, _meta} =
             AshSurface.project(surface, PhoenixChannelProbe,
               transports: [:http, :phoenix_channel]
             )

    # All admitted alternatives are preserved until selection; nothing extra enters.
    assert both.transports == [:http, :phoenix_channel]

    assert {:ok, none, _meta} = AshSurface.project(surface, PhoenixChannelProbe, [])
    assert none.transports == []
  end

  test "projection state carries per-action authority boundaries from real metadata" do
    surface = full_surface()

    assert {:ok, artifacts, _meta} = AshSurface.project(surface, Expo, prefix: "auth")

    actions = actions_state(artifacts, "auth")
    record = Enum.find(actions, &(&1["id"] == @record_id))
    read = Enum.find(actions, &(&1["id"] == @read_id))

    # Profiled metadata is carried verbatim into the consumer projection.
    assert record["authorityBoundary"] == "SELECT"
    assert record["doAuthority"] == false
    assert record["semanticId"] == "zoe:SelectOption"
    assert record["receiptRequired"] == true
    assert record["evidenceRequired"] == true
    assert record["possibleRefusals"] == ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED"]

    # The unprofiled :read entrypoint keeps its lawful OBSERVE defaults.
    assert read["authorityBoundary"] == "OBSERVE"
    assert read["doAuthority"] == false
    assert read["semanticId"] == "ash:#{@read_id}"
  end

  test "prefix option is reflected in the returned projection state" do
    surface = full_surface()

    assert {:ok, default_artifacts, default_meta} = AshSurface.project(surface, Expo)
    assert default_meta.prefix == "zoela_surface"
    assert MapSet.new(Map.keys(default_artifacts)) == artifact_names("zoela_surface")

    assert {:ok, custom_artifacts, custom_meta} =
             AshSurface.project(surface, Expo, prefix: "acme_surface")

    assert custom_meta.prefix == "acme_surface"
    assert MapSet.new(Map.keys(custom_artifacts)) == artifact_names("acme_surface")
  end

  test "unknown projection kind is a typed error, never a crash or silent projection" do
    surface = full_surface()

    # Phoenix and Vue consumer kinds ship no projector module: project/3
    # refuses them with the typed unsupported_projector error.
    assert {:error, {:unsupported_projector, AshSurface.Projector.Phoenix}} =
             AshSurface.project(surface, AshSurface.Projector.Phoenix, [])

    assert {:error, {:unsupported_projector, AshSurface.Projector.Vue}} =
             AshSurface.project(surface, AshSurface.Projector.Vue, [])

    # A loaded module that does not implement project/2 is equally typed.
    assert {:error, {:unsupported_projector, Enum}} = AshSurface.project(surface, Enum, [])
  end

  defp full_manifest do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    manifest
  end

  defp record_only_manifest do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [{VolunteerMilestone, :record}]
             )

    manifest
  end

  defp full_surface do
    profile = %{"audience" => "zoe_kingdom", "actions" => %{@record_id => @record_profile}}
    assert {:ok, surface} = AshSurface.from_manifest(full_manifest(), profile: profile)
    surface
  end

  defp record_only_surface do
    profile = %{"actions" => %{@record_id => @record_profile}}
    assert {:ok, surface} = AshSurface.from_manifest(record_only_manifest(), profile: profile)
    surface
  end

  defp artifacts_code(artifacts, prefix), do: artifacts["#{prefix}.actions.mjs"]

  defp actions_state(artifacts, prefix) do
    artifacts
    |> artifacts_code(prefix)
    |> extract_actions_json()
    |> Jason.decode!()
  end

  defp extract_actions_json(code) do
    [_, json] = Regex.run(~r/Object\.freeze\((\[[\s\S]*?\])\);/, code)
    json
  end

  defp artifact_names(prefix) do
    MapSet.new([
      "#{prefix}.schemas.mjs",
      "#{prefix}.actions.mjs",
      "#{prefix}.events.mjs",
      "#{prefix}.receipts.mjs",
      "#{prefix}.mjs",
      "#{prefix}.tanstack.mjs"
    ])
  end
end
