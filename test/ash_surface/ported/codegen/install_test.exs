defmodule AshSurface.Ported.Codegen.InstallTest do
  @moduledoc """
  Adaptation of ash_typescript `mix_tasks/install_test.exs` (`mix ash_typescript.install`)
  for `mix ash_surface.install`, driven by `Igniter.Test` against a real in-memory project.

  Reference test -> port:

    * scaffolds zod and valibot config symmetrically -> same six keys, ash_surface names
    * scaffolds the manifest module and core options -> core options (`output_file`,
      `run_endpoint`, `validate_endpoint`) are seeded; the reference's `manifest:` module
      has no ash_surface counterpart (`from_app/2` reads the Ash app directly) and the
      artifact is the single `.mjs` client, not `assets/js/ash_rpc.ts`
    * the four router tests (adds / falls back / uses configured / does not duplicate RPC
      routes) are in `install_gap_test.exs` (loud skips; no server-side RPC controller)
  """
  use ExUnit.Case, async: false

  import Igniter.Test

  defp scaffolded_config do
    test_project()
    |> Igniter.compose_task("ash_surface.install", ["--yes"])
    |> then(fn igniter ->
      igniter.rewrite
      |> Rewrite.source!("config/config.exs")
      |> Rewrite.Source.get(:content)
    end)
  end

  test "scaffolds zod and valibot config symmetrically" do
    config = scaffolded_config()

    assert config =~ "generate_zod_schemas: false"
    assert config =~ ~s(zod_import_path: "zod")
    assert config =~ ~s(zod_schema_suffix: "ZodSchema")

    assert config =~ "generate_valibot_schemas: false"
    assert config =~ ~s(valibot_import_path: "valibot")
    assert config =~ ~s(valibot_schema_suffix: "ValibotSchema")
  end

  test "scaffolds the core options (output file and RPC endpoints)" do
    config = scaffolded_config()

    assert config =~ "config :ash_surface"
    assert config =~ ~s(output_file: "assets/js/ash_surface/ash_surface_client.mjs")
    assert config =~ ~s(run_endpoint: "/rpc/run")
    assert config =~ ~s(validate_endpoint: "/rpc/validate")
    # the reference `manifest:` module is not scaffolded: no ash_surface counterpart
    refute config =~ "manifest:"
  end

  test "every installer-seeded key is written to config and the symmetric set is complete" do
    config = scaffolded_config()
    keys = AshSurface.Installer.default_config() |> Keyword.keys()

    for key <- keys, do: assert(config =~ "#{key}:")

    for key <- ~w(generate_zod_schemas zod_schema_suffix generate_valibot_schemas
                  valibot_import_path valibot_schema_suffix run_endpoint validate_endpoint)a do
      assert key in Keyword.keys(AshSurface.Installer.default_config())
    end
  end
end
