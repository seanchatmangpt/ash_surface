defmodule AshShadcn.Introspect do
  @moduledoc """
  Turns configured Ash domains into JSON-able descriptors for the React admin:
  domains -> resources -> fields / relationships / actions / calculations / aggregates.
  Ash is the only source of truth; nothing here invents a second model.
  """
  alias Ash.Resource.Info

  def domains do
    for domain <- AshShadcn.domains() do
      %{
        name: short(domain),
        module: inspect(domain),
        resources: Enum.map(Ash.Domain.Info.resources(domain), &resource_summary/1)
      }
    end
  end

  def resource_summary(resource) do
    %{name: short(resource), module: inspect(resource), primary_key: Info.primary_key(resource)}
  end

  def resource(resource) do
    %{
      name: short(resource),
      module: inspect(resource),
      primary_key: Info.primary_key(resource),
      attributes: Enum.map(Info.public_attributes(resource), &attribute/1),
      relationships: Enum.map(Info.public_relationships(resource), &relationship/1),
      calculations: Enum.map(Info.public_calculations(resource), &field(&1, :calculation)),
      aggregates: Enum.map(Info.public_aggregates(resource), &aggregate(resource, &1)),
      actions: Enum.map(Info.actions(resource), &action(resource, &1))
    }
  end

  def attribute(a) do
    %{
      name: a.name,
      type: type_name(a.type),
      kind: kind(a.type),
      constraints: constraints(a.constraints),
      allow_nil: a.allow_nil?,
      primary_key: a.primary_key?,
      writable: a.writable?,
      has_default: not is_nil(a.default),
      sensitive: a.sensitive?
    }
    |> Map.merge(detail(a.type, a.constraints))
  end

  def relationship(r) do
    %{
      name: r.name,
      type: r.type,
      cardinality: r.cardinality,
      destination: short(r.destination),
      destination_module: inspect(r.destination),
      source_attribute: r.source_attribute,
      destination_attribute: r.destination_attribute
    }
  end

  defp aggregate(resource, agg) do
    type =
      case Info.aggregate_type(resource, agg) do
        {:ok, t} -> t
        _ -> agg.type || Ash.Type.String
      end

    field(%{agg | type: type}, :aggregate)
  end

  defp field(f, tag) do
    %{
      name: f.name,
      type: type_name(f.type),
      kind: kind(f.type),
      tag: tag,
      arguments: Enum.map(Map.get(f, :arguments, []), &argument/1)
    }
  end

  def action(a), do: action(nil, a)

  def action(resource, a) do
    %{
      name: a.name,
      type: a.type,
      primary: Map.get(a, :primary?, false),
      description: a.description,
      accept: Map.get(a, :accept) || [],
      arguments: a |> Map.get(:arguments, []) |> Enum.filter(& &1.public?) |> Enum.map(&argument/1),
      returns: if(a.type == :action, do: type_name(a.returns), else: nil),
      pagination: pagination(a),
      managed_relationships: managed_relationships(resource, a)
    }
  end

  # `manage_relationship` changes: argument -> relationship, rendered as nested forms.
  defp managed_relationships(nil, _), do: []

  defp managed_relationships(resource, a) do
    for %{change: {Ash.Resource.Change.ManageRelationship, opts}} <- Map.get(a, :changes, []),
        rel = Info.relationship(resource, opts[:relationship]),
        not is_nil(rel) do
      %{
        argument: opts[:argument],
        relationship: rel.name,
        cardinality: rel.cardinality,
        destination: short(rel.destination),
        destination_module: inspect(rel.destination),
        type: get_in(opts, [:opts, :type])
      }
    end
  end

  defp pagination(%{type: :read, pagination: %{} = p}),
    do: %{offset: p.offset?, keyset: p.keyset?, countable: p.countable, required: p.required?, default_limit: p.default_limit}

  defp pagination(_), do: nil

  def argument(a) do
    %{
      name: a.name,
      type: type_name(a.type),
      kind: kind(a.type),
      constraints: constraints(a.constraints),
      allow_nil: a.allow_nil?,
      sensitive: Map.get(a, :sensitive?, false)
    }
    |> Map.merge(detail(a.type, a.constraints))
  end

  @doc """
  Structure of composite types so the UI can render real controls: array item descriptor,
  embedded resource fields, union member types.
  """
  def detail({:array, inner}, c), do: %{items: describe(nil, inner, Keyword.get(c || [], :items, []))}

  def detail(type, c) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.embedded_type?(type) ->
        %{fields: type |> Info.public_attributes() |> Enum.map(&attribute/1)}

      type == Ash.Type.Union ->
        %{types: for({name, cfg} <- Keyword.get(c || [], :types, []), do: describe(name, cfg[:type], cfg[:constraints] || []))}

      Ash.Type.NewType.new_type?(type) ->
        detail(Ash.Type.NewType.subtype_of(type), Ash.Type.NewType.constraints(type, c || []))

      true ->
        %{}
    end
  end

  defp describe(name, type, c) do
    Map.merge(
      %{name: name, type: type_name(type), kind: kind(type), constraints: constraints(c)},
      detail(type, c)
    )
  end

  @doc "Coarse UI kind for a field control."
  def kind({:array, inner}), do: "array:" <> kind(inner)

  def kind(type) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.embedded_type?(type) -> "embedded"
      type == Ash.Type.Union -> "union"
      Ash.Type.NewType.new_type?(type) -> kind(Ash.Type.NewType.subtype_of(type))
      type in [Ash.Type.Boolean] -> "boolean"
      type in [Ash.Type.Integer] -> "integer"
      type in [Ash.Type.Float, Ash.Type.Decimal] -> "number"
      type in [Ash.Type.Date] -> "date"
      type in [Ash.Type.UtcDatetime, Ash.Type.UtcDatetimeUsec, Ash.Type.DateTime, Ash.Type.NaiveDatetime] -> "datetime"
      type in [Ash.Type.Atom] -> "atom"
      type in [Ash.Type.UUID, Ash.Type.UUIDv7] -> "uuid"
      type == Ash.Type.File -> "file"
      type in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Struct, Ash.Type.Tuple] -> "json"
      true -> "string"
    end
  end

  def type_name({:array, t}), do: "array of " <> type_name(t)
  def type_name(t) when is_atom(t), do: t |> Ash.Type.get_type() |> inspect() |> String.replace("Ash.Type.", "")
  def type_name(t), do: inspect(t)

  defp constraints(c) when is_list(c) do
    c |> Keyword.take([:one_of, :min, :max, :min_length, :max_length, :match, :allow_empty?, :trim?])
    |> Enum.map(fn
      {k, %Regex{} = r} -> {k, Regex.source(r)}
      {k, v} -> {k, v}
    end)
    |> Map.new()
  end

  defp constraints(_), do: %{}

  def short(module), do: module |> Module.split() |> List.last()
end
