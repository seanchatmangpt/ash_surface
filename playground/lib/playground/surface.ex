defmodule Playground.Surface do
  @moduledoc """
  Compile-only view of the REUSED fixture Ash domain `AshSurface.ZodFixtures.*`
  (defined in `../test/support/zod_fixtures.ex`).

  Pipeline: Ash domain -> `Ash.Info.Manifest` -> `AshSurface.Compiler.compile/1`
  (IR per resource action) -> `AshSurface.IR.Codec.to_map/1` (contract JSON) and
  `AshSurface.Projectors.JS.project_ir/1` (emitted `.mjs` with Zod schemas).

  Nothing here executes an Ash action; there is no data-layer call and no network.
  """

  @otp_app :ash_surface_zod_fixtures
  @artifact "ash_surface_client.mjs"

  @doc "Compiled snapshot, memoised in :persistent_term (compile is pure)."
  def snapshot do
    case :persistent_term.get({__MODULE__, :snapshot}, nil) do
      nil ->
        snap = build!()
        :persistent_term.put({__MODULE__, :snapshot}, snap)
        snap

      snap ->
        snap
    end
  end

  defp build! do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.ZodFixtures.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    {:ok, irs} = AshSurface.Compiler.compile(manifest)
    irs = List.wrap(irs)
    {:ok, artifacts, meta} = AshSurface.Projectors.JS.project_ir(irs)

    entries =
      irs
      |> Enum.with_index()
      |> Enum.map(fn {ir, idx} ->
        %{
          id: idx,
          resource: inspect(ir.ash.resource),
          action: to_string(ir.ash.action),
          action_type: to_string(ir.ash.action_type),
          actionId: "#{ir.ash.resource |> Module.split() |> List.last()}.#{ir.ash.action}",
          digest: ir.digest,
          contract: ir |> AshSurface.IR.Codec.to_map() |> Jason.encode!(pretty: true)
        }
      end)

    %{entries: entries, artifact: Map.fetch!(artifacts, @artifact), meta: meta}
  end
end
