defmodule AshSurfaceZoe.Projector.HumanRuntimeTest do
  @moduledoc """
  Law pinned: the human/demo artifacts manufactured by the package's
  `AshSurfaceZoe.Projector.Human` execute under Node against the
  deterministic `AshSurface.ZoeDemo` fixture, importing this package's
  `ash_surface_zoe` schemas over core's `ash_surface` runtime. ALIVE only via
  the runner's execution receipt.
  """
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.ZoeDemo
  alias AshSurfaceZoe.Fixtures.VolunteerMilestone
  alias AshSurfaceZoe.Projector.Human

  @tmp_dir Path.expand("../../_build/test/projector_human_runtime", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  defp surface! do
    {:ok, manifest} =
      Manifest.generate(
        otp_app: :ash_surface_zoe,
        action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
      )

    {:ok, surface} =
      AshSurface.from_manifest(manifest,
        profile: %{
          audience: :zoe_human_demo,
          actions: %{
            "AshSurfaceZoe.Fixtures.VolunteerMilestone#record" => %{
              consumer: :mobile,
              transport: :http
            }
          }
        }
      )

    surface
  end

  test "emits ONLY the human/demo artifacts (generic Expo files stay in core)" do
    assert {:ok, artifacts, meta} = AshSurface.project(surface!(), Human, prefix: "zoela_surface")

    assert Map.keys(artifacts) |> Enum.sort() ==
             ["zoela_surface.demo.mjs", "zoela_surface.human.mjs"]

    assert meta == %{prefix: "zoela_surface", human_surface: true}
    assert artifacts["zoela_surface.human.mjs"] =~ ~s|from "ash_surface_zoe"|
    refute artifacts["zoela_surface.human.mjs"] =~ ~s|from "ash_surface"|
  end

  test "refuses non-surface IR with the same typed errors as core projectors" do
    assert {:error, {:missing_surface_ir, _}} = Human.project_ir([%{kind: "other", ash: %{}}], [])
  end

  test "manufactured human module executes against the deterministic ZOE demo fixture" do
    assert {:ok, artifacts, meta} =
             AshSurface.project(surface!(), Human, prefix: "zoela_surface", target_dir: @tmp_dir)

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

  # node_modules/{ash_surface,ash_surface_zoe} resolve the bare specifiers the
  # generated artifacts and the package schemas use; zod comes from core's
  # installed node_modules (`npm install` at the repo root).
  defp install_runtime_shim! do
    node_modules = Path.join(@tmp_dir, "node_modules")

    for {name, source} <- [
          {"ash_surface", AshSurface.runtime_path()},
          {"ash_surface_zoe", AshSurfaceZoe.runtime_path()}
        ] do
      dir = Path.join(node_modules, name)
      File.mkdir_p!(dir)

      File.write!(
        Path.join(dir, "package.json"),
        Jason.encode!(%{"name" => name, "type" => "module", "exports" => "./index.mjs"})
      )

      File.cp!(source, Path.join(dir, "index.mjs"))
    end

    zod_source = Path.expand("../../node_modules/zod", File.cwd!())
    assert File.dir?(zod_source), "npm install at the repo root must provide node_modules/zod"

    case File.ln_s(zod_source, Path.join(node_modules, "zod")) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end
end
