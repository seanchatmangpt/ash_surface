defmodule AshSurface.RuntimeParity.Rpc.Support do
  @moduledoc """
  Lookups and helpers shared by the ported non-actuating RPC pipeline core.

  Counterpart of `AshTypescript.Helpers`, `AshTypescript.Manifest.Custom`,
  `ActionIntrospection` and the global `AshTypescript.*_lookup()` accessors.

  `install/2` stores a prepared manifest handle (`RequestedFields.Compat.prepare/1`) and the
  RPC action table (a list of entry maps, see `AshSurface.RuntimeParity.Rpc.Pipeline`) in
  `:persistent_term`, mirroring the reference's compile-time-persisted manifest.
  """

  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.RequestedFields.Introspection

  @key {__MODULE__, :installed}
  @field_constrained_types [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple]

  @doc "Install the manifest handle and RPC entry table used by the pipeline."
  def install(handle, entries) when is_map(handle) and is_list(entries) do
    table = Map.new(entries, fn e -> {to_string(e.name), e} end)
    :persistent_term.put(@key, %{handle: handle, table: table})
    :ok
  end

  defp installed do
    case :persistent_term.get(@key, nil) do
      nil -> raise "AshSurface.RuntimeParity.Rpc.Support.install/2 has not been called"
      state -> state
    end
  end

  def handle, do: installed().handle
  def entry_table, do: installed().table
  def resource_lookup, do: Compat.resource_lookup(handle())
  def type_lookup, do: Compat.type_lookup(handle())
  def action_lookup, do: Compat.action_lookup(handle())

  # The configured formatters (`AshSurface.Config`, default :camel_case); read per call so a
  # request honors the application env in force.
  # A `AshSurface.FieldName.with_formatter/2` scope (also the compile option
  # `:output_field_formatter`) applies in-process to RPC parse and format, input and output, so a
  # snake_case compile scope parses and emits snake spellings; outside any scope Config rules.
  def output_field_formatter, do: AshSurface.FieldName.output_formatter()

  def input_field_formatter, do: AshSurface.FieldName.input_formatter()

  # -- Helpers.* -------------------------------------------------------------

  defdelegate ash_resource?(module), to: Compat
  defdelegate has_typescript_field_names?(module), to: Compat
  defdelegate typescript_field_names(module), to: Compat
  defdelegate typescript_field_names_reverse(module), to: Compat

  # -- Custom.* --------------------------------------------------------------

  def resolve_resource(module), do: Compat.resolve_resource(module, handle())
  def original_field_name(resource, name), do: Compat.original_field_name(resource, name)
  def type_field_name_mappings_pair(_type), do: nil
  def action_input_expected_keys(_action, _formatter), do: nil

  # -- ActionIntrospection.* -------------------------------------------------

  def get_action!(resource, action_name) do
    case Map.get(action_lookup(), {resource, action_name}) do
      %Ash.Info.Manifest.Action{} = action ->
        action

      nil ->
        raise "action #{inspect(action_name)} not found on #{inspect(resource)} in manifest"
    end
  end

  def accepted_attribute?(resource, input_name, resource_lookup) do
    case Map.get(resource_lookup || %{}, resource) do
      %Ash.Info.Manifest.Resource{fields: fields} when is_map(fields) ->
        Map.has_key?(fields, input_name)

      _ ->
        false
    end
  end

  alias AshSurface.RuntimeParity.Rpc.FieldFormatter

  def format_input_name(resource, action_name, input_name, resource_lookup, formatter \\ nil) do
    formatter = formatter || output_field_formatter()

    if accepted_attribute?(resource, input_name, resource_lookup) do
      FieldFormatter.format_field_for_client(input_name, resource, formatter)
    else
      mapped = mapped_argument_name(resource, action_name, input_name)

      # mapped_argument_name/3 returns a binary or input_name itself.
      if is_binary(mapped),
        do: mapped,
        else: FieldFormatter.format_field_name(input_name, formatter)
    end
  end

  @doc "Client name for an action argument per the resource `argument_names` option, else the atom."
  def mapped_argument_name(resource, action_name, input_name) do
    with true <- Compat.ash_resource?(resource),
         true <- AshSurface.Resource in Spark.extensions(resource),
         names when is_list(names) <- AshSurface.Resource.Info.argument_names(resource),
         per_action when is_list(per_action) <- Keyword.get(names, action_name),
         name when is_binary(name) <- Keyword.get(per_action, input_name) do
      name
    else
      _ -> input_name
    end
  end

  def action_supports_pagination?(action),
    do: action.type == :read and not Map.get(action, :get?, false) and is_map(pagination(action))

  def action_requires_pagination?(action),
    do: Map.get(pagination(action) || %{}, :required?, false)

  defp pagination(action), do: Map.get(action, :pagination)

  def action_returns_field_selectable_type?(action),
    do: compute_action_returns_field_selectable_type?(action, type_lookup())

  @doc """
  Pure computation of `action_returns_field_selectable_type?/1`, taking an
  explicit `type_lookup` so it can run during manifest decoration (before the
  `:type_lookup` is persisted). The decorator stores the result on the action's
  `custom.ash_typescript` so the runtime path is a plain map read.
  """
  def compute_action_returns_field_selectable_type?(action, type_lookup) do
    if action.type != :action do
      {:error, :not_generic_action}
    else
      check_action_returns(action, type_lookup)
    end
  end

  defp check_action_returns(action, type_lookup) do
    {base_type, constraints, is_array} = unwrap_return_type(action, type_lookup)

    {unwrapped_type, unwrapped_constraints} =
      Introspection.unwrap_new_type(base_type, constraints)

    case classify_return_type(unwrapped_type, unwrapped_constraints, type_lookup) do
      {:resource, module} ->
        if is_array do
          {:ok, :array_of_resource, module}
        else
          {:ok, :resource, module}
        end

      {:typed_map, fields} ->
        if is_array do
          {:ok, :array_of_typed_map, fields}
        else
          {:ok, :typed_map, fields}
        end

      {:typed_struct, {module, fields}} ->
        if is_array do
          {:ok, :array_of_typed_struct, {module, fields}}
        else
          {:ok, :typed_struct, {module, fields}}
        end

      :unconstrained_map ->
        if is_array do
          {:ok, :array_of_unconstrained_map, nil}
        else
          {:ok, :unconstrained_map, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp unwrap_return_type(action, type_lookup) do
    case action.returns do
      # Ash.Info.Manifest.Type with array kind
      %Ash.Info.Manifest.Type{kind: :array, item_type: item_type} ->
        {item_type, [], true}

      # Ash.Info.Manifest.Type ref — resolve before continuing
      %Ash.Info.Manifest.Type{kind: :type_ref, module: module} ->
        full_type = Ash.Info.Manifest.get_type!(type_lookup, module)
        {full_type, [], false}

      # Ash.Info.Manifest.Type (non-array)
      %Ash.Info.Manifest.Type{} = type ->
        {type, [], false}

      # Legacy: raw Ash type tuple
      {:array, inner_type} ->
        inner_constraints = Keyword.get(Map.get(action, :constraints) || [], :items, [])
        {inner_type, inner_constraints, true}

      type ->
        {type, Map.get(action, :constraints) || [], false}
    end
  end

  # Classifies a return type into a category for field selectability
  @spec classify_return_type(
          atom() | tuple() | Ash.Info.Manifest.Type.t(),
          keyword(),
          map()
        ) ::
          {:resource, module()}
          | {:typed_map, keyword()}
          | {:typed_struct, {module(), keyword()}}
          | :unconstrained_map
          | {:error, atom()}
  # Ash.Info.Manifest.Type classification
  defp classify_return_type(
         %Ash.Info.Manifest.Type{kind: :type_ref, module: module},
         _constraints,
         type_lookup
       ) do
    full_type = Ash.Info.Manifest.get_type!(type_lookup, module)
    classify_return_type(full_type, [], type_lookup)
  end

  defp classify_return_type(
         %Ash.Info.Manifest.Type{kind: kind, resource_module: mod},
         _constraints,
         _type_lookup
       )
       when kind in [:resource, :embedded_resource] and not is_nil(mod) do
    {:resource, mod}
  end

  defp classify_return_type(
         %Ash.Info.Manifest.Type{kind: :struct, fields: fields, instance_of: inst},
         _constraints,
         _type_lookup
       )
       when is_list(fields) and fields != [] and not is_nil(inst) do
    {:typed_struct, {inst, fields}}
  end

  defp classify_return_type(
         %Ash.Info.Manifest.Type{kind: kind} = type_info,
         _constraints,
         _type_lookup
       )
       when kind in [:map, :keyword, :tuple] do
    fields = Ash.Info.Manifest.Type.get_fields(type_info)

    if fields != [] do
      {:typed_map, fields}
    else
      :unconstrained_map
    end
  end

  defp classify_return_type(%Ash.Info.Manifest.Type{}, _constraints, _type_lookup) do
    {:error, :not_field_selectable_type}
  end

  # Legacy raw Ash type classification
  defp classify_return_type(type, constraints, _type_lookup) do
    cond do
      type == Ash.Type.Struct and Keyword.has_key?(constraints, :instance_of) ->
        instance_of = Keyword.get(constraints, :instance_of)

        cond do
          Ash.Resource.Info.resource?(instance_of) ->
            {:resource, instance_of}

          Keyword.has_key?(constraints, :fields) ->
            {:typed_struct, {instance_of, Keyword.get(constraints, :fields, [])}}

          true ->
            {:error, :not_field_selectable_type}
        end

      type == Ash.Type.Struct ->
        {:error, :no_instance_of_defined}

      type in @field_constrained_types and Keyword.has_key?(constraints, :fields) ->
        {:typed_map, Keyword.get(constraints, :fields)}

      type in @field_constrained_types ->
        :unconstrained_map

      is_atom(type) and has_field_constraints?(constraints) ->
        fields = Keyword.get(constraints, :fields, [])
        {:typed_struct, {type, fields}}

      true ->
        {:error, :not_field_selectable_type}
    end
  end

  defp has_field_constraints?(constraints) do
    Keyword.has_key?(constraints, :fields) and Keyword.has_key?(constraints, :instance_of)
  end
end
