defmodule AshSurface.RuntimeParity.RequestedFields.Compat do
  @moduledoc """
  Adapter between the ported requested-fields processor and ash_surface.

  Counterpart of `AshTypescript.Manifest.Custom`, `AshTypescript.Helpers`,
  `AshTypescript.FieldFormatter` and the manifest lookups of `AshTypescript`.
  ash_surface ingests a plain `%Ash.Info.Manifest{}`; `prepare/1` decorates it once
  (resource field-name mappings, relationship read action / pagination) under
  `custom[:ash_surface]` and returns a handle carrying the lookups, so the selector never
  touches `Ash.Resource.Info` for those facts at selection time.
  """

  alias Ash.Info.Manifest
  alias AshSurface.FieldName

  @doc "Decorate `manifest` and build the lookup handle the processor threads as `manifest`."
  @spec prepare(Manifest.t() | map()) :: map()
  def prepare(%{resource_lookup: _} = handle), do: handle

  def prepare(%Manifest{} = manifest) do
    resources = Enum.map(manifest.resources, &decorate_resource/1)
    types = Enum.map(manifest.types, &decorate_type/1)
    decorated = %Manifest{manifest | resources: resources, types: types}

    %{
      manifest: decorated,
      resource_lookup: build_resource_lookup(decorated),
      action_lookup: Manifest.action_lookup(decorated),
      type_lookup: Manifest.type_lookup(decorated)
    }
  end

  # Ash 3.25+ keeps embedded resources in `manifest.types`; merge them back (as the reference does).
  defp build_resource_lookup(manifest) do
    embedded =
      manifest.types
      |> Enum.filter(&match?(%Manifest.Type{kind: :embedded_resource, resource: %_{}}, &1))
      |> Map.new(fn %{module: mod, resource: resource} -> {mod, resource} end)

    Map.merge(embedded, Manifest.resource_lookup(manifest))
  end

  defp decorate_resource(%Manifest.Resource{module: module} = res) do
    res = %Manifest.Resource{
      res
      | relationships:
          Map.new(res.relationships, fn {k, rel} -> {k, decorate_rel(module, rel)} end)
    }

    if surface_resource?(module) do
      fwd = module |> AshSurface.Resource.Info.field_names() |> Kernel.||([]) |> Map.new()
      rev = Map.new(fwd, fn {k, v} -> {to_string(v), k} end)

      %Manifest.Resource{
        res
        | custom:
            Map.put(res.custom || %{}, :ash_surface, %{
              field_name_mappings: fwd,
              reverse_field_name_mappings: rev
            })
      }
    else
      res
    end
  end

  defp decorate_type(%Manifest.Type{resource: %Manifest.Resource{} = res} = type),
    do: %Manifest.Type{type | resource: decorate_resource(res)}

  defp decorate_type(type), do: type

  defp decorate_rel(source, %Manifest.Relationship{name: name, destination: dest} = rel) do
    ash_rel = Ash.Resource.Info.relationship(source, name)

    read_action =
      (ash_rel && Map.get(ash_rel, :read_action)) ||
        case Ash.Resource.Info.primary_action(dest, :read) do
          nil -> nil
          action -> action.name
        end

    pagination =
      case read_action && Ash.Resource.Info.action(dest, read_action) do
        %{pagination: %{offset?: true, keyset?: true}} -> :mixed
        %{pagination: %{offset?: true}} -> :offset
        %{pagination: %{keyset?: true}} -> :keyset
        _ -> :none
      end

    %Manifest.Relationship{
      rel
      | custom:
          Map.put(rel.custom || %{}, :ash_surface, %{
            pagination: pagination,
            read_action: read_action
          })
    }
  end

  defp surface_resource?(module) do
    Spark.Dsl.is?(module, Ash.Resource) and AshSurface.Resource in Spark.extensions(module)
  end

  # -- lookups ---------------------------------------------------------------

  def resource_lookup(%{resource_lookup: l}), do: l
  def resource_lookup(%Manifest{} = m), do: m |> prepare() |> resource_lookup()
  def action_lookup(%{action_lookup: l}), do: l
  def action_lookup(%Manifest{} = m), do: m |> prepare() |> action_lookup()
  def type_lookup(%{type_lookup: l}), do: l
  def type_lookup(%Manifest{} = m), do: m |> prepare() |> type_lookup()

  @doc "Resolve a resource (or embedded-resource type module) to its manifest resource."
  def resolve_resource(module, manifest) when is_atom(module) and not is_nil(module) do
    case Manifest.get_resource(resource_lookup(manifest), module) do
      %Manifest.Resource{} = resource ->
        resource

      _ ->
        case Manifest.get_type(type_lookup(manifest), module) do
          %Manifest.Type{resource: %Manifest.Resource{} = resource} -> resource
          _ -> nil
        end
    end
  end

  def resolve_resource(_, _), do: nil

  def typescript_resource?(%Manifest.Resource{custom: %{ash_surface: _}}), do: true
  def typescript_resource?(_), do: false

  def original_field_name(
        %Manifest.Resource{custom: %{ash_surface: %{reverse_field_name_mappings: m}}},
        name
      )
      when is_binary(name),
      do: Map.get(m, name)

  def original_field_name(resource, name) when is_atom(name) and not is_nil(name),
    do: original_field_name(resource, Atom.to_string(name))

  def original_field_name(_, _), do: nil

  def relationship_pagination(%Manifest.Relationship{custom: %{ash_surface: %{pagination: p}}}),
    do: p

  def relationship_pagination(_), do: :none

  def relationship_read_action(%Manifest.Relationship{custom: %{ash_surface: %{read_action: a}}}),
    do: a

  def relationship_read_action(_), do: nil

  @doc "ash_surface carries no per-type decoration; callers fall back to module reflection."
  def type_field_name_mappings_pair(_), do: nil

  # -- helpers ---------------------------------------------------------------

  def ash_resource?(module) when is_atom(module) and not is_nil(module),
    do: Code.ensure_loaded?(module) == true and Ash.Resource.Info.resource?(module)

  def ash_resource?(_), do: false

  def has_typescript_field_names?(nil), do: false

  def has_typescript_field_names?(module) when is_atom(module),
    do:
      Code.ensure_loaded?(module) == true and
        function_exported?(module, :typescript_field_names, 0)

  def has_typescript_field_names?(_), do: false

  def typescript_field_names(module) do
    if has_typescript_field_names?(module),
      do: module.typescript_field_names() |> Map.new(),
      else: %{}
  end

  def typescript_field_names_reverse(module),
    do: module |> typescript_field_names() |> Map.new(fn {k, v} -> {v, k} end)

  # -- field formatter -------------------------------------------------------

  def parse_input_field(name, formatter) when is_binary(name) or is_atom(name) do
    case FieldName.parse_input(name, formatter) do
      {:ok, atom} -> atom
      :error -> name
    end
  end

  def resolve_field_name(name, _formatter) when is_atom(name), do: name

  def resolve_field_name(name, formatter) when is_binary(name),
    do: parse_input_field(name, formatter)

  def parse_input_fields(fields, formatter) when is_map(fields) do
    Map.new(fields, fn {k, v} ->
      {parse_input_field(k, formatter), parse_input_value(v, formatter)}
    end)
  end

  defp parse_input_value(%{} = map, formatter), do: parse_input_fields(map, formatter)

  defp parse_input_value(list, formatter) when is_list(list),
    do: Enum.map(list, &parse_input_value(&1, formatter))

  defp parse_input_value(other, _formatter), do: other

  def format_sort_string(nil, _formatter), do: nil

  def format_sort_string(sort, formatter) when is_list(sort),
    do: Enum.map_join(sort, ",", &sort_field(&1, formatter))

  def format_sort_string(sort, formatter) when is_binary(sort),
    do: sort |> String.split(",") |> Enum.map_join(",", &sort_field(&1, formatter))

  defp sort_field(field, formatter) do
    {prefix, name} =
      case field do
        "++" <> n -> {"++", n}
        "--" <> n -> {"--", n}
        "+" <> n -> {"+", n}
        "-" <> n -> {"-", n}
        n -> {"", n}
      end

    prefix <> to_string(parse_input_field(name, formatter))
  end
end
