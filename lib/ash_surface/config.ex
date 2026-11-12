defmodule AshSurface.Config do
  @moduledoc """
  Application-environment accessors for the `:ash_surface` app, each with a default.

  ## Paths

  The generated client artifact is an ES module, so every default path ends in
  `.mjs`:

    * `:output_file` (default `#{"assets/js/ash_surface/ash_surface_client.mjs"}`) - the
      client artifact.
    * `:zod_output_file` - the Zod schema module. When unset it is derived as a
      sibling of `:output_file` (`ash_surface_zod.mjs` in the same directory).
    * `:output_dir` - documented alias kept for older configs. When set and
      `:output_file` is not, the artifact is `<output_dir>/ash_surface_client.mjs`.
      `:output_file` wins when both are set; nothing is silently dropped.

  ## Error handling keys

    * `:show_raised_errors` (boolean, default `false`)
    * `:show_policy_breakdowns` (boolean, default `false`)
    * `:error_handler` - a module or `{module, function, extra_args}`
    * `:error_output_formatter` - a module or `{module, function, extra_args}`

  ## Zod keys

  `:zod_mapping_overrides` accepts the same shapes as
  `AshSurface.Compiler.ZodType`: a map `%{kind => "z.expr"}` or a keyword/list of
  `{kind_or_module, "z.expr"}` pairs. The legacy `{type, {import, name}}` and
  `{type, %{import:, name:}}` shapes remain valid. `:zod_import_into_generated`
  (boolean, default `false`) asks the generator to import the Zod module into the
  generated artifact instead of emitting a sibling file.
  """

  @app :ash_surface

  @default_output_file "assets/js/ash_surface/ash_surface_client.mjs"
  @zod_basename "ash_surface_zod.mjs"

  defp get(key, default), do: Application.get_env(@app, key, default)

  @doc "Client artifact path: `:output_file`, else `:output_dir`-derived, else the default."
  def output_file do
    case Application.get_env(@app, :output_file) do
      nil ->
        case output_dir() do
          nil -> @default_output_file
          dir -> Path.join(dir, Path.basename(@default_output_file))
        end

      path ->
        path
    end
  end

  @doc "Legacy alias `:output_dir`; `nil` when unset."
  def output_dir, do: Application.get_env(@app, :output_dir)

  @doc "Zod module path: `:zod_output_file`, else a sibling of `output_file/0`."
  def zod_output_file, do: config_or_derive(:zod_output_file, @zod_basename)

  defp config_or_derive(key, derived_name) do
    case Application.get_env(@app, key) do
      nil -> Path.join(Path.dirname(output_file()), derived_name)
      path -> path
    end
  end

  def ash_domains, do: get(:ash_domains, [])
  def input_field_formatter, do: get(:input_field_formatter, :camel_case)
  def output_field_formatter, do: get(:output_field_formatter, :camel_case)
  def require_tenant_parameters, do: get(:require_tenant_parameters, false)
  def always_regenerate, do: get(:always_regenerate, false)
  def source_path_prefix, do: get(:source_path_prefix, "")
  def not_found_error?, do: get(:not_found_error?, true)
  def type_mapping_overrides, do: get(:type_mapping_overrides, [])

  def show_raised_errors, do: get(:show_raised_errors, false)
  def show_policy_breakdowns, do: get(:show_policy_breakdowns, false)
  def error_handler, do: get(:error_handler, nil)
  def error_output_formatter, do: get(:error_output_formatter, nil)

  def zod_import_path, do: get(:zod_import_path, "zod")
  def zod_schema_suffix, do: get(:zod_schema_suffix, "ZodSchema")
  def zod_mapping_overrides, do: get(:zod_mapping_overrides, [])
  def zod_object_mode, do: get(:zod_object_mode, :strip)
  def zod_infer_types, do: get(:zod_infer_types, true)
  def zod_import_into_generated, do: get(:zod_import_into_generated, false)

  # ---------------------------------------------------------------------------
  # ash_typescript parity keys (lane G1). Same name, type and default as the
  # reference's `Application.get_env(:ash_typescript, key, default)`; validated
  # by `AshSurface.Config.Verifier` by `kind`.
  # ---------------------------------------------------------------------------

  @ctx "Record<string, any>"

  @parity_keys [
    {:add_ash_internals_to_jsdoc, false, :boolean},
    {:add_ash_internals_to_manifest, false, :boolean},
    {:controller_namespace_output_dir, nil, :nilable_string},
    {:enable_controller_namespace_files, false, :boolean},
    {:enable_namespace_files, false, :boolean},
    {:generate_phx_channel_rpc_actions, false, :boolean},
    {:generate_valibot_schemas, false, :boolean},
    {:generate_validation_functions, false, :boolean},
    {:generate_zod_schemas, false, :boolean},
    {:import_into_generated, nil, :nilable_list},
    {:input_field_formatter, :camel_case, :formatter},
    {:output_field_formatter, :camel_case, :formatter},
    {:json_manifest_file, nil, :nilable_string},
    {:json_manifest_filename_format, :relative, {:enum, [:relative, :absolute, :basename]}},
    {:manifest, nil, :nilable_module},
    {:manifest_file, nil, :nilable_string},
    {:namespace_output_dir, nil, :nilable_string},
    {:not_found_error?, true, :boolean},
    {:phoenix_import_path, "phoenix", :nonempty_string},
    {:policies, nil, :nilable_keyword},
    {:require_tenant_parameters, false, :boolean},
    {:router, nil, :nilable_module},
    {:rpc_action_after_channel_response_hook, nil, :nilable_string},
    {:rpc_action_after_request_hook, nil, :nilable_string},
    {:rpc_action_before_channel_push_hook, nil, :nilable_string},
    {:rpc_action_before_request_hook, nil, :nilable_string},
    {:rpc_action_channel_hook_context_type, @ctx, :nonempty_string},
    {:rpc_action_hook_context_type, @ctx, :nonempty_string},
    {:rpc_validation_after_channel_response_hook, nil, :nilable_string},
    {:rpc_validation_after_request_hook, nil, :nilable_string},
    {:rpc_validation_before_channel_push_hook, nil, :nilable_string},
    {:rpc_validation_before_request_hook, nil, :nilable_string},
    {:rpc_validation_channel_hook_context_type, @ctx, :nonempty_string},
    {:rpc_validation_hook_context_type, @ctx, :nonempty_string},
    {:run_endpoint, "/rpc/run", :endpoint},
    {:validate_endpoint, "/rpc/validate", :endpoint},
    {:source_path_prefix, "", :nilable_string},
    {:type_mapping_overrides, [], :overrides},
    {:typed_channels, [], :list},
    {:typed_channels_output_file, nil, :nilable_string},
    {:typed_controller_after_request_hook, nil, :nilable_string},
    {:typed_controller_base_path, "", :string},
    {:typed_controller_before_request_hook, nil, :nilable_string},
    {:typed_controller_error_handler, nil, :handler},
    {:typed_controller_hook_context_type, @ctx, :nonempty_string},
    {:typed_controller_import_into_generated, [], :list},
    {:typed_controller_mode, :full, {:enum, [:full, :paths_only]}},
    {:typed_controller_path_params_style, :object, {:enum, [:object, :args]}},
    {:typed_controller_show_raised_errors, false, :boolean},
    {:typed_controllers, [], :list},
    {:untyped_map_type, "Record<string, any>", :nonempty_string},
    {:valibot_import_into_generated, [], :list},
    {:valibot_import_path, "valibot", :nonempty_string},
    {:valibot_mapping_overrides, [], :overrides},
    {:valibot_schema_suffix, "ValibotSchema", :identifier_fragment},
    {:warn_on_missing_channel_returns, true, :boolean},
    {:warn_on_missing_rpc_config, true, :boolean},
    {:warn_on_non_public_publications, true, :boolean},
    {:warn_on_non_rpc_references, true, :boolean}
  ]

  @already_defined [
    :input_field_formatter,
    :output_field_formatter,
    :not_found_error?,
    :require_tenant_parameters,
    :source_path_prefix,
    :type_mapping_overrides
  ]

  @doc "Parity key table: `[{key, default, kind}]` (reference name, type and default)."
  def parity_keys, do: @parity_keys

  @doc "Current value of a parity key (env value, else the reference default)."
  def parity_value(key) do
    {^key, default, _kind} = List.keyfind(@parity_keys, key, 0)
    get(key, default)
  end

  for {key, default, _kind} <- @parity_keys, key not in @already_defined do
    @doc "`:#{key}` (default `#{inspect(default)}`)."
    def unquote(key)(), do: get(unquote(key), unquote(Macro.escape(default)))
  end

  @doc "True when an RPC action before/after request hook is configured."
  def rpc_action_hooks_enabled?,
    do: rpc_action_before_request_hook() != nil or rpc_action_after_request_hook() != nil

  @doc "True when an RPC validation before/after request hook is configured."
  def rpc_validation_hooks_enabled?,
    do: rpc_validation_before_request_hook() != nil or rpc_validation_after_request_hook() != nil

  @doc "True when an RPC action before-channel-push / after-channel-response hook is configured."
  def rpc_action_channel_hooks_enabled?,
    do:
      rpc_action_before_channel_push_hook() != nil or
        rpc_action_after_channel_response_hook() != nil

  @doc "True when an RPC validation before-channel-push / after-channel-response hook is configured."
  def rpc_validation_channel_hooks_enabled?,
    do:
      rpc_validation_before_channel_push_hook() != nil or
        rpc_validation_after_channel_response_hook() != nil
end
