if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer.PackageJson do
    @moduledoc false

    @path "assets/package.json"
    @zod_version "^4.0.0"

    def path, do: @path
    def zod_version, do: @zod_version

    @doc "True when the project has an `assets/` directory (on disk or in the igniter)."
    def assets?(igniter) do
      File.dir?("assets") or Igniter.exists?(igniter, @path)
    end

    @doc "Merge `zod` into assets/package.json (created as `{}` when missing). No-op without assets/."
    def add_zod(igniter) do
      if assets?(igniter) do
        igniter
        |> Igniter.create_or_update_file(@path, "{}\n", fn source -> source end)
        |> update(fn pkg ->
          deps = Map.get(pkg, "dependencies", %{})
          Map.put(pkg, "dependencies", Map.put_new(deps, "zod", @zod_version))
        end)
      else
        igniter
      end
    end

    def update(igniter, updater) do
      Igniter.update_file(igniter, @path, fn source ->
        case Jason.decode(source.content) do
          {:ok, pkg} ->
            updated = updater.(pkg)

            if updated == pkg,
              do: source,
              else: Rewrite.Source.update(source, :content, encode(updated))

          {:error, _} ->
            source
        end
      end)
    end

    def encode(data), do: Jason.encode!(data, pretty: true) <> "\n"
  end
end
