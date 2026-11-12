defmodule AshSurface.Config.ParityKeyCourtsTest do
  # One literal-titled court per config key (the parity gate reads titles structurally).
  # Mutates the :ash_surface application env, so it cannot run async.
  use ExUnit.Case, async: false

  alias AshSurface.Config
  alias AshSurface.Config.Verifier

  @ctx "Record<string, any>"

  setup do
    keys = [:zod_mapping_overrides | Enum.map(Config.parity_keys(), &elem(&1, 0))]
    saved = for k <- keys, do: {k, Application.fetch_env(:ash_surface, k)}
    for k <- keys, do: Application.delete_env(:ash_surface, k)

    on_exit(fn ->
      for {k, v} <- saved do
        case v do
          {:ok, val} -> Application.put_env(:ash_surface, k, val)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)
  end

  test "config.key.add_ash_internals_to_jsdoc default, override, Verifier validation" do
    assert Config.add_ash_internals_to_jsdoc() == false
    Application.put_env(:ash_surface, :add_ash_internals_to_jsdoc, true)
    assert Config.add_ash_internals_to_jsdoc() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :add_ash_internals_to_jsdoc, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "add_ash_internals_to_jsdoc "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.add_ash_internals_to_manifest default, override, Verifier validation" do
    assert Config.add_ash_internals_to_manifest() == false
    Application.put_env(:ash_surface, :add_ash_internals_to_manifest, true)
    assert Config.add_ash_internals_to_manifest() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :add_ash_internals_to_manifest, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "add_ash_internals_to_manifest "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.controller_namespace_output_dir default, override, Verifier validation" do
    assert Config.controller_namespace_output_dir() == nil
    Application.put_env(:ash_surface, :controller_namespace_output_dir, "out/ctl")
    assert Config.controller_namespace_output_dir() == "out/ctl"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :controller_namespace_output_dir, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "controller_namespace_output_dir "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.enable_controller_namespace_files default, override, Verifier validation" do
    assert Config.enable_controller_namespace_files() == false
    Application.put_env(:ash_surface, :enable_controller_namespace_files, true)
    assert Config.enable_controller_namespace_files() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :enable_controller_namespace_files, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "enable_controller_namespace_files "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.enable_namespace_files default, override, Verifier validation" do
    assert Config.enable_namespace_files() == false
    Application.put_env(:ash_surface, :enable_namespace_files, true)
    assert Config.enable_namespace_files() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :enable_namespace_files, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "enable_namespace_files "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.generate_phx_channel_rpc_actions default, override, Verifier validation" do
    assert Config.generate_phx_channel_rpc_actions() == false
    Application.put_env(:ash_surface, :generate_phx_channel_rpc_actions, true)
    assert Config.generate_phx_channel_rpc_actions() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :generate_phx_channel_rpc_actions, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "generate_phx_channel_rpc_actions "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.generate_valibot_schemas default, override, Verifier validation" do
    assert Config.generate_valibot_schemas() == false
    Application.put_env(:ash_surface, :generate_valibot_schemas, true)
    assert Config.generate_valibot_schemas() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :generate_valibot_schemas, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "generate_valibot_schemas "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.generate_validation_functions default, override, Verifier validation" do
    assert Config.generate_validation_functions() == false
    Application.put_env(:ash_surface, :generate_validation_functions, true)
    assert Config.generate_validation_functions() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :generate_validation_functions, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "generate_validation_functions "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.generate_zod_schemas default, override, Verifier validation" do
    assert Config.generate_zod_schemas() == false
    Application.put_env(:ash_surface, :generate_zod_schemas, true)
    assert Config.generate_zod_schemas() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :generate_zod_schemas, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "generate_zod_schemas "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.import_into_generated default, override, Verifier validation" do
    assert Config.import_into_generated() == nil
    Application.put_env(:ash_surface, :import_into_generated, [%{import_name: "T", file: "./t"}])
    assert Config.import_into_generated() == [%{import_name: "T", file: "./t"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :import_into_generated, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "import_into_generated "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.input_field_formatter default, override, Verifier validation" do
    assert Config.input_field_formatter() == :camel_case
    Application.put_env(:ash_surface, :input_field_formatter, :snake_case)
    assert Config.input_field_formatter() == :snake_case
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :input_field_formatter, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "input_field_formatter "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.json_manifest_file default, override, Verifier validation" do
    assert Config.json_manifest_file() == nil
    Application.put_env(:ash_surface, :json_manifest_file, "m.json")
    assert Config.json_manifest_file() == "m.json"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :json_manifest_file, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "json_manifest_file "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.json_manifest_filename_format default, override, Verifier validation" do
    assert Config.json_manifest_filename_format() == :relative
    Application.put_env(:ash_surface, :json_manifest_filename_format, :basename)
    assert Config.json_manifest_filename_format() == :basename
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :json_manifest_filename_format, :nope)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "json_manifest_filename_format "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.manifest default, override, Verifier validation" do
    assert Config.manifest() == nil
    Application.put_env(:ash_surface, :manifest, __MODULE__)
    assert Config.manifest() == __MODULE__
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :manifest, "Mod")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "manifest "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.manifest_file default, override, Verifier validation" do
    assert Config.manifest_file() == nil
    Application.put_env(:ash_surface, :manifest_file, "m.md")
    assert Config.manifest_file() == "m.md"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :manifest_file, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "manifest_file "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.namespace_output_dir default, override, Verifier validation" do
    assert Config.namespace_output_dir() == nil
    Application.put_env(:ash_surface, :namespace_output_dir, "out/ns")
    assert Config.namespace_output_dir() == "out/ns"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :namespace_output_dir, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "namespace_output_dir "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.not_found_error? default, override, Verifier validation" do
    assert Config.not_found_error?() == true
    Application.put_env(:ash_surface, :not_found_error?, false)
    assert Config.not_found_error?() == false
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :not_found_error?, "no")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "not_found_error? "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.phoenix_import_path default, override, Verifier validation" do
    assert Config.phoenix_import_path() == "phoenix"
    Application.put_env(:ash_surface, :phoenix_import_path, "my-phoenix")
    assert Config.phoenix_import_path() == "my-phoenix"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :phoenix_import_path, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "phoenix_import_path "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.policies default, override, Verifier validation" do
    assert Config.policies() == nil
    Application.put_env(:ash_surface, :policies, show_policy_breakdowns?: true)
    assert Config.policies() == [show_policy_breakdowns?: true]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :policies, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "policies "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.router default, override, Verifier validation" do
    assert Config.router() == nil
    Application.put_env(:ash_surface, :router, __MODULE__)
    assert Config.router() == __MODULE__
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :router, "Router")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "router "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_after_channel_response_hook default, override, Verifier validation" do
    assert Config.rpc_action_after_channel_response_hook() == nil
    Application.put_env(:ash_surface, :rpc_action_after_channel_response_hook, "hookA")
    assert Config.rpc_action_after_channel_response_hook() == "hookA"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_after_channel_response_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_after_channel_response_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_after_request_hook default, override, Verifier validation" do
    assert Config.rpc_action_after_request_hook() == nil
    Application.put_env(:ash_surface, :rpc_action_after_request_hook, "hookB")
    assert Config.rpc_action_after_request_hook() == "hookB"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_after_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_after_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_before_channel_push_hook default, override, Verifier validation" do
    assert Config.rpc_action_before_channel_push_hook() == nil
    Application.put_env(:ash_surface, :rpc_action_before_channel_push_hook, "hookC")
    assert Config.rpc_action_before_channel_push_hook() == "hookC"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_before_channel_push_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_before_channel_push_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_before_request_hook default, override, Verifier validation" do
    assert Config.rpc_action_before_request_hook() == nil
    Application.put_env(:ash_surface, :rpc_action_before_request_hook, "hookD")
    assert Config.rpc_action_before_request_hook() == "hookD"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_before_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_before_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_channel_hook_context_type default, override, Verifier validation" do
    assert Config.rpc_action_channel_hook_context_type() == @ctx
    Application.put_env(:ash_surface, :rpc_action_channel_hook_context_type, "Ctx")
    assert Config.rpc_action_channel_hook_context_type() == "Ctx"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_channel_hook_context_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_channel_hook_context_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_action_hook_context_type default, override, Verifier validation" do
    assert Config.rpc_action_hook_context_type() == @ctx
    Application.put_env(:ash_surface, :rpc_action_hook_context_type, "Ctx")
    assert Config.rpc_action_hook_context_type() == "Ctx"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_action_hook_context_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_action_hook_context_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_after_channel_response_hook default, override, Verifier validation" do
    assert Config.rpc_validation_after_channel_response_hook() == nil
    Application.put_env(:ash_surface, :rpc_validation_after_channel_response_hook, "hookE")
    assert Config.rpc_validation_after_channel_response_hook() == "hookE"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_after_channel_response_hook, 5)
    assert {:error, errs} = Verifier.verify()

    assert Enum.any?(
             errs,
             &String.starts_with?(&1, "rpc_validation_after_channel_response_hook ")
           )

    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_after_request_hook default, override, Verifier validation" do
    assert Config.rpc_validation_after_request_hook() == nil
    Application.put_env(:ash_surface, :rpc_validation_after_request_hook, "hookF")
    assert Config.rpc_validation_after_request_hook() == "hookF"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_after_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_validation_after_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_before_channel_push_hook default, override, Verifier validation" do
    assert Config.rpc_validation_before_channel_push_hook() == nil
    Application.put_env(:ash_surface, :rpc_validation_before_channel_push_hook, "hookG")
    assert Config.rpc_validation_before_channel_push_hook() == "hookG"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_before_channel_push_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_validation_before_channel_push_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_before_request_hook default, override, Verifier validation" do
    assert Config.rpc_validation_before_request_hook() == nil
    Application.put_env(:ash_surface, :rpc_validation_before_request_hook, "hookH")
    assert Config.rpc_validation_before_request_hook() == "hookH"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_before_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_validation_before_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_channel_hook_context_type default, override, Verifier validation" do
    assert Config.rpc_validation_channel_hook_context_type() == @ctx
    Application.put_env(:ash_surface, :rpc_validation_channel_hook_context_type, "Ctx")
    assert Config.rpc_validation_channel_hook_context_type() == "Ctx"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_channel_hook_context_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_validation_channel_hook_context_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.rpc_validation_hook_context_type default, override, Verifier validation" do
    assert Config.rpc_validation_hook_context_type() == @ctx
    Application.put_env(:ash_surface, :rpc_validation_hook_context_type, "Ctx")
    assert Config.rpc_validation_hook_context_type() == "Ctx"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :rpc_validation_hook_context_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "rpc_validation_hook_context_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.run_endpoint default, override, Verifier validation" do
    assert Config.run_endpoint() == "/rpc/run"
    Application.put_env(:ash_surface, :run_endpoint, "/api/run")
    assert Config.run_endpoint() == "/api/run"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :run_endpoint, "run")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "run_endpoint "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.source_path_prefix default, override, Verifier validation" do
    assert Config.source_path_prefix() == ""
    Application.put_env(:ash_surface, :source_path_prefix, "lib/")
    assert Config.source_path_prefix() == "lib/"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :source_path_prefix, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "source_path_prefix "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.type_mapping_overrides default, override, Verifier validation" do
    assert Config.type_mapping_overrides() == []
    Application.put_env(:ash_surface, :type_mapping_overrides, [{Ash.Type.UUID, "z.string()"}])
    assert Config.type_mapping_overrides() == [{Ash.Type.UUID, "z.string()"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :type_mapping_overrides, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "type_mapping_overrides "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_channels default, override, Verifier validation" do
    assert Config.typed_channels() == []
    Application.put_env(:ash_surface, :typed_channels, [__MODULE__])
    assert Config.typed_channels() == [__MODULE__]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_channels, :bad)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_channels "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_channels_output_file default, override, Verifier validation" do
    assert Config.typed_channels_output_file() == nil
    Application.put_env(:ash_surface, :typed_channels_output_file, "ch.mjs")
    assert Config.typed_channels_output_file() == "ch.mjs"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_channels_output_file, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_channels_output_file "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_after_request_hook default, override, Verifier validation" do
    assert Config.typed_controller_after_request_hook() == nil
    Application.put_env(:ash_surface, :typed_controller_after_request_hook, "hookI")
    assert Config.typed_controller_after_request_hook() == "hookI"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_after_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_after_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_base_path default, override, Verifier validation" do
    assert Config.typed_controller_base_path() == ""
    Application.put_env(:ash_surface, :typed_controller_base_path, "/api")
    assert Config.typed_controller_base_path() == "/api"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_base_path, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_base_path "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_before_request_hook default, override, Verifier validation" do
    assert Config.typed_controller_before_request_hook() == nil
    Application.put_env(:ash_surface, :typed_controller_before_request_hook, "hookJ")
    assert Config.typed_controller_before_request_hook() == "hookJ"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_before_request_hook, 5)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_before_request_hook "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_error_handler default, override, Verifier validation" do
    assert Config.typed_controller_error_handler() == nil
    Application.put_env(:ash_surface, :typed_controller_error_handler, {__MODULE__, :handle, []})
    assert Config.typed_controller_error_handler() == {__MODULE__, :handle, []}
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_error_handler, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_error_handler "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_hook_context_type default, override, Verifier validation" do
    assert Config.typed_controller_hook_context_type() == @ctx
    Application.put_env(:ash_surface, :typed_controller_hook_context_type, "Ctx")
    assert Config.typed_controller_hook_context_type() == "Ctx"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_hook_context_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_hook_context_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_import_into_generated default, override, Verifier validation" do
    assert Config.typed_controller_import_into_generated() == []

    Application.put_env(:ash_surface, :typed_controller_import_into_generated, [
      %{import_name: "T", file: "./t"}
    ])

    assert Config.typed_controller_import_into_generated() == [%{import_name: "T", file: "./t"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_import_into_generated, :bad)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_import_into_generated "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_mode default, override, Verifier validation" do
    assert Config.typed_controller_mode() == :full
    Application.put_env(:ash_surface, :typed_controller_mode, :paths_only)
    assert Config.typed_controller_mode() == :paths_only
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_mode, :nope)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_mode "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_path_params_style default, override, Verifier validation" do
    assert Config.typed_controller_path_params_style() == :object
    Application.put_env(:ash_surface, :typed_controller_path_params_style, :args)
    assert Config.typed_controller_path_params_style() == :args
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_path_params_style, :nope)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_path_params_style "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controller_show_raised_errors default, override, Verifier validation" do
    assert Config.typed_controller_show_raised_errors() == false
    Application.put_env(:ash_surface, :typed_controller_show_raised_errors, true)
    assert Config.typed_controller_show_raised_errors() == true
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controller_show_raised_errors, "yes")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controller_show_raised_errors "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.typed_controllers default, override, Verifier validation" do
    assert Config.typed_controllers() == []
    Application.put_env(:ash_surface, :typed_controllers, [__MODULE__])
    assert Config.typed_controllers() == [__MODULE__]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :typed_controllers, :bad)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "typed_controllers "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.untyped_map_type default, override, Verifier validation" do
    assert Config.untyped_map_type() == "Record<string, any>"
    Application.put_env(:ash_surface, :untyped_map_type, "unknown")
    assert Config.untyped_map_type() == "unknown"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :untyped_map_type, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "untyped_map_type "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.valibot_import_into_generated default, override, Verifier validation" do
    assert Config.valibot_import_into_generated() == []

    Application.put_env(:ash_surface, :valibot_import_into_generated, [
      %{import_name: "V", file: "./v"}
    ])

    assert Config.valibot_import_into_generated() == [%{import_name: "V", file: "./v"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :valibot_import_into_generated, :bad)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "valibot_import_into_generated "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.valibot_import_path default, override, Verifier validation" do
    assert Config.valibot_import_path() == "valibot"
    Application.put_env(:ash_surface, :valibot_import_path, "valibot/x")
    assert Config.valibot_import_path() == "valibot/x"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :valibot_import_path, "")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "valibot_import_path "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.valibot_mapping_overrides default, override, Verifier validation" do
    assert Config.valibot_mapping_overrides() == []
    Application.put_env(:ash_surface, :valibot_mapping_overrides, [{Ash.Type.UUID, "v.string()"}])
    assert Config.valibot_mapping_overrides() == [{Ash.Type.UUID, "v.string()"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :valibot_mapping_overrides, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "valibot_mapping_overrides "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.valibot_schema_suffix default, override, Verifier validation" do
    assert Config.valibot_schema_suffix() == "ValibotSchema"
    Application.put_env(:ash_surface, :valibot_schema_suffix, "Vs")
    assert Config.valibot_schema_suffix() == "Vs"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :valibot_schema_suffix, "1 bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "valibot_schema_suffix "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.validate_endpoint default, override, Verifier validation" do
    assert Config.validate_endpoint() == "/rpc/validate"
    Application.put_env(:ash_surface, :validate_endpoint, "/api/validate")
    assert Config.validate_endpoint() == "/api/validate"
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :validate_endpoint, "validate")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "validate_endpoint "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.warn_on_missing_channel_returns default, override, Verifier validation" do
    assert Config.warn_on_missing_channel_returns() == true
    Application.put_env(:ash_surface, :warn_on_missing_channel_returns, false)
    assert Config.warn_on_missing_channel_returns() == false
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :warn_on_missing_channel_returns, "no")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "warn_on_missing_channel_returns "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.warn_on_non_public_publications default, override, Verifier validation" do
    assert Config.warn_on_non_public_publications() == true
    Application.put_env(:ash_surface, :warn_on_non_public_publications, false)
    assert Config.warn_on_non_public_publications() == false
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :warn_on_non_public_publications, "no")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "warn_on_non_public_publications "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.warn_on_non_rpc_references default, override, Verifier validation" do
    assert Config.warn_on_non_rpc_references() == true
    Application.put_env(:ash_surface, :warn_on_non_rpc_references, false)
    assert Config.warn_on_non_rpc_references() == false
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :warn_on_non_rpc_references, "no")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "warn_on_non_rpc_references "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end

  test "config.key.zod_mapping_overrides default, override, Verifier validation" do
    assert Config.zod_mapping_overrides() == []
    Application.put_env(:ash_surface, :zod_mapping_overrides, [{Ash.Type.UUID, "z.string()"}])
    assert Config.zod_mapping_overrides() == [{Ash.Type.UUID, "z.string()"}]
    assert Verifier.verify() == :ok
    Application.put_env(:ash_surface, :zod_mapping_overrides, "bad")
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &String.starts_with?(&1, "zod_mapping_overrides "))
    assert_raise ArgumentError, fn -> Verifier.verify!() end
  end
end
