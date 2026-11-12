defmodule AshSurface.Manifest.Dsl do
  @moduledoc """
  Serialization of the surface DSL declarations into the `Ash.Info.Manifest`
  custom entry (counterpart of `AshTypescript.Manifest.Dsl`).

  The reference extension builds and decorates a manifest from its DSL. ash_surface
  ingests the manifest Ash produces and decorates it: resource-level DSL declarations
  (`type_name`, `namespace`, `field_names`, `argument_names`, `show_raised_errors?`,
  `typed_query` entities) are written under `manifest.custom[:ash_surface]["dsl"]`,
  keyed by resource module name, as JSON-shaped data. Per-action projection options
  (`show_metadata`, `metadata_field_names`) live in the action custom entry.

  `serialize/1` is DSL -> JSON data; `read/2` is manifest (struct or serialized map)
  -> the same data. Resources without declarations contribute nothing.
  """

  alias AshSurface.Resource.{Info, Projections}

  @doc "JSON-shaped DSL declarations of `resource` (empty map when none are declared)."
  @spec serialize(module()) :: map()
  def serialize(resource) do
    if Spark.Dsl.is?(resource, Ash.Resource) and
         AshSurface.Resource in Spark.extensions(resource) do
      %{}
      |> put("type_name", Info.type_name(resource))
      |> put("namespace", Info.namespace(resource))
      |> put("field_names", Info.field_names(resource) |> names())
      |> put("argument_names", Info.argument_names(resource) |> nested_names())
      |> put("show_raised_errors?", opt(resource, :show_raised_errors?))
      |> put("typed_queries", resource |> Projections.typed_queries() |> Enum.map(&typed_query/1))
    else
      %{}
    end
  end

  @doc "DSL declarations for every distinct resource of `entrypoints`, keyed by module name."
  @spec serialize_all([Ash.Info.Manifest.Entrypoint.t()]) :: map()
  def serialize_all(entrypoints) do
    entrypoints
    |> Enum.map(& &1.resource)
    |> Enum.uniq()
    |> Enum.reduce(%{}, fn resource, acc ->
      case serialize(resource) do
        dsl when map_size(dsl) == 0 -> acc
        dsl -> Map.put(acc, inspect(resource), dsl)
      end
    end)
  end

  @doc """
  Reads the DSL declarations back from a decorated manifest (struct) or a
  contract map (string keys, e.g. after JSON decode; the serializer omits `custom`, so
  the envelope under `"surface"` carries the same data and enters the digest).
  """
  @spec read(Ash.Info.Manifest.t() | AshSurface.Surface.t() | map()) :: map()
  def read(%Ash.Info.Manifest{custom: custom}) do
    custom |> Map.get(:ash_surface, %{}) |> Map.get("dsl", %{})
  end

  def read(%AshSurface.Surface{contract: contract}), do: read(contract)
  def read(%{"surface" => %{"dsl" => dsl}}), do: dsl
  def read(%{}), do: %{}

  defp typed_query(q) do
    %{"name" => to_string(q.name), "action" => to_string(q.action)}
    |> put("description", q.description)
    |> put("result_type_name", q.result_type_name)
    |> put("fields_const_name", q.fields_const_name)
    |> Map.put("fields", json(q.fields))
  end

  defp opt(resource, key), do: Spark.Dsl.Extension.get_opt(resource, [:surface], key, nil)

  defp put(acc, _key, nil), do: acc
  defp put(acc, _key, []), do: acc
  defp put(acc, _key, m) when m == %{}, do: acc
  defp put(acc, key, value), do: Map.put(acc, key, value)

  defp names(nil), do: nil
  defp names(kw), do: Map.new(kw, fn {k, v} -> {to_string(k), v} end)

  defp nested_names(nil), do: nil

  defp nested_names(kw),
    do: Map.new(kw, fn {action, inner} -> {to_string(action), names(inner)} end)

  # Field trees: atoms -> strings, {key, subtree} / keyword entries -> single-key maps,
  # {key, {args, subtree}} -> %{key => %{"args" => .., "fields" => ..}}.
  defp json(list) when is_list(list), do: Enum.map(list, &json_item/1)
  defp json(other), do: json_item(other)

  defp json_item(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom),
    do: Atom.to_string(atom)

  defp json_item({key, {args, fields}}) when is_list(fields) and (is_map(args) or is_list(args)),
    do: %{to_string(key) => %{"args" => json_data(args), "fields" => json(fields)}}

  defp json_item({key, value}), do: %{to_string(key) => json(value)}
  defp json_item(map) when is_map(map), do: Map.new(map, fn {k, v} -> {to_string(k), json(v)} end)
  defp json_item(other), do: json_data(other)

  defp json_data(m) when is_map(m), do: Map.new(m, fn {k, v} -> {to_string(k), json_data(v)} end)

  defp json_data(l) when is_list(l) do
    if Keyword.keyword?(l) and l != [],
      do: Map.new(l, fn {k, v} -> {to_string(k), json_data(v)} end),
      else: Enum.map(l, &json_data/1)
  end

  defp json_data(a) when is_atom(a) and not is_nil(a) and not is_boolean(a), do: Atom.to_string(a)
  defp json_data(other), do: other
end
