defmodule AshSurface.RuntimeParity.Rpc.TypedQuery do
  @moduledoc """
  Non-actuating typed-query runner (counterpart of `AshTypescript.Rpc.run_typed_query/4`).

  A typed query is the `typed_query` surface entity of a resource: a named, pre-configured field
  selection over a read action. This module resolves it by name, finds the RPC entry of the same
  resource/action in the installed table, expands the declared `fields` into the client field
  request and runs the pipeline stages 1 + 3 + 4 over a caller-supplied, already materialized
  result. It never runs the action (README: it never actuates).
  """

  alias AshSurface.Resource.Projections
  alias AshSurface.RuntimeParity.Rpc.{FieldFormatter, Pipeline, Support}

  @doc """
  Resolve the typed query `name`. Searches `opts[:resources]` (default: the resources of the
  installed entry table). Returns `{:ok, {resource, typed_query}}` or
  `{:error, {:typed_query_not_found, name}}`.
  """
  def lookup(name, opts \\ []) do
    resources = Keyword.get_lazy(opts, :resources, &entry_resources/0)
    name = to_atom(name)

    resources
    |> Enum.find_value(fn resource ->
      case name && Projections.typed_query(resource, name) do
        nil -> nil
        false -> nil
        query -> {resource, query}
      end
    end)
    |> case do
      nil -> {:error, {:typed_query_not_found, name}}
      found -> {:ok, found}
    end
  end

  @doc "Client field request (camelCase, string keyed) for the declared fields of a typed query."
  def client_fields(fields, resource \\ nil),
    do: Enum.map(List.wrap(fields), &client_field(&1, resource))

  @doc """
  Run typed query `name` over `result`. `params` is the string-keyed client map (`"input"`,
  `"filter"`, `"sort"`, `"page"`, ...); the typed query's fields are set from its declaration.
  Returns the client envelope.
  """
  def run(name, params, result, opts \\ []) do
    with {:ok, request} <- parse(name, params, opts),
         {:ok, processed} <- Pipeline.process_result(result, request) do
      Pipeline.format_output(%{success: true, data: processed}, request)
    else
      {:error, reason} -> Pipeline.error_response(reason)
    end
  end

  @doc "Stage 1 only: the parsed `Request` of typed query `name` with the caller `params`."
  def parse(name, params, opts \\ []) do
    with {:ok, {resource, query}} <- lookup(name, opts),
         {:ok, entry} <- rpc_entry(resource, query) do
      params
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> Map.put("action", to_string(entry.name))
      |> Map.put("fields", client_fields(query.fields, resource))
      |> Pipeline.parse_request(Keyword.take(opts, [:actor, :tenant, :context]))
    end
  end

  defp rpc_entry(resource, query) do
    Support.entry_table()
    |> Map.values()
    |> Enum.filter(&(&1.resource == resource and &1.action == query.action))
    |> Enum.sort_by(&to_string(&1.name))
    |> case do
      [entry | _] -> {:ok, entry}
      [] -> {:error, {:action_not_found, query.action}}
    end
  end

  defp entry_resources do
    Support.entry_table() |> Map.values() |> Enum.map(& &1.resource) |> Enum.uniq()
  end

  # Every level resolves names through ITS OWN destination (`dest/2`): the root through the
  # entry resource, relationship / embedded / calculation levels through their destination
  # resource, union levels through the member's resource. A level with no resource is camelCase.
  # Each name is formatted exactly once (`format/2`), here; the pipeline then reads wire names.
  defp client_field(name, res) when is_atom(name), do: format(name, res)

  defp client_field({name, %{} = spec}, res) when is_atom(name),
    do: %{format(name, res) => client_spec(spec, dest(res, name))}

  defp client_field({name, nested}, res) when is_atom(name),
    do: %{format(name, res) => client_fields(nested, dest(res, name))}

  defp client_field(%{} = map, res) do
    Map.new(map, fn
      {name, %{} = spec} -> {format(name, res), client_spec(spec, dest(res, name))}
      {name, nested} -> {format(name, res), client_fields(nested, dest(res, name))}
    end)
  end

  defp client_spec(%{args: args, fields: fields}, res),
    do: %{"args" => client_args(args), "fields" => client_fields(fields, res)}

  defp client_spec(%{fields: fields}, res), do: %{"fields" => client_fields(fields, res)}
  defp client_spec(%{args: args}, _res), do: %{"args" => client_args(args)}

  defp client_args(args) when is_map(args),
    do: Map.new(args, fn {k, v} -> {format(k, nil), v} end)

  defp format(name, nil), do: FieldFormatter.format_field_name(name, :camel_case)

  # Union level: members are plain tag names, not resource fields.
  defp format(name, {:union, _members}), do: FieldFormatter.format_field_name(name, :camel_case)

  defp format(name, resource),
    do: AshSurface.FieldName.wire(resource, name, formatter: :camel_case)

  # Destination of `name` on `res`: a resource module, `{:union, %{member => resource | nil}}`,
  # or nil.
  defp dest({:union, members}, name), do: Map.get(members, name)
  defp dest(nil, _name), do: nil

  defp dest(res, name) do
    case Ash.Resource.Info.relationship(res, name) do
      %{destination: d} -> d
      nil -> type_dest(field_type(res, name))
    end
  end

  defp field_type(res, name) do
    case Ash.Resource.Info.field(res, name) do
      %{type: type} = f -> {type, Map.get(f, :constraints, [])}
      _ -> nil
    end
  end

  defp type_dest(nil), do: nil
  defp type_dest({{:array, t}, c}), do: type_dest({t, Keyword.get(c, :items, [])})

  defp type_dest({type, c}) do
    type = if is_atom(type), do: Ash.Type.get_type(type), else: type

    cond do
      type == Ash.Type.Union ->
        {:union,
         c |> Keyword.get(:types, []) |> Map.new(fn {m, cfg} -> {m, member_dest(cfg)} end)}

      type == Ash.Type.Struct ->
        Keyword.get(c, :instance_of)

      is_atom(type) and Ash.Resource.Info.resource?(type) ->
        type

      is_atom(type) and Ash.Type.NewType.new_type?(type) ->
        type_dest({Ash.Type.NewType.subtype_of(type), Ash.Type.NewType.constraints(type, c)})

      true ->
        nil
    end
  end

  defp member_dest(cfg), do: type_dest({cfg[:type], cfg[:constraints] || []})

  defp to_atom(name) when is_atom(name), do: name

  defp to_atom(name) when is_binary(name) do
    String.to_existing_atom(name)
  rescue
    ArgumentError -> nil
  end
end
