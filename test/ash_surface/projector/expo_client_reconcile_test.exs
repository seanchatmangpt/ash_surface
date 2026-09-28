defmodule AshSurface.Projector.ExpoClientReconcileTest do
  @moduledoc """
  Consumer execution receipt for the manufactured Expo client's `reconcile/1`.

  The text-golden suites (`expo_client_test`, `expo_receipts_test`) pin what the
  generated client says; this suite runs it. The real projector manufactures
  `zoela_surface.mjs`, the real runtime is installed behind the `ash_surface`
  import, and Node drives `reconcile` (test/js/generated_client_reconcile_runner.mjs)
  against stubbed `fetch` behaviours:

    * server-observed `COMPLETED | NOT_OBSERVED | STILL_UNKNOWN` pass through,
      over a plain GET bound to the commandId (no method, no body);
    * a non-ok reply, an unknown status, a null or non-JSON body and a network
      error all stay `STILL_UNKNOWN` - never invented, never upgraded;
    * a hung endpoint is bounded by `reconcileTimeoutMs`, not a hang.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @tmp_dir Path.expand("../../../_build/test/projector_expo_client_reconcile", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    :ok
  end

  test "the manufactured client's reconcile executes under the admitted-status law" do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
             )

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})

    assert {:ok, artifacts, _meta} =
             AshSurface.project(surface, Expo, prefix: "zoela_surface", target_dir: @tmp_dir)

    assert is_binary(artifacts["zoela_surface.mjs"])

    install_runtime_shim!()
    contract_path = Path.join(@tmp_dir, "contract.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    {output, exit_code} =
      System.cmd(
        "node",
        ["test/js/generated_client_reconcile_runner.mjs", @tmp_dir, contract_path],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "generated Expo client reconcile failed: #{output}"

    assert {:ok, receipt} =
             Jason.decode(output |> String.trim() |> String.split("\n") |> List.last())

    assert receipt == %{
             "receipt" => "GENERATED_EXPO_RECONCILE_PASS",
             "passThrough" => true,
             "unreadableIsUnknown" => true,
             "hungEndpointBounded" => true
           }
  end

  defp install_runtime_shim! do
    package_dir = Path.join([@tmp_dir, "node_modules", "ash_surface"])
    File.mkdir_p!(package_dir)

    File.write!(
      Path.join(package_dir, "package.json"),
      Jason.encode!(%{"name" => "ash_surface", "type" => "module", "exports" => "./index.mjs"})
    )

    File.cp!(
      Path.expand("priv/static/ash_surface_runtime.mjs"),
      Path.join(package_dir, "index.mjs")
    )

    zod_source = Path.expand("node_modules/zod")
    assert File.dir?(zod_source), "npm install must provide node_modules/zod before mix test"

    case File.ln_s(zod_source, Path.join([@tmp_dir, "node_modules", "zod"])) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end
end
