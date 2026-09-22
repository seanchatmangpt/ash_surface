defmodule AshSurface.Projector.ExpoTest do
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @tmp_dir Path.expand("../../../_build/test/projector_expo", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  test "projects real AshSurface into complete Zoela / Expo artifacts with node check verification" do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      audience: :zoe_kingdom,
      actions: %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          semanticId: "zoe:SelectOption",
          authorityBoundary: "SELECT",
          doAuthority: false,
          receiptRequired: true,
          evidenceRequired: true,
          possibleRefusals: ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED", "UNKNOWN_AFTER_DISPATCH"]
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    assert {:ok, artifacts, meta} =
             AshSurface.project(surface, Expo, prefix: "zoela_surface", target_dir: @tmp_dir)

    assert meta.prefix == "zoela_surface"
    assert meta.action_count == 2
    assert meta.human_surface == true

    for file <- [
          "zoela_surface.schemas.mjs",
          "zoela_surface.actions.mjs",
          "zoela_surface.events.mjs",
          "zoela_surface.receipts.mjs",
          "zoela_surface.human.mjs",
          "zoela_surface.mjs",
          "zoela_surface.tanstack.mjs"
        ] do
      path = Path.join(@tmp_dir, file)
      assert File.exists?(path), "Expected #{file} to be manufactured"
      assert is_binary(artifacts[file])
    end

    human = artifacts["zoela_surface.human.mjs"]
    assert human =~ "HUMAN_AREAS"
    assert human =~ "preservedPossibilities"
    assert human =~ "devotionalQueue"
    assert human =~ "commitmentPreview"
    assert human =~ "journeyTimeline"
    assert human =~ "assertNoDoAuthority"

    # Verify every generated JavaScript artifact independently. Passing many
    # filenames to one node --check only checks the first script and treats the
    # remainder as argv, so each artifact gets its own syntax receipt.
    for file <- [
          "zoela_surface.schemas.mjs",
          "zoela_surface.actions.mjs",
          "zoela_surface.events.mjs",
          "zoela_surface.receipts.mjs",
          "zoela_surface.human.mjs",
          "zoela_surface.mjs",
          "zoela_surface.tanstack.mjs"
        ] do
      {output, exit_code} =
        System.cmd(
          "node",
          ["--check", Path.join(@tmp_dir, file)],
          stderr_to_stdout: true
        )

      assert exit_code == 0, "node --check failed for #{file}: #{output}"
    end
  end
end
