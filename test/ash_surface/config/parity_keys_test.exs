defmodule AshSurface.Config.ParityKeysTest do
  # Mutates the :ash_surface application env, so it cannot run async.
  use ExUnit.Case, async: false

  alias AshSurface.Config
  alias AshSurface.Config.Verifier

  # {key, default, valid override, invalid override}. Keys, names, defaults mirror
  # ash_typescript (`Application.get_env(:ash_typescript, key, default)`).
  @ctx "Record<string, any>"
  @cases [
    {:add_ash_internals_to_jsdoc, false, true, "yes"},
    {:add_ash_internals_to_manifest, false, true, "yes"},
    {:controller_namespace_output_dir, nil, "out/ctl", 5},
    {:enable_controller_namespace_files, false, true, "yes"},
    {:enable_namespace_files, false, true, "yes"},
    {:generate_phx_channel_rpc_actions, false, true, "yes"},
    {:generate_valibot_schemas, false, true, "yes"},
    {:generate_validation_functions, false, true, "yes"},
    {:generate_zod_schemas, false, true, "yes"},
    {:import_into_generated, nil, [%{import_name: "T", file: "./t"}], "bad"},
    {:input_field_formatter, :camel_case, :snake_case, 5},
    {:json_manifest_file, nil, "m.json", 5},
    {:json_manifest_filename_format, :relative, :basename, :nope},
    {:manifest, nil, __MODULE__, "Mod"},
    {:manifest_file, nil, "m.md", 5},
    {:namespace_output_dir, nil, "out/ns", 5},
    {:not_found_error?, true, false, "no"},
    {:output_field_formatter, :camel_case, :snake_case, 5},
    {:phoenix_import_path, "phoenix", "my-phoenix", ""},
    {:policies, nil, [show_policy_breakdowns?: true], "bad"},
    {:require_tenant_parameters, false, true, "yes"},
    {:router, nil, __MODULE__, "Router"},
    {:rpc_action_after_channel_response_hook, nil, "hookA", 5},
    {:rpc_action_after_request_hook, nil, "hookB", 5},
    {:rpc_action_before_channel_push_hook, nil, "hookC", 5},
    {:rpc_action_before_request_hook, nil, "hookD", 5},
    {:rpc_action_channel_hook_context_type, @ctx, "Ctx", ""},
    {:rpc_action_hook_context_type, @ctx, "Ctx", ""},
    {:rpc_validation_after_channel_response_hook, nil, "hookE", 5},
    {:rpc_validation_after_request_hook, nil, "hookF", 5},
    {:rpc_validation_before_channel_push_hook, nil, "hookG", 5},
    {:rpc_validation_before_request_hook, nil, "hookH", 5},
    {:rpc_validation_channel_hook_context_type, @ctx, "Ctx", ""},
    {:rpc_validation_hook_context_type, @ctx, "Ctx", ""},
    {:run_endpoint, "/rpc/run", "/api/run", "run"},
    {:source_path_prefix, "", "lib/", 5},
    {:type_mapping_overrides, [], [{Ash.Type.UUID, "z.string()"}], "bad"},
    {:typed_channels, [], [__MODULE__], :bad},
    {:typed_channels_output_file, nil, "ch.mjs", 5},
    {:typed_controller_after_request_hook, nil, "hookI", 5},
    {:typed_controller_base_path, "", "/api", 5},
    {:typed_controller_before_request_hook, nil, "hookJ", 5},
    {:typed_controller_error_handler, nil, {__MODULE__, :handle, []}, "bad"},
    {:typed_controller_hook_context_type, @ctx, "Ctx", ""},
    {:typed_controller_import_into_generated, [], [%{import_name: "T", file: "./t"}], :bad},
    {:typed_controller_mode, :full, :paths_only, :nope},
    {:typed_controller_path_params_style, :object, :args, :nope},
    {:typed_controller_show_raised_errors, false, true, "yes"},
    {:typed_controllers, [], [__MODULE__], :bad},
    {:untyped_map_type, "Record<string, any>", "unknown", ""},
    {:valibot_import_into_generated, [], [%{import_name: "V", file: "./v"}], :bad},
    {:valibot_import_path, "valibot", "valibot/x", ""},
    {:valibot_mapping_overrides, [], [{Ash.Type.UUID, "v.string()"}], "bad"},
    {:valibot_schema_suffix, "ValibotSchema", "Vs", "1 bad"},
    {:validate_endpoint, "/rpc/validate", "/api/validate", "validate"},
    {:warn_on_missing_channel_returns, true, false, "no"},
    {:warn_on_missing_rpc_config, true, false, "no"},
    {:warn_on_non_public_publications, true, false, "no"},
    {:warn_on_non_rpc_references, true, false, "no"}
  ]

  setup do
    keys = Enum.map(Config.parity_keys(), &elem(&1, 0))
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

  test "the case table covers exactly the parity key table" do
    assert Enum.sort(Enum.map(@cases, &elem(&1, 0))) ==
             Enum.sort(Enum.map(Config.parity_keys(), &elem(&1, 0)))

    assert length(@cases) == 59
  end

  test "defaults verify clean" do
    assert Verifier.verify() == :ok
  end

  for {key, default, valid, invalid} <- @cases do
    @key key
    @default default
    @valid valid
    @invalid invalid

    test "config key #{key}: default, override, validation" do
      assert Config.parity_value(@key) == @default
      assert apply_accessor(@key) == @default

      Application.put_env(:ash_surface, @key, @valid)
      assert apply_accessor(@key) == @valid
      assert Verifier.verify() == :ok

      Application.put_env(:ash_surface, @key, @invalid)
      assert {:error, errs} = Verifier.verify()
      assert Enum.any?(errs, &String.starts_with?(&1, Atom.to_string(@key) <> " "))
      assert_raise ArgumentError, fn -> Verifier.verify!() end
    end
  end

  # Accessors are named after the key; resolved by function export, not Kernel.apply.
  defp apply_accessor(key) do
    fun = Function.capture(Config, key, 0)
    fun.()
  end
end
