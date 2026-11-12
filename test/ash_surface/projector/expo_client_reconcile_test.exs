defmodule AshSurface.Projector.ExpoClientReconcileTest do
  @moduledoc """
  Consumer execution receipt for the manufactured Expo client's `reconcile/1`.

  The text-golden suites (`expo_client_test`, `expo_receipts_test`) pin what the
  generated client says; this suite runs it. The real projector manufactures
  `zoela_surface.mjs`, the real runtime is installed behind the `ash_surface`
  import, and Node drives `reconcile` (test/js/generated_client_reconcile_runner.mjs)
  against a real `node:http` server. The emitted client imports
  `./ash_surface_runtime.mjs` (copied beside it by the consumer; the codegen task owns that copy) and delegates
  to the runtime's `client.reconcile`:

    * server-observed `COMPLETED | NOT_OBSERVED | STILL_UNKNOWN` pass through,
      over a plain GET bound to the commandId (no method, no body);
    * `reconcile.result` is emitted and `onEvent` is forwarded;
    * a non-ok reply, an unknown status, a null or non-JSON body and a network
      error THROW - never an invented or upgraded status;
    * a hung endpoint is bounded by `reconcileTimeoutMs` and throws.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  setup do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_expo_reconcile_#{System.unique_integer([:positive])}_#{:os.getpid()}"
      )

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, tmp_dir: tmp_dir}
  end

  test "the manufactured client's reconcile executes under the admitted-status law", %{
    tmp_dir: tmp_dir
  } do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
             )

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})

    assert {:ok, artifacts, _meta} =
             AshSurface.project(surface, Expo, prefix: "zoela_surface", target_dir: tmp_dir)

    assert is_binary(artifacts["zoela_surface.mjs"])

    copy_runtime!(tmp_dir)
    link_zod!(tmp_dir)
    contract_path = Path.join(tmp_dir, "contract.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    {output, exit_code} =
      System.cmd(
        "node",
        ["test/js/generated_client_reconcile_runner.mjs", tmp_dir, contract_path],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "generated Expo client reconcile failed: #{output}"

    assert {:ok, receipt} =
             Jason.decode(output |> String.trim() |> String.split("\n") |> List.last())

    assert receipt == %{
             "receipt" => "GENERATED_EXPO_RECONCILE_PASS",
             "passThrough" => true,
             "runtimeReconcileDelegated" => true,
             "unreadableThrows" => true,
             "hungEndpointBounded" => true
           }
  end

  defp copy_runtime!(tmp_dir) do
    for file <-
          ~w(ash_surface_runtime.mjs ash_surface_http_transport.mjs ash_surface_channel_transport.mjs) do
      File.cp!(Path.expand(Path.join("priv/static", file)), Path.join(tmp_dir, file))
    end
  end

  defp link_zod!(tmp_dir) do
    File.mkdir_p!(Path.join(tmp_dir, "node_modules"))
    zod_source = Path.expand("node_modules/zod")
    assert File.dir?(zod_source), "npm install must provide node_modules/zod before mix test"

    case File.ln_s(zod_source, Path.join([tmp_dir, "node_modules", "zod"])) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end
end
