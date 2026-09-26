defmodule AshSurface.Projector.ExpoHumanRuntimeTest do
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{ZoeDemo}
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @tmp_dir Path.expand("../../../_build/test/projector_expo_human_runtime", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  test "manufactured Expo human module executes against the deterministic ZOE demo fixture" do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    assert {:ok, surface} =
             AshSurface.from_manifest(manifest,
               profile: %{
                 audience: :zoe_human_demo,
                 actions: %{
                   "AshSurface.Fixtures.VolunteerMilestone#record" => %{
                     consumer: :mobile,
                     transport: :http
                   }
                 }
               }
             )

    assert {:ok, artifacts, meta} =
             AshSurface.project(surface, Expo,
               prefix: "zoela_surface",
               target_dir: @tmp_dir
             )

    assert meta.human_surface == true
    assert is_binary(artifacts["zoela_surface.human.mjs"])
    assert is_binary(artifacts["zoela_surface.demo.mjs"])

    install_runtime_shim!()

    fixture_path = Path.join(@tmp_dir, "zoe_demo_human_surface.json")
    File.write!(fixture_path, Jason.encode!(ZoeDemo.map()))

    {output, exit_code} =
      System.cmd(
        "node",
        ["test/js/generated_human_runtime_runner.mjs", @tmp_dir, fixture_path],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "generated human runtime failed: #{output}"

    assert {:ok, receipt} = Jason.decode(String.trim(output))
    assert receipt["standing"] == "ALIVE"
    assert receipt["receipt"] == "GENERATED_HUMAN_RUNTIME_PASS"
    assert receipt["areas"] == ["TODAY", "BIBLE", "LIFE", "ZOE", "YOU"]
    assert receipt["possibilityCount"] == 4
    assert receipt["devotionalSegmentCount"] == 4
    assert receipt["journeyEntryCount"] == 3
    assert is_binary(receipt["manufactureTraceId"])
    assert receipt["consumerStanding"] == "ALIVE"
    assert receipt["playbackReceiptKind"] == "LOCAL_PLAYBACK_COMPLETED"
    assert receipt["htmlAudioPlayback"] == "COMPLETED"
    assert receipt["provenanceVisible"] == true
    assert receipt["brceDispatched"] == false
  end

  defp install_runtime_shim! do
    node_modules = Path.join(@tmp_dir, "node_modules")
    package_dir = Path.join(node_modules, "ash_surface")
    File.mkdir_p!(package_dir)

    File.write!(
      Path.join(package_dir, "package.json"),
      Jason.encode!(%{
        "name" => "ash_surface",
        "type" => "module",
        "exports" => "./index.mjs"
      })
    )

    File.cp!(
      Path.expand("priv/static/ash_surface_runtime.mjs"),
      Path.join(package_dir, "index.mjs")
    )

    zod_source = Path.expand("node_modules/zod")
    zod_target = Path.join(node_modules, "zod")

    assert File.dir?(zod_source), "npm install must provide node_modules/zod before mix test"

    case File.ln_s(zod_source, zod_target) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end
end
