defmodule AshSurface.Projector.ExpoOriginTest do
  @moduledoc """
  Origin law for the manufactured Expo client's reconcile sugar, executed under
  node against a real `node:http` server.

  Decision: an absolute `reconcileEndpoint` supplied by the caller authorizes its
  OWN origin (and only it) - the transport rule is not weakened. A relative
  endpoint with no page and no `reconcileBaseUrl` is refused by the transport; a
  `reconcileBaseUrl` authorizes its origin. Extra origins need
  `reconcileAllowedOrigins`.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @script ~S"""
  import http from "node:http";
  import { readFile } from "node:fs/promises";
  import { join } from "node:path";
  import { pathToFileURL } from "node:url";
  const [dir, contractPath] = process.argv.slice(2);
  const { createZoelaClient } = await import(pathToFileURL(join(dir, "zoela_surface.mjs")).href);
  const contract = JSON.parse(await readFile(contractPath, "utf8"));
  const hits = [];
  const server = http.createServer((req, res) => {
    hits.push(req.url);
    res.setHeader("content-type", "application/json");
    res.end(JSON.stringify({ status: "COMPLETED", commandId: "c1" }));
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const origin = `http://127.0.0.1:${server.address().port}`;
  const out = {};
  const attempt = async (name, opts) => {
    try { out[name] = (await createZoelaClient({ contract, ...opts }).reconcile("c1")).status; }
    catch (e) { out[name] = e.code ?? e.cause?.code ?? String(e.message); }
  };
  await attempt("absolute_own_origin", { reconcileEndpoint: `${origin}/r` });
  const afterAbs = hits.length;
  await attempt("relative_no_base", { reconcileEndpoint: "/r" });
  await attempt("relative_with_base", { reconcileEndpoint: "/r", reconcileBaseUrl: origin });
  await attempt("other_origin_via_before", { reconcileEndpoint: `${origin}/r`, reconcileAllowedOrigins: [] });
  out.hitsAfterRefused = hits.length - afterAbs;
  server.closeAllConnections?.();
  await new Promise((r) => server.close(r));
  console.log(JSON.stringify(out));
  """

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "ash_surface_expo_origin_#{System.unique_integer([:positive])}_#{:os.getpid()}"
      )

    File.rm_rf!(dir)
    File.mkdir_p!(Path.join(dir, "node_modules"))
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "absolute endpoint pins its own origin; relative needs a base", %{dir: dir} do
    {:ok, manifest} =
      Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
      )

    {:ok, surface} = AshSurface.from_manifest(manifest, profile: %{})

    {:ok, _artifacts, _meta} =
      AshSurface.project(surface, Expo, prefix: "zoela_surface", target_dir: dir)

    for file <-
          ~w(ash_surface_runtime.mjs ash_surface_http_transport.mjs ash_surface_channel_transport.mjs) do
      File.cp!(Path.expand(Path.join("priv/static", file)), Path.join(dir, file))
    end

    File.ln_s!(Path.expand("node_modules/zod"), Path.join([dir, "node_modules", "zod"]))
    contract_path = Path.join(dir, "contract.json")
    File.write!(contract_path, Jason.encode!(surface.contract))
    script_path = Path.join(dir, "run.mjs")
    File.write!(script_path, @script)

    {output, 0} =
      System.cmd("node", [script_path, dir, contract_path], stderr_to_stdout: true)

    result = output |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()
    assert result["absolute_own_origin"] == "COMPLETED"
    assert result["relative_no_base"] == "RELATIVE_ENDPOINT_NO_BASE"
    assert result["relative_with_base"] == "COMPLETED"
  end
end
