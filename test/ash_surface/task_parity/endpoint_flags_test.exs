defmodule AshSurface.TaskParity.EndpointFlagsTest do
  # Mutates the :ash_surface application env, so it cannot run async.
  use ExUnit.Case, async: false

  alias AshSurface.Projectors.JS

  @root Path.expand("../../..", __DIR__)

  setup do
    saved =
      for k <- [:run_endpoint, :validate_endpoint],
          do: {k, Application.fetch_env(:ash_surface, k)}

    for {k, _} <- saved, do: Application.delete_env(:ash_surface, k)

    on_exit(fn ->
      for {k, v} <- saved do
        case v do
          {:ok, val} -> Application.put_env(:ash_surface, k, val)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)
  end

  defp codegen(args) do
    # inside the repo so the artifact's `zod` import resolves from node_modules
    dir = Path.join(@root, "_build/ash_surface_ep_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    file = Path.join(dir, "client.mjs")
    Mix.Task.reenable("ash_surface.codegen")

    ExUnit.CaptureIO.capture_io(fn ->
      Mix.Tasks.AshSurface.Codegen.run(["--output", file, "--no-runtime" | args])
    end)

    file
  end

  defp endpoints_under_node(file) do
    script =
      ~s|const m = await import(#{Jason.encode!("file://" <> file)}); | <>
        ~s|console.log(JSON.stringify([m.AshSurfaceEndpoints ?? null, Object.isFrozen(m.AshSurfaceEndpoints ?? {})]))|

    {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: @root)
    Jason.decode!(String.trim(out))
  end

  test "task.codegen.flag.run_endpoint flag, alias and config reach the artifact" do
    file = codegen(["--run-endpoint", "/api/run"])
    assert [%{"run" => "/api/run"}, true] = endpoints_under_node(file)
    refute File.read!(file) =~ "validate:"

    file = codegen(["-r", "/api/alias"])
    assert [%{"run" => "/api/alias"}, true] = endpoints_under_node(file)

    Application.put_env(:ash_surface, :run_endpoint, "/cfg/run")
    assert [%{"run" => "/cfg/run"}, true] = endpoints_under_node(codegen([]))
    # the flag outranks configuration
    assert [%{"run" => "/flag/run"}, true] = endpoints_under_node(codegen(["-r", "/flag/run"]))
  end

  test "task.codegen.flag.validate_endpoint flag, alias and config reach the artifact" do
    file = codegen(["--validate-endpoint", "/api/validate"])
    assert [%{"validate" => "/api/validate"}, true] = endpoints_under_node(file)
    refute File.read!(file) =~ "run:"

    file = codegen(["-v", "/api/alias", "-r", "/api/run"])
    assert [%{"run" => "/api/run", "validate" => "/api/alias"}, true] = endpoints_under_node(file)

    Application.put_env(:ash_surface, :validate_endpoint, "/cfg/validate")
    assert [%{"validate" => "/cfg/validate"}, true] = endpoints_under_node(codegen([]))
  end

  test "an unconfigured, flagless run emits no endpoints (bytes unchanged) and a bad path is refused typed" do
    refute File.read!(codegen([])) =~ "AshSurfaceEndpoints"

    assert {:error, {:invalid_endpoint, :run_endpoint, "no-slash"}} =
             JS.project_ir([], run_endpoint: "no-slash")

    assert {:error, {:invalid_endpoint, :validate_endpoint, 42}} =
             JS.project_ir([], validate_endpoint: 42)

    assert {:ok, %{"ash_surface_client.mjs" => code}, _} =
             JS.project_ir([], run_endpoint: "/r", validate_endpoint: "/v")

    assert code =~ ~s|run: "/r"|
    assert code =~ ~s|validate: "/v"|
  end
end
