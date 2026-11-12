defmodule AshSurface.Ported.Rpc.B.ManifestGeneratorConfigTest do
  @moduledoc """
  Counterpart of the config-accessor tests in ash_typescript `rpc/manifest_generator_test`
  ("config functions") and `rpc/json_manifest_generator_test` ("config accessor").

  Changes: `AshTypescript.Rpc.manifest_file/0`, `add_ash_internals_to_manifest?/0`,
  `json_manifest_file/0` become `AshSurface.Config` accessors over the `:ash_surface` env;
  the reference reads a path preset by its test config, here the test sets the env value
  itself (restored on exit) because ash_surface ships no preset. `add_ash_internals_to_manifest`
  is exposed as the raw boolean key (no `?` suffix). The generator-output describes live in
  `manifest_generator_gap_test.exs` / `json_manifest_generator_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  @keys [:manifest_file, :json_manifest_file, :add_ash_internals_to_manifest]

  setup do
    snapshot = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}

    on_exit(fn ->
      for {k, res} <- snapshot do
        case res do
          {:ok, v} -> Application.put_env(:ash_surface, k, v)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)

    :ok
  end

  describe "config functions" do
    test "manifest_file/0 returns configured path" do
      Application.put_env(:ash_surface, :manifest_file, "./test/ts/MANIFEST.md")
      assert AshSurface.Config.manifest_file() == "./test/ts/MANIFEST.md"
    end

    test "add_ash_internals_to_manifest?/0 returns configured value" do
      Application.put_env(:ash_surface, :add_ash_internals_to_manifest, true)
      assert AshSurface.Config.add_ash_internals_to_manifest() == true

      Application.put_env(:ash_surface, :add_ash_internals_to_manifest, false)
      assert AshSurface.Config.add_ash_internals_to_manifest() == false
    end

    test "add_ash_internals_to_manifest?/0 defaults to false" do
      Application.delete_env(:ash_surface, :add_ash_internals_to_manifest)
      assert AshSurface.Config.add_ash_internals_to_manifest() == false
    end
  end

  describe "config defaults" do
    test "manifest_file/0 and json_manifest_file/0 default to nil (no output path)" do
      Application.delete_env(:ash_surface, :manifest_file)
      Application.delete_env(:ash_surface, :json_manifest_file)
      assert AshSurface.Config.manifest_file() == nil
      assert AshSurface.Config.json_manifest_file() == nil
    end
  end

  describe "zod/error config defaults" do
    setup do
      keys = [
        :zod_import_into_generated,
        :zod_import_path,
        :show_raised_errors,
        :zod_schema_suffix,
        :zod_object_mode,
        :zod_infer_types,
        :show_policy_breakdowns
      ]
      snap = for k <- keys, do: {k, Application.fetch_env(:ash_surface, k)}

      on_exit(fn ->
        for {k, res} <- snap do
          case res do
            {:ok, v} -> Application.put_env(:ash_surface, k, v)
            :error -> Application.delete_env(:ash_surface, k)
          end
        end
      end)

      for k <- keys, do: Application.delete_env(:ash_surface, k)
      :ok
    end

    test "zod_import_into_generated/0 defaults to false" do
      assert AshSurface.Config.zod_import_into_generated() == false
    end

    test "zod_import_path/0 defaults to \"zod\"" do
      assert AshSurface.Config.zod_import_path() == "zod"
    end

    test "show_raised_errors/0 defaults to false" do
      assert AshSurface.Config.show_raised_errors() == false
    end

    test "zod_schema_suffix/0 defaults to \"ZodSchema\"" do
      assert AshSurface.Config.zod_schema_suffix() == "ZodSchema"
    end

    test "zod_object_mode/0 defaults to :strip" do
      assert AshSurface.Config.zod_object_mode() == :strip
    end

    test "zod_infer_types/0 defaults to true" do
      assert AshSurface.Config.zod_infer_types() == true
    end

    test "show_policy_breakdowns/0 defaults to false" do
      assert AshSurface.Config.show_policy_breakdowns() == false
    end

    test "configured values override the defaults" do
      Application.put_env(:ash_surface, :zod_import_into_generated, true)
      Application.put_env(:ash_surface, :zod_import_path, "zod/v4")
      Application.put_env(:ash_surface, :show_raised_errors, true)
      assert AshSurface.Config.zod_import_into_generated() == true
      assert AshSurface.Config.zod_import_path() == "zod/v4"
      assert AshSurface.Config.show_raised_errors() == true
    end
  end

  describe "config accessor" do
    test "json_manifest_file/0 returns configured path" do
      Application.put_env(:ash_surface, :json_manifest_file, "./test/ts/ash_rpc_manifest.json")
      assert AshSurface.Config.json_manifest_file() == "./test/ts/ash_rpc_manifest.json"
    end
  end
end
