defmodule AshSurface.Config.Verifier do
  @moduledoc """
  Validates `:ash_surface` application-env values. `verify/0` returns `:ok` or
  `{:error, [message]}`; `verify!/0` raises.
  """

  alias AshSurface.Config

  @modes [:strict, :passthrough, :strip]
  @identifier ~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/

  @spec verify() :: :ok | {:error, [String.t()]}
  def verify do
    case errors() do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  def verify! do
    case verify() do
      :ok ->
        :ok

      {:error, errs} ->
        raise ArgumentError, "invalid :ash_surface config: " <> Enum.join(errs, "; ")
    end
  end

  defp errors do
    mode_errors() ++
      identifier_errors() ++
      path_errors() ++
      boolean_errors() ++ override_errors() ++ handler_errors() ++ parity_errors()
  end

  defp mode_errors do
    m = Config.zod_object_mode()

    if m in @modes,
      do: [],
      else: ["zod_object_mode must be one of #{inspect(@modes)}, got #{inspect(m)}"]
  end

  defp identifier_errors do
    suffix = Config.zod_schema_suffix()

    suffix_errs =
      if is_binary(suffix) and (suffix == "" or Regex.match?(@identifier, "x" <> suffix)),
        do: [],
        else: ["zod_schema_suffix is not a valid identifier fragment: #{inspect(suffix)}"]

    overrides = Config.zod_mapping_overrides()

    names =
      if is_map(overrides) or (is_list(overrides) and Enum.all?(overrides, &match?({_, _}, &1))),
        do: for({_type, spec} <- overrides, name <- spec_names(spec), do: name),
        else: []

    name_errs =
      for n <- names,
          not (is_binary(n) and Regex.match?(@identifier, n)),
          do: "zod_mapping_overrides name is not a valid identifier: #{inspect(n)}"

    suffix_errs ++ name_errs
  end

  defp path_errors do
    for {key, v} <- [
          zod_import_path: Config.zod_import_path(),
          zod_output_file: Config.zod_output_file(),
          output_file: Config.output_file()
        ],
        not (is_binary(v) and v != ""),
        do: "#{key} must be a non-empty string, got #{inspect(v)}"
  end

  defp handler_errors do
    for {key, v} <- [
          error_handler: Config.error_handler(),
          error_output_formatter: Config.error_output_formatter()
        ],
        not valid_handler?(v),
        do: "#{key} must be nil, a module, or {module, function, args}, got #{inspect(v)}"
  end

  defp valid_handler?(nil), do: true
  defp valid_handler?(m) when is_atom(m), do: true
  defp valid_handler?({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a), do: true
  defp valid_handler?(_), do: false

  defp boolean_errors do
    for {key, v} <- [
          zod_infer_types: Config.zod_infer_types(),
          require_tenant_parameters: Config.require_tenant_parameters(),
          always_regenerate: Config.always_regenerate(),
          not_found_error?: Config.not_found_error?(),
          show_raised_errors: Config.show_raised_errors(),
          show_policy_breakdowns: Config.show_policy_breakdowns(),
          zod_import_into_generated: Config.zod_import_into_generated()
        ],
        not is_boolean(v),
        do: "#{key} must be a boolean, got #{inspect(v)}"
  end

  # Each override is {type, {import_module_or_path, name}} / {type, %{import:, name:}} /
  # {type, {name, import}}-free: must carry a non-empty import and a name.
  defp override_errors do
    overrides = Config.zod_mapping_overrides()

    if (is_list(overrides) and Enum.all?(overrides, &match?({_, _}, &1))) or is_map(overrides) do
      for {type, spec} <- overrides,
          not valid_spec?(spec),
          do:
            "zod_mapping_overrides #{inspect(type)} requires a z.expr string " <>
              "or a matching import and name"
    else
      ["zod_mapping_overrides must be a keyword list of pairs or a map"]
    end
  end

  defp valid_spec?(expr) when is_binary(expr), do: String.trim(expr) != ""
  defp valid_spec?(%{import: i, name: n}), do: nonempty?(i) and nonempty?(n)
  defp valid_spec?({i, n}), do: nonempty?(i) and nonempty?(n)
  defp valid_spec?(_), do: false

  defp nonempty?(v), do: is_binary(v) and v != ""

  defp spec_names(%{name: n}), do: [n]
  defp spec_names({_i, n}), do: [n]
  defp spec_names(_), do: []

  defp parity_errors do
    for {key, _default, kind} <- Config.parity_keys(),
        v <- [Config.parity_value(key)],
        not valid_kind?(kind, v),
        do: "#{key} #{describe(kind)}, got #{inspect(v)}"
  end

  defp describe(:boolean), do: "must be a boolean"
  defp describe(:string), do: "must be a string"
  defp describe(:nonempty_string), do: "must be a non-empty string"
  defp describe(:nilable_string), do: "must be nil or a string"
  defp describe(:endpoint), do: "must be a string starting with \"/\""
  defp describe(:nilable_module), do: "must be nil or a module"
  defp describe(:nilable_list), do: "must be nil or a list"
  defp describe(:nilable_keyword), do: "must be nil or a keyword list"
  defp describe(:list), do: "must be a list"
  defp describe(:handler), do: "must be nil, a module, or {module, function, args}"
  defp describe(:formatter), do: "must be an atom or {module, function[, args]}"
  defp describe(:overrides), do: "must be a keyword list of pairs or a map"
  defp describe(:identifier_fragment), do: "must be a valid identifier fragment"
  defp describe({:enum, vals}), do: "must be one of #{inspect(vals)}"

  defp valid_kind?(:boolean, v), do: is_boolean(v)
  defp valid_kind?(:string, v), do: is_binary(v)
  defp valid_kind?(:nonempty_string, v), do: nonempty?(v)
  defp valid_kind?(:nilable_string, v), do: is_nil(v) or is_binary(v)
  defp valid_kind?(:endpoint, v), do: is_binary(v) and String.starts_with?(v, "/")
  defp valid_kind?(:nilable_module, v), do: is_nil(v) or is_atom(v)
  defp valid_kind?(:nilable_list, v), do: is_nil(v) or is_list(v)
  defp valid_kind?(:nilable_keyword, v), do: is_nil(v) or Keyword.keyword?(v)
  defp valid_kind?(:list, v), do: is_list(v)
  defp valid_kind?(:handler, v), do: valid_handler?(v)
  defp valid_kind?(:formatter, v) when is_atom(v), do: true
  defp valid_kind?(:formatter, {m, f}), do: is_atom(m) and is_atom(f)
  defp valid_kind?(:formatter, {m, f, a}), do: is_atom(m) and is_atom(f) and is_list(a)
  defp valid_kind?(:formatter, _), do: false

  defp valid_kind?(:overrides, v),
    do: is_map(v) or (is_list(v) and Enum.all?(v, &match?({_, _}, &1)))

  defp valid_kind?(:identifier_fragment, v),
    do: is_binary(v) and (v == "" or Regex.match?(@identifier, "x" <> v))

  defp valid_kind?({:enum, vals}, v), do: v in vals
end
