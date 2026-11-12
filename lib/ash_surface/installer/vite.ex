if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer.Vite do
    @moduledoc false
    # Vite (phoenix_vite or standalone): output goes under the Vite source root
    # (assets/js for Phoenix, src/ for a root-level vite.config).

    alias AshSurface.Installer.Framework

    @doc "Seeds `:output_file` under the Vite source tree (configure_new never overwrites)."
    def patch(igniter) do
      if Framework.detect(igniter) == :vite do
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
        "vite detected: the generated client is plain ESM (.mjs) and is picked up by Vite " <>
          "without extra plugins; zod resolves from node_modules."
  end
end
