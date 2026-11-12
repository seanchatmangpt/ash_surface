if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer.Framework do
    @moduledoc false
    # Detects the host JS bundler from real project files so the generated `.mjs`
    # lands where the bundler resolves it. Pure file observation: no shelling out.

    @default "assets/js/ash_surface/ash_surface_client.mjs"
    @vite_configs ~w(assets/vite.config.js assets/vite.config.mjs assets/vite.config.ts
                     vite.config.js vite.config.mjs vite.config.ts)

    @type bundler :: :vite | :esbuild | :none

    @doc "Detects `:vite`, `:esbuild` (Phoenix default) or `:none`."
    @spec detect(Igniter.t()) :: bundler()
    def detect(igniter) do
      cond do
        Enum.any?(@vite_configs, &Igniter.exists?(igniter, &1)) or dep?(igniter, "vite") ->
          :vite

        esbuild_configured?(igniter) ->
          :esbuild

        true ->
          :none
      end
    end

    @doc "Directory (relative) that holds the project's JS sources for the detected bundler."
    @spec js_root(Igniter.t()) :: String.t()
    def js_root(igniter) do
      cond do
        Igniter.exists?(igniter, "assets/package.json") or File.dir?("assets") ->
          "assets/js"

        Enum.any?(
          ~w(vite.config.js vite.config.mjs vite.config.ts),
          &Igniter.exists?(igniter, &1)
        ) ->
          "src"

        true ->
          "assets/js"
      end
    end

    @doc "Output file path for the generated client, inside the bundler's source tree."
    @spec output_file(Igniter.t()) :: String.t()
    def output_file(igniter) do
      case js_root(igniter) do
        "assets/js" -> @default
        root -> Path.join(root, "ash_surface/ash_surface_client.mjs")
      end
    end

    defp dep?(igniter, name) do
      Enum.any?(~w(assets/package.json package.json), fn path ->
        with true <- Igniter.exists?(igniter, path),
             {:ok, pkg} <- igniter.rewrite |> Rewrite.source!(path) |> content() |> Jason.decode() do
          Map.has_key?(Map.get(pkg, "dependencies", %{}), name) or
            Map.has_key?(Map.get(pkg, "devDependencies", %{}), name)
        else
          _ -> false
        end
      end)
    end

    defp content(source), do: Rewrite.Source.get(source, :content)

    defp esbuild_configured?(igniter) do
      Igniter.exists?(igniter, "config/config.exs") and
        igniter.rewrite
        |> Rewrite.source!("config/config.exs")
        |> content()
        |> String.contains?("config :esbuild")
    end
  end
end
