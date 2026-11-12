if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer.Esbuild do
    @moduledoc false
    # Phoenix esbuild: the generated client must live under assets/js (the esbuild entry
    # tree) and `zod` must resolve from assets/node_modules.

    alias AshSurface.Installer.Framework

    @doc "Seeds `:output_file` under the esbuild tree (configure_new never overwrites)."
    def patch(igniter) do
      if Framework.detect(igniter) == :esbuild do
        Igniter.Project.Config.configure_new(
          igniter,
          "config.exs",
          :ash_surface,
          [:output_file],
          Framework.output_file(igniter)
        )
      else
        igniter
      end
    end

    def notice,
      do:
        "esbuild detected: import the generated client from assets/js/app.js " <>
          "(`import \"./ash_surface/ash_surface_client.mjs\"`); zod resolves from assets/node_modules."
  end
end
