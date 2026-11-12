defmodule AshSurface.RuntimeParity.Rpc.FieldFormatter do
  @moduledoc """
  Field-name formatting for the ported RPC pipeline (counterpart of
  `AshTypescript.FieldFormatter`), delegating the name computation to
  `AshSurface.FieldName` and resource mappings to the decorated manifest
  (`RequestedFields.Compat`).
  """

  alias Ash.Info.Manifest
  alias AshSurface.FieldName
  alias AshSurface.RuntimeParity.RequestedFields.Compat

  def format_field_name(field_name, formatter), do: FieldName.compute(field_name, formatter)

  def format_field_for_client(field, resource_or_type \\ nil, formatter)

  def format_field_for_client(field, %Manifest.Resource{custom: custom}, formatter)
      when is_atom(field) do
    case custom do
      %{ash_surface: %{field_name_mappings: m}} ->
        case Map.get(m, field) do
          mapped when is_binary(mapped) -> mapped
          _ -> FieldName.compute(field, formatter)
        end

      _ ->
        FieldName.compute(field, formatter)
    end
  end

  def format_field_for_client(field, %Manifest.Type{}, formatter) when is_atom(field),
    do: FieldName.compute(field, formatter)

  def format_field_for_client(field, resource, formatter)
      when is_atom(field) and is_atom(resource) and not is_nil(resource) do
    if Compat.ash_resource?(resource) or Compat.has_typescript_field_names?(resource) do
      FieldName.format_field_for_client(field, resource, formatter)
    else
      FieldName.compute(field, formatter)
    end
  end

  def format_field_for_client(field, _resource, formatter) when is_atom(field),
    do: FieldName.compute(field, formatter)

  def format_field_for_client(field, _resource, formatter) when is_binary(field),
    do: format_field_name(field, formatter)

  def format_field_for_client(other, _resource, _formatter), do: other

  def parse_input_field(field_name, formatter),
    do: Compat.parse_input_field(field_name, formatter)

  def resolve_field_name(name, formatter), do: Compat.resolve_field_name(name, formatter)

  def parse_input_fields(fields, formatter) when is_map(fields),
    do: Compat.parse_input_fields(fields, formatter)

  def parse_input_value(%{} = map, formatter), do: parse_input_fields(map, formatter)

  def parse_input_value(list, formatter) when is_list(list),
    do: Enum.map(list, &parse_input_value(&1, formatter))

  def parse_input_value(other, _formatter), do: other

  def format_sort_string(sort, formatter), do: Compat.format_sort_string(sort, formatter)

  def format_output_field_names(data, formatter) do
    case data do
      map when is_map(map) and not is_struct(map) ->
        Map.new(map, fn {key, value} ->
          formatted_key =
            if is_atom(key) or is_binary(key), do: format_field_name(key, formatter), else: key

          {formatted_key, format_output_field_names(value, formatter)}
        end)

      list when is_list(list) ->
        Enum.map(list, &format_output_field_names(&1, formatter))

      other ->
        other
    end
  end
end
