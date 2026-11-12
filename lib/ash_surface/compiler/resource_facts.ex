defmodule AshSurface.Compiler.ResourceFacts do
  @moduledoc """
  Resource-level facts the per-action IR carries beyond the action's inputs
  (wave3-01): read/get semantics, projection options, identities,
  multitenancy, sortable and filterable fields, relationships, calculations
  and aggregates.

  Called exactly once per discovered action from `AshSurface.Compiler`'s
  normalize step (both the manifest and the raw-Ash path), so the schema
  fragments are rendered from the normalized entry with no second discovery.

  Every fact is read from the resource through `Ash.Resource.Info` (and, for
  surface options, `AshSurface.Resource.Projections`); nothing is guessed. A
  fact that cannot be read is `nil` with a typed reason recorded under
  `:unknown_reasons` (never a silent default). A module that is not an Ash
  resource yields all-nil facts with the single reason
  `:resource_not_introspectable`.
  """

  alias AshSurface.Compiler.{EmbeddedSchema, FilterSchema, TypeFacts}
  alias AshSurface.Resource.Projections

  @facts [
    :read_action,
    :get_by,
    :get_by_keys,
    :not_found_error?,
    :enable_sort?,
    :enable_filter?,
    :allowed_loads,
    :denied_loads,
    :identities,
    :primary_key,
    :multitenancy,
    :sortable_fields,
    :filter_entries,
    :relationships,
    :calculations,
    :aggregates,
    :public_attributes
  ]

  @doc "The fact keys this module emits."
  @spec fact_keys() :: [atom()]
  def fact_keys, do: @facts

  @doc """
  Builds the resource facts for `{resource, action}` (`action` is a raw
  `Ash.Resource.Actions.*` or an `Ash.Info.Manifest.Action`).
  """
  @spec build(module(), map()) :: map()
  def build(resource, action) do
    if introspectable?(resource) do
      do_build(resource, action)
    else
      @facts
      |> Map.new(&{&1, nil})
      |> Map.merge(%{
        get?: false,
        unknown_reasons: %{"resource" => "resource_not_introspectable"}
      })
    end
  end

  defp introspectable?(resource) do
    is_atom(resource) and not is_nil(resource) and Code.ensure_loaded?(resource) and
      function_exported?(resource, :spark_is, 0) and Ash.Resource.Info.resource?(resource)
  end

  defp do_build(resource, action) do
    raw = Ash.Resource.Info.action(resource, action.name)
    projection = projection(resource, action.name)
    reasons = %{}

    get_by = get_by(raw, projection)

    get? =
      Map.get(action, :get?) == true or (raw != nil and Map.get(raw, :get?) == true) or
        get_by != []

    read? = to_string(action.type) == "read"
    enable_sort? = projection_option(projection, :enable_sort?)
    pagination = Map.get(action, :pagination) || (raw && Map.get(raw, :pagination))

    {sortable, reasons} =
      sortable_fields(resource, read?, get?, enable_sort?, pagination, reasons)

    {filter_entries, reasons} = filter_entries(resource, read?, get?, projection, reasons)

    {relationships, reasons} = relationships(resource, reasons)

    %{
      get?: get?,
      read_action: projection && projection.read_action && to_string(projection.read_action),
      get_by: get_by,
      get_by_keys: Enum.map(get_by, &key_fact(resource, &1)),
      not_found_error?: if(get?, do: projection_option(projection, :not_found_error?)),
      enable_sort?: enable_sort?,
      enable_filter?: projection_option(projection, :enable_filter?),
      allowed_loads: loads(resource, projection && projection.allowed_loads),
      denied_loads: loads(resource, projection && projection.denied_loads),
      identities: identities(resource, projection),
      primary_key: Enum.map(Ash.Resource.Info.primary_key(resource), &wire_name(resource, &1)),
      multitenancy: multitenancy(resource),
      sortable_fields: sortable,
      filter_entries: filter_entries,
      relationships: relationships,
      calculations: calculations(resource),
      aggregates: aggregates(resource),
      public_attributes:
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.map(&wire_name(resource, &1.name))
        |> Enum.sort(),
      unknown_reasons:
        if(projection, do: reasons, else: Map.put(reasons, "projection", "no_surface_projection"))
    }
  end

  ## Projection options (AshSurface.Dsl.Projection entity of the action)

  defp projection(resource, action_name) do
    Projections.for_action(resource, action_name)
  rescue
    _ -> nil
  end

  # No projection declared: `not_found_error?` falls back to the global
  # `AshSurface.Config.not_found_error?/0` (ash_typescript pipeline semantics:
  # action option nil -> global config). Projection options carry a DSL default,
  # so an explicit projection always wins.
  defp projection_option(nil, :not_found_error?), do: AshSurface.Config.not_found_error?()

  defp projection_option(nil, key),
    do: Map.get(%{enable_sort?: true, enable_filter?: true}, key)

  defp projection_option(projection, key), do: Projections.option(projection, key)

  defp get_by(raw, projection) do
    declared = (projection && projection.get_by) || (raw && Map.get(raw, :get_by))
    declared |> List.wrap() |> Enum.map(&to_string/1)
  end

  # Load paths as dotted strings: `:comments`, `[comments: [:likes]]`,
  # `"comments.likes"` all normalise to `["comments", "comments.likes"]`-style
  # paths; anything else is dropped from the path list (never guessed).
  defp loads(_resource, nil), do: nil

  defp loads(resource, loads),
    do:
      loads
      |> flatten_loads([])
      |> Enum.map(&wire_load_path(resource, &1))
      |> Enum.uniq()
      |> Enum.sort()

  # Each dotted segment is a relationship; its wire name is taken on the resource that owns it.
  defp wire_load_path(resource, path) do
    {segments, _} =
      path
      |> String.split(".")
      |> Enum.map_reduce(resource, fn segment, owner ->
        case owner && relationship_named(owner, segment) do
          %{name: name, destination: dest} -> {wire_name(owner, name), dest}
          _ -> {segment, nil}
        end
      end)

    Enum.join(segments, ".")
  end

  defp relationship_named(owner, segment) do
    Ash.Resource.Info.public_relationships(owner) |> Enum.find(&(to_string(&1.name) == segment))
  rescue
    _ -> nil
  end

  defp flatten_loads(items, prefix) when is_list(items),
    do: Enum.flat_map(items, &flatten_loads(&1, prefix))

  defp flatten_loads({name, nested}, prefix) when is_atom(name) or is_binary(name) do
    path = prefix ++ [to_string(name)]
    [Enum.join(path, ".") | flatten_loads(List.wrap(nested), path)]
  end

  defp flatten_loads(name, prefix) when is_atom(name) or is_binary(name),
    do: [Enum.join(prefix ++ [to_string(name)], ".")]

  defp flatten_loads(_, _), do: []

  ## Identities

  defp identities(resource, projection) do
    declared = projection && projection.identities
    names = if is_list(declared) and declared != [], do: Enum.map(declared, &to_string/1)

    resource
    |> Ash.Resource.Info.identities()
    |> Enum.filter(&(is_nil(names) or to_string(&1.name) in names))
    |> Enum.map(fn identity ->
      %{
        "name" => to_string(identity.name),
        "keys" => Enum.map(identity.keys, &key_fact(resource, &1))
      }
    end)
    |> Enum.concat(primary_key_identity(resource, declared))
    |> Enum.sort_by(& &1["name"])
  end

  # `identities: [:_primary_key]` (the reference's implicit identity) names the primary key, which
  # Ash does not list among `identities`; render it as an identity over exactly the key parts so
  # composite keys admit as one all-parts-required lookup (`IdentitySchema` names it
  # `"primary_key"`).
  defp primary_key_identity(resource, declared) when is_list(declared) do
    if :_primary_key in declared do
      [
        %{
          "name" => "_primary_key",
          "keys" =>
            resource |> Ash.Resource.Info.primary_key() |> Enum.map(&key_fact(resource, &1))
        }
      ]
    else
      []
    end
  end

  defp primary_key_identity(_resource, _declared), do: []

  defp key_fact(resource, key) do
    kind =
      case Ash.Resource.Info.attribute(resource, key) do
        nil -> nil
        attr -> TypeFacts.kind(attr.type, attr.constraints)
      end

    %{"name" => wire_name(resource, key), "type" => %{"kind" => kind || "unknown"}}
  rescue
    # A string key naming no attribute (Ash.Resource.Info.attribute/2 accepts names).
    _ -> %{"name" => wire_name(resource, key), "type" => %{"kind" => "unknown"}}
  end

  ## Multitenancy

  defp multitenancy(resource) do
    %{
      "strategy" => resource |> Ash.Resource.Info.multitenancy_strategy() |> atom_string(),
      "global?" => Ash.Resource.Info.multitenancy_global?(resource) == true,
      "attribute" => resource |> Ash.Resource.Info.multitenancy_attribute() |> atom_string()
    }
  end

  defp atom_string(nil), do: nil
  defp atom_string(value), do: to_string(value)

  ## Sortable fields (resource fields, never input names)

  defp sortable_fields(_resource, false, _get?, _enable, _pagination, reasons),
    do: {nil, Map.put(reasons, "sortable_fields", "not_a_read_action")}

  defp sortable_fields(_resource, _read?, true, _enable, _pagination, reasons),
    do: {nil, Map.put(reasons, "sortable_fields", "get_action_has_no_sort")}

  defp sortable_fields(_resource, _read?, _get?, false, _pagination, reasons),
    do: {nil, Map.put(reasons, "sortable_fields", "enable_sort_false")}

  defp sortable_fields(resource, _read?, _get?, _enable, pagination, reasons) do
    type = if keyset_only?(pagination), do: :keyset, else: :offset

    fields =
      resource
      |> Ash.Resource.Info.public_fields()
      |> Enum.reject(&(Map.get(&1, :field?) == false))
      |> Enum.map(& &1.name)
      |> Enum.filter(
        &Ash.Resource.Info.sortable?(resource, &1, pagination_type: type, include_private?: false)
      )
      |> Enum.map(&wire_name(resource, &1))
      |> Enum.sort()

    case fields do
      [] -> {nil, Map.put(reasons, "sortable_fields", "no_sortable_fields")}
      _ -> {fields, reasons}
    end
  end

  # Wire name of a resource field: `FieldName.wire/2` (type callback, resource `field_names`
  # verbatim, else the configured output formatter) -- the one naming helper.
  defp wire_name(resource, name), do: AshSurface.FieldName.wire(resource, name)

  defp keyset_only?(%{} = p), do: Map.get(p, :keyset?) == true and Map.get(p, :offset?) != true
  defp keyset_only?(_), do: false

  ## Filter entries (filterable resource fields: attributes, calculations, aggregates)

  defp filter_entries(_resource, false, _get?, _projection, reasons),
    do: {nil, Map.put(reasons, "filter_entries", "not_a_read_action")}

  defp filter_entries(_resource, _read?, true, _projection, reasons),
    do: {nil, Map.put(reasons, "filter_entries", "get_action_has_no_filter")}

  defp filter_entries(resource, _read?, _get?, projection, reasons) do
    if projection_option(projection, :enable_filter?) == false do
      {nil, Map.put(reasons, "filter_entries", "enable_filter_false")}
    else
      functions = functions(resource)

      entries =
        (attribute_entries(resource) ++
           calculation_entries(resource) ++
           aggregate_entries(resource) ++ relationship_entries(resource))
        |> Enum.map(&put_functions(&1, functions))
        |> Enum.sort_by(& &1["name"])

      case entries do
        [] -> {nil, Map.put(reasons, "filter_entries", "no_filterable_fields")}
        _ -> {entries, reasons}
      end
    end
  end

  @doc """
  Filter entries of an embedded resource's public attributes (an embedded resource has no read
  action, so it carries no `filter_entries` of its own); wire names follow the formatter and
  `field_names` mapping.
  """
  @spec embedded_filter_entries(module()) :: [map()]
  def embedded_filter_entries(resource) do
    functions = functions(resource)

    # No aggregate entries: an embedded resource has no data layer able to aggregate (Ash:
    # "is not aggregatable"), so an aggregate on one is never a filterable field.
    (attribute_entries(resource, true) ++ calculation_entries(resource, true))
    |> Enum.map(&put_functions(&1, functions))
    |> Enum.sort_by(& &1["name"])
  end

  defp attribute_entries(resource, typed? \\ false) do
    for attr <- Ash.Resource.Info.public_attributes(resource),
        Map.get(attr, :filterable?) != false do
      entry(
        wire_name(resource, attr.name),
        attr.allow_nil?,
        TypeFacts.analyze(attr.type, attr.constraints),
        typed?
      )
    end
  end

  # Scalar kinds a related destination filters on (containers, unions and unknown kinds stay
  # filterable on their own resource only: the destination union is expanded per logical
  # level and the compiled filter is capped at 1 MB).
  @related_kinds ~w(string ci_string integer float decimal boolean uuid date time time_usec
                    utc_datetime utc_datetime_usec datetime naive_datetime atom)

  # Public relationships become `related` filter entries: the destination's filterable
  # public scalar attributes as leaf inputs (no further relationships; `FilterSchema`
  # renders the destination union at related depth).
  defp relationship_entries(resource) do
    for rel <- Ash.Resource.Info.public_relationships(resource),
        dest = rel.destination,
        Ash.Resource.Info.resource?(dest),
        inputs =
          dest |> attribute_entries() |> Enum.filter(&(&1["type"]["kind"] in @related_kinds)),
        inputs != [] do
      %{
        "name" => wire_name(resource, rel.name),
        "allow_nil?" => false,
        "type" => %{"kind" => "map"},
        "relationship" => %{"filter_inputs" => Enum.sort_by(inputs, & &1["name"])}
      }
    end
  end

  defp calculation_entries(resource, typed? \\ false) do
    for calc <- Ash.Resource.Info.public_calculations(resource),
        Map.get(calc, :filterable?) != false,
        Map.get(calc, :field?) != false do
      entry(
        wire_name(resource, calc.name),
        calc.allow_nil?,
        TypeFacts.analyze(calc.type, calc.constraints),
        typed?
      )
    end
  end

  defp aggregate_entries(resource) do
    for agg <- Ash.Resource.Info.public_aggregates(resource),
        Map.get(agg, :filterable?) != false do
      case Ash.Query.Aggregate.aggregate_type(resource, agg) do
        {:ok, type, constraints} ->
          entry(
            wire_name(resource, agg.name),
            agg.kind not in [:count, :exists, :list],
            TypeFacts.analyze(type, constraints)
          )

        _ ->
          %{
            "name" => wire_name(resource, agg.name),
            "allow_nil?" => true,
            "type" => %{"kind" => "unknown"}
          }
      end
    end
  end

  # `typed?` (embedded filters): container/union attribute values carry their real type schema
  # (`"zod"`: bounded-depth EmbeddedSchema render; array items under `"element_zod"`). A type
  # whose schema cannot be rendered is withheld from the filter (never z.unknown()).
  defp entry(name, allow_nil?, analysis, typed? \\ false) do
    base = %{
      "name" => to_string(name),
      "allow_nil?" => allow_nil? == true,
      "type" => %{"kind" => analysis.kind || "unknown"}
    }

    base =
      case get_in(analysis.definition, ["type", "items", "type"]) do
        %{"kind" => _} = items -> Map.put(base, "items", items)
        _ -> base
      end

    base =
      case get_in(analysis.definition, ["type", "values"]) do
        [_ | _] = values when analysis.kind in ["atom", "enum"] ->
          Map.put(base, "values", values)

        _ ->
          base
      end

    if typed?, do: put_typed_zod(base, analysis), else: base
  end

  @embedded_cycle_depth 2

  defp put_typed_zod(base, %{kind: "array", definition: definition}) do
    item = get_in(definition, ["type", "items"])

    cond do
      is_map(item) and EmbeddedSchema.container?(item) ->
        case render_typed(item) do
          {:ok, zod} -> Map.put(base, "element_zod", zod)
          :error -> Map.put(base, "filterable", false)
        end

      true ->
        base
    end
  end

  defp put_typed_zod(base, %{definition: definition}) do
    if EmbeddedSchema.container?(definition) do
      case render_typed(definition) do
        {:ok, zod} -> Map.put(base, "zod", zod)
        :error -> Map.put(base, "filterable", false)
      end
    else
      base
    end
  end

  defp render_typed(definition) do
    opts = [
      resources: TypeFacts.embedded_resources([definition]),
      cycle_depth: @embedded_cycle_depth
    ]

    case EmbeddedSchema.render(definition, opts) do
      {:ok, zod} -> {:ok, zod}
      _ -> :error
    end
  end

  # Data-layer function names are metadata (`FilterSchema.split_capabilities/1`
  # contract): a function never becomes an operator. Names an operator key
  # claims (`FilterSchema.operator_key/1`) are operators, not functions.
  defp functions(resource) do
    resource
    |> Ash.DataLayer.functions()
    |> Enum.map(&function_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&match?({:ok, _}, FilterSchema.operator_key(&1)))
    |> Enum.uniq()
    |> Enum.sort()
  rescue
    _ -> []
  end

  defp function_name(module) when is_atom(module) do
    if Code.ensure_loaded?(module) and function_exported?(module, :name, 0),
      do: to_string(module.name())
  end

  defp function_name(_), do: nil

  defp put_functions(entry, []), do: entry
  defp put_functions(entry, functions), do: Map.put(entry, "functions", functions)

  ## Relationships

  defp relationships(resource, reasons) do
    case Ash.Resource.Info.public_relationships(resource) do
      [] ->
        {nil, Map.put(reasons, "relationships", "no_public_relationships")}

      rels ->
        {rels |> Enum.map(&relationship(resource, &1)) |> Enum.sort_by(& &1["name"]), reasons}
    end
  end

  defp relationship(resource, rel) do
    destination = rel.destination

    %{
      "name" => wire_name(resource, rel.name),
      "destination" => module_name(destination),
      "cardinality" => cardinality(rel),
      "primitive_fields" =>
        destination
        |> Ash.Resource.Info.public_attributes()
        |> Enum.map(&wire_name(destination, &1.name))
        |> Enum.sort(),
      "pagination" => relationship_pagination(rel),
      "filterable" => Map.get(rel, :filterable?) != false,
      "sortable" => Map.get(rel, :sortable?) != false,
      "exposed" => true
    }
  end

  # belongs_to / has_one => "one"; has_many / many_to_many => "many".
  defp cardinality(%Ash.Resource.Relationships.BelongsTo{}), do: "one"
  defp cardinality(%Ash.Resource.Relationships.HasOne{}), do: "one"
  defp cardinality(%Ash.Resource.Relationships.HasMany{}), do: "many"
  defp cardinality(%Ash.Resource.Relationships.ManyToMany{}), do: "many"

  @doc """
  Read action a many-relationship loads through (port of ash_typescript
  `Custom.relationship_read_action/1`): the relationship's own `read_action`
  override, else the destination's primary read. `nil` for to-one relationships
  and destinations without a primary read.
  """
  @spec relationship_read_action(struct()) :: atom() | nil
  def relationship_read_action(rel) do
    if cardinality(rel) == "many" do
      case Map.get(rel, :read_action) do
        nil ->
          case Ash.Resource.Info.primary_action(rel.destination, :read) do
            %{name: name} -> name
            _ -> nil
          end

        name ->
          name
      end
    end
  end

  @doc """
  Pagination decoration of a relationship: `"offset" | "keyset" | "mixed" | "none"`,
  derived from `relationship_read_action/1` (to-one relationships are `"none"`).
  """
  @spec relationship_pagination(struct()) :: String.t()
  def relationship_pagination(rel) do
    with name when not is_nil(name) <- relationship_read_action(rel),
         %{pagination: %{} = p} <- Ash.Resource.Info.action(rel.destination, name, :read) do
      case {Map.get(p, :offset?) == true, Map.get(p, :keyset?) == true} do
        {true, true} -> "mixed"
        {true, false} -> "offset"
        {false, true} -> "keyset"
        _ -> "none"
      end
    else
      _ -> "none"
    end
  end

  ## Calculations

  defp calculations(resource) do
    case Ash.Resource.Info.public_calculations(resource) do
      [] -> nil
      calcs -> calcs |> Enum.map(&calculation(resource, &1)) |> Enum.sort_by(& &1.name)
    end
  end

  defp calculation(resource, calc) do
    ret = TypeFacts.analyze(calc.type, calc.constraints)

    %{
      name: wire_name(resource, calc.name),
      return_kind: ret.kind || "unknown",
      return_ref: return_ref(ret),
      allow_nil?: calc.allow_nil? == true,
      arguments: Enum.map(calc.arguments, &calculation_argument/1)
    }
  end

  defp calculation_argument(arg) do
    analysis = TypeFacts.analyze(arg.type, arg.constraints)

    %{
      name: AshSurface.FieldName.emitted(arg.name),
      kind: analysis.kind || "unknown",
      constraints: analysis.declared_constraints,
      allow_nil?: arg.allow_nil? == true,
      has_default?: not is_nil(arg.default)
    }
  end

  defp return_ref(%{definition: %{"type" => %{"resource?" => true, "instance_of" => name}}})
       when is_binary(name),
       do: name

  defp return_ref(_), do: nil

  ## Aggregates

  defp aggregates(resource) do
    case Ash.Resource.Info.public_aggregates(resource) do
      [] -> nil
      aggs -> aggs |> Enum.map(&aggregate(resource, &1)) |> Enum.sort_by(& &1.name)
    end
  end

  defp aggregate(resource, agg) do
    base = %{
      name: wire_name(resource, agg.name),
      kind: agg.kind,
      field: agg.field && to_string(agg.field),
      allow_nil?: agg.kind not in [:count, :exists, :list]
    }

    case Ash.Query.Aggregate.aggregate_type(resource, agg) do
      {:ok, type, constraints} ->
        analysis = element_analysis(agg.kind, TypeFacts.analyze(type, constraints))

        base
        |> Map.put(:field_kind, analysis.kind || "unknown")
        |> put_complex(analysis)

      _ ->
        Map.put(base, :field_kind, "unknown")
    end
  end

  # A `:list` aggregate's type is `{:array, element}`; the renderer wraps the
  # element itself, so the element's facts are what it needs.
  defp element_analysis(
         :list,
         %{
           definition: %{
             "type" => %{"kind" => "array", "items" => %{"type" => %{"kind" => kind}} = items}
           }
         } = analysis
       ),
       do: %{analysis | kind: kind, definition: items}

  defp element_analysis(_kind, analysis), do: analysis

  defp put_complex(
         base,
         %{definition: %{"type" => %{"kind" => kind} = type} = definition} = _analysis
       )
       when kind in ["union", "embedded_resource", "typed_struct", "typed_map", "map", "struct"] do
    base = Map.put(base, :field_definition, definition)

    case type do
      %{"members" => [_ | _] = members} -> Map.put(base, :union_facts, members)
      _ -> base
    end
  end

  defp put_complex(base, _), do: base

  defp module_name(module), do: module |> Module.split() |> Enum.join(".")
end
