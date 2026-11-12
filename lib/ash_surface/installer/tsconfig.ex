if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer.Tsconfig do
    @moduledoc false

    @path "assets/tsconfig.json"
    @required %{
      "module" => "ESNext",
      "moduleResolution" => "bundler",
      "esModuleInterop" => true
    }

    def path, do: @path
    def required, do: @required

    @doc "Idempotently patch compilerOptions. Creates the file when assets/ exists; unparseable files are left alone."
    def patch(igniter) do
      if AshSurface.Installer.PackageJson.assets?(igniter) do
        initial = encode(%{"compilerOptions" => @required})

        Igniter.create_or_update_file(igniter, @path, initial, fn source ->
          case Jason.decode(source.content) do
            {:ok, %{} = ts} ->
              opts = Map.get(ts, "compilerOptions", %{})
              updated = Map.put(ts, "compilerOptions", Map.merge(opts, @required))

              if updated == ts,
                do: source,
                else: Rewrite.Source.update(source, :content, encode(updated))

            _ ->
              source
          end
        end)
      else
        igniter
      end
    end

    defp encode(data), do: Jason.encode!(data, pretty: true) <> "\n"
  end
end
