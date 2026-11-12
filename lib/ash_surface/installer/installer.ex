if Code.ensure_loaded?(Igniter) do
  defmodule AshSurface.Installer do
    @moduledoc false

    @doc "Config keys the installer seeds with `Igniter.Project.Config.configure_new/5`."
    def default_config do
      [
        output_file: "assets/js/ash_surface/ash_surface_client.mjs",
        run_endpoint: "/rpc/run",
        validate_endpoint: "/rpc/validate",
        generate_zod_schemas: false,
        zod_import_path: "zod",
        zod_schema_suffix: "ZodSchema",
        zod_object_mode: :strip,
        generate_valibot_schemas: false,
        valibot_import_path: "valibot",
        valibot_schema_suffix: "ValibotSchema"
      ]
    end
  end
end
