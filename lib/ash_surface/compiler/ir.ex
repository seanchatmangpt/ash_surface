# Canonical compiler IR slices — ONE owner (v50 integration reconciliation).
#
# Branch-local copies of `AshSurface.Compiler.IR` (semantic.ex, schema.ex,
# aria.ex) are superseded by this file per the wave doctrine: the local
# Section-behaviour and IR duplicates in section modules yield to the single
# canonical declaration. Slice shapes are carried verbatim from their landing
# branches:
#
#   * `Input` + `Schema` — the per-action carrier (v08's surviving shape; its
#     tests pin `%IR.Schema{}` with `action_id`/`inputs`/`presentation`/`aria`).
#   * `Semantic` — the R2RML-delegated semantic slice (v04, verbatim).
#   * `Boundary` — the schema-section slice (v07, verbatim; renamed from its
#     branch-local `Schema` name to resolve the collision with the carrier —
#     its own moduledoc calls these "boundary schemas").
#
# `AshSurface.Compiler.IR.Capability` / `.Presentation` remain declared inside
# their owning section files (capability.ex, presentation.ex); nested-named
# module declarations compose with this parent without conflict.

defmodule AshSurface.Compiler.IR do
  @moduledoc """
  Canonical compiler IR slices, one declaration site.

  Every field is a delegated fact carried verbatim from the owning upstream
  surface; a `nil` field is an honest UNKNOWN, never a fabricated default.
  """

  defmodule Input do
    @enforce_keys [:name, :type, :allow_nil?]
    defstruct [:name, :type, :allow_nil?, :description]

    @type t :: %__MODULE__{
            name: atom() | String.t(),
            type: Ash.Info.Manifest.Type.t() | atom() | nil,
            allow_nil?: boolean(),
            description: String.t() | nil
          }
  end

  defmodule Schema do
    @moduledoc """
    Per-action carrier: the action's stable identity, normalized inputs, and
    the mounted output of each compiler section under that section's name.
    """
    @enforce_keys [:action_id, :inputs]
    defstruct [:action_id, :inputs, :presentation, :aria]

    @type t :: %__MODULE__{
            action_id: String.t(),
            inputs: [Input.t()],
            presentation: map() | nil,
            aria: map() | nil
          }
  end

  defmodule Semantic do
    @moduledoc """
    Semantic identity of one `{resource, action}` pair (R2RML delegation).

      * `subject_iri` — the R2RML subject IRI contract (template or constant)
        exactly as mapped. `nil` when the subject maps to a blank node.
      * `capability_iri` — the mapped RDF class IRI the action operates on.
      * `predicates` — the mapped predicate IRIs, verbatim and in mapping
        order. Empty when the mapping admits no property mappings.
      * `shape_id` — the SHACL `sh:NodeShape` identity exactly as emitted by
        AshR2RML's SHACL renderer for this mapping.
      * `ontology` — ontology provenance: the named-graph IRIs the mapping
        admits. Empty when the mapping admits no graph.
    """

    @enforce_keys [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]
    defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

    @type t :: %__MODULE__{
            subject_iri: String.t() | nil,
            capability_iri: String.t() | nil,
            predicates: [String.t()],
            shape_id: String.t() | nil,
            ontology: [String.t()]
          }
  end

  defmodule Boundary do
    @moduledoc """
    Per-action boundary-schema slice (the schema section's output).

    * `input` — the input description: argument name -> type description map
    * `output` — the output description: the return type description, or
      `nil` when the action returns nothing declared
    * `zod` — the zod projection as source text (paired input/output schemas
      mirroring `AshSurface.Projector.Expo`'s emission idioms)
    * `aria` — derived accessibility metadata (zero-config, from names only)
    """

    @enforce_keys [:input, :output, :zod, :aria]
    defstruct [:input, :output, :zod, :aria]

    @type t :: %__MODULE__{
            input: %{optional(String.t()) => map()},
            output: map() | nil,
            zod: String.t(),
            aria: map()
          }
  end
end

defmodule AshSurface.Compiler.IR.Fragments do
  @moduledoc """
  Wires the per-action Zod fragments into the canonical `AshSurface.IR.Schema`:
  filter, sort, page, capability flags, error carry, get/identity, tenant,
  relationship load, field selection, calculations, aggregates, the
  validation-error shape, the carried non-zod facts, and the typed reason for
  every fragment that is honestly nil.

  Pure: reads only the already-normalized action entry (no second
  discovery). Each fragment is rendered by its Phase-A renderer directly; a
  renderer refusal or an inapplicable fragment is `nil` AND recorded in
  `nil_reasons` (field name -> reason atom string, or
  `%{"reason" => tag, "detail" => text}`), never swallowed and never
  fabricated. Output is deterministic (inputs are pre-sorted).
  """

  alias AshSurface.Compiler.{
    CalculationSchema,
    EmbeddedSchema,
    ErrorSchema,
    FilterSchema,
    IdentitySchema,
    QuerySchema,
    RelationshipSchema,
    RecordSchema,
    SelectionSchema,
    ValidationErrorSchema,
    ZodType
  }

  alias AshSurface.IR.ErrorShape

  @record_actions ~w(read create update)

  @spec enrich(AshSurface.IR.Schema.t() | nil, map()) :: AshSurface.IR.Schema.t() | nil
  def enrich(%AshSurface.IR.Schema{} = schema, action) when is_map(action) do
    type = to_string(Map.get(action, :action_type))
    read? = type == "read"
    inputs = Map.get(action, :inputs) || []
    pagination = Map.get(action, :pagination)
    carried = Map.get(action, :unknown_reasons) || %{}

    {sort, page} = query_params(action, read?, pagination, carried)

    fragments = [
      {"filter", filter(action, read?, carried)},
      {"sort", sort},
      {"page", page},
      {"get", get(action, carried)},
      {"tenant", tenant(action)},
      {"load", load(action, type, carried)},
      {"selection", selection(action, type)},
      {"calculations", calculations(action, carried)},
      {"aggregates", aggregates(action)},
      {"validation_error", validation_error(action, inputs)},
      {"response_zod", response_zod(action, type)}
    ]

    values = Map.new(fragments, fn {name, outcome} -> {name, value(outcome)} end)

    reasons =
      fragments
      |> Enum.flat_map(fn {name, outcome} -> reason_entry(name, outcome) end)
      |> Map.new()
      |> Map.merge(Map.new(carried, fn {k, v} -> {to_string(k), reason(v)} end), fn _k, own, _c ->
        own
      end)

    %{
      schema
      | filter: values["filter"],
        sort: values["sort"],
        page: values["page"],
        capability_flags: if(read?, do: flags(action, pagination)),
        response_zod: values["response_zod"],
        error: error_ref(action, inputs),
        get: values["get"],
        tenant: values["tenant"],
        load: values["load"],
        selection: values["selection"],
        calculations: values["calculations"],
        aggregates: values["aggregates"],
        validation_error: values["validation_error"],
        facts: facts(action, pagination),
        nil_reasons: reasons
    }
  end

  def enrich(other, _action), do: other

  # -- outcomes: {:ok, value} | {:absent, reason} -------------------------------

  defp value({:ok, v}), do: v
  defp value({:absent, _}), do: nil

  defp reason_entry(_name, {:ok, _}), do: []
  defp reason_entry(name, {:absent, why}), do: [{name, reason(why)}]

  defp outcome({:ok, v}), do: {:ok, v}
  defp outcome({:ok, v, _extra}), do: {:ok, v}
  defp outcome({:error, why}), do: {:absent, why}

  defp skip(why), do: {:absent, why}

  # A whole-resource reason (`"resource"`) explains every resource-derived
  # fragment; otherwise the fragment-specific carried reason; else the default.
  defp why(carried, key, default), do: carried["resource"] || carried[key] || default

  @doc false
  # Typed reason: atoms and strings render as themselves; tagged tuples as
  # `%{"reason" => tag, "detail" => inspect(rest)}`.
  @spec reason(term()) :: String.t() | map()
  def reason(why) when is_atom(why), do: Atom.to_string(why)
  def reason(why) when is_binary(why), do: why

  def reason(why) when is_tuple(why) and tuple_size(why) > 0 and is_atom(elem(why, 0)) do
    [tag | rest] = Tuple.to_list(why)
    %{"reason" => Atom.to_string(tag), "detail" => inspect(rest, limit: 8, printable_limit: 200)}
  end

  def reason(why),
    do: %{"reason" => "unspecified", "detail" => inspect(why, limit: 8, printable_limit: 200)}

  # -- query: filter / sort / page -------------------------------------------

  defp filter(_action, false, _carried), do: skip(:not_a_read_action)

  defp filter(action, true, carried) do
    cond do
      Map.get(action, :get?) == true ->
        skip(:get_action_has_no_filter)

      Map.get(action, :enable_filter?) == false ->
        skip(:enable_filter_false)

      is_nil(Map.get(action, :filter_entries)) ->
        skip(why(carried, "filter_entries", :filter_entries_not_carried))

      true ->
        outcome(FilterSchema.render_filter_schema(action.filter_entries))
    end
  end

  defp query_params(_action, false, _pagination, _carried),
    do: {skip(:not_a_read_action), skip(:not_a_read_action)}

  defp query_params(action, true, pagination, carried) do
    get? = Map.get(action, :get?) == true
    page_opts = page_opts(pagination)

    params =
      QuerySchema.render_query_params(%{
        read?: true,
        get?: get?,
        enable_sort?: Map.get(action, :enable_sort?) != false,
        sortable_fields: Map.get(action, :sortable_fields) || [],
        pagination: page_opts,
        sort_array?: false
      })

    case params do
      {:ok, %{sort: sort, page: page}} ->
        {present(sort, sort_reason(action, get?, carried)),
         present(page, page_reason(get?, pagination))}

      {:error, why} ->
        {skip(why), skip(why)}
    end
  end

  defp present(nil, why), do: skip(why)
  defp present(zod, _why), do: {:ok, zod}

  defp sort_reason(_action, true, _carried), do: :get_action_has_no_sort
  defp sort_reason(%{enable_sort?: false}, _get?, _carried), do: :enable_sort_false

  defp sort_reason(_action, _get?, carried),
    do: why(carried, "sortable_fields", :sortable_fields_not_carried)

  defp page_reason(true, _pagination), do: :get_action_has_no_page
  defp page_reason(_get?, nil), do: :no_pagination
  defp page_reason(_get?, _pagination), do: :pagination_refused

  defp page_opts(nil), do: nil

  defp page_opts(p) do
    %{
      offset?: Map.get(p, :offset?) == true,
      keyset?: Map.get(p, :keyset?) == true,
      required?: Map.get(p, :required?) == true,
      countable?: Map.get(p, :countable?) == true,
      default_limit?: not is_nil(Map.get(p, :default_limit)),
      max_limit: Map.get(p, :max_page_size)
    }
  end

  defp flags(action, pagination) do
    p = pagination || %{}

    %{
      "countable" => Map.get(p, :countable?) == true,
      "get" => Map.get(action, :get?) == true,
      "keyset" => Map.get(p, :keyset?) == true,
      "offset" => Map.get(p, :offset?) == true,
      "required" => Map.get(p, :required?) == true
    }
  end

  # -- get / identities / tenant ---------------------------------------------

  defp get(%{get?: true} = action, carried) do
    identities = Map.get(action, :identities)
    keys = Map.get(action, :get_by_keys) || []

    cond do
      is_nil(identities) -> skip(why(carried, "get", :identities_not_carried))
      true -> get_schemas(identities, Map.get(action, :primary_key) || [], keys)
    end
  end

  defp get(_action, _carried), do: skip(:not_a_get_action)

  defp get_schemas(identities, primary_key, keys) do
    input =
      case keys do
        [] -> nil
        _ -> unwrap(QuerySchema.render_get_input_schema(Enum.map(keys, &key_fragment/1)))
      end

    by_identity =
      case IdentitySchema.render_get_schema(identities, primary_key) do
        {:ok, map} -> map
        {:error, _} -> nil
      end

    case {input, by_identity} do
      {nil, nil} -> skip(:no_admitted_identities)
      _ -> {:ok, %{"input" => input, "identities" => by_identity}}
    end
  end

  defp key_fragment(%{"name" => name, "type" => type}),
    do: {name, ZodType.fragment(%{"type" => type, "allow_nil?" => false})}

  defp unwrap({:ok, zod}), do: zod
  defp unwrap(_), do: nil

  defp tenant(action) do
    case Map.get(action, :multitenancy) do
      nil ->
        skip(:multitenancy_not_carried)

      mt ->
        case IdentitySchema.render_tenant_schema(mt) do
          {:ok, nil} -> skip(:no_tenant_parameter)
          {:ok, zod} -> {:ok, zod}
        end
    end
  end

  # -- relationships / selection / calculations / aggregates -----------------

  defp load(_action, type, _carried) when type not in @record_actions,
    do: skip(:action_returns_no_record)

  defp load(action, _type, carried) do
    case Map.get(action, :relationships) do
      nil -> skip(why(carried, "relationships", :relationships_not_carried))
      rels -> outcome(RelationshipSchema.render_load_schema(rels))
    end
  end

  defp selection(_action, type) when type not in @record_actions,
    do: skip(:action_returns_no_record)

  defp selection(action, _type) do
    case Map.get(action, :public_attributes) do
      nil ->
        skip(:public_attributes_not_carried)

      fields ->
        opts =
          [
            relationships: Map.get(action, :relationships),
            allowed_loads: Map.get(action, :allowed_loads),
            denied_loads: Map.get(action, :denied_loads),
            calculations: Map.get(action, :calculations),
            aggregates: Map.get(action, :aggregates)
          ]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        outcome(SelectionSchema.render_selection_schema(fields, [], opts))
    end
  end

  # The record schema of the action's resource (read/create/update return one
  # record, or a page of them). Shared/cyclic embedded resources are inlined
  # (`cycle_depth: 1`) because the IR field is one embeddable expression.
  defp response_zod(action, "action") do
    case Map.get(action, :returns_facts) do
      nil -> skip(:no_declared_return)
      definition -> returns_zod(definition, Map.get(action, :embedded_resources) || %{})
    end
  end

  defp response_zod(_action, type) when type not in @record_actions,
    do: skip(:no_record_schema)

  defp response_zod(action, _type) do
    case Map.get(action, :resource) do
      resource when is_atom(resource) and not is_nil(resource) ->
        with {:ok, %{declarations: [], expression: expr}} <- RecordSchema.render(resource) do
          {:ok, expr}
        else
          _ ->
            case RecordSchema.render(resource, cycle_depth: 1) do
              {:ok, %{declarations: [], expression: expr}} -> {:ok, expr}
              {:ok, _named} -> skip(:named_declarations)
              {:error, why} -> skip(why)
            end
        end

      _ ->
        skip(:no_record_schema)
    end
  end

  defp returns_zod(definition, resources) do
    if EmbeddedSchema.container?(definition) do
      with {:error, _} <- inline_program(definition, resources, []),
           {:error, why} <- inline_program(definition, resources, cycle_depth: 1) do
        skip(why)
      end
    else
      {:ok, ZodType.fragment(definition)}
    end
  end

  defp inline_program(definition, resources, extra) do
    case EmbeddedSchema.render_program(definition, [resources: resources] ++ extra) do
      {:ok, %{declarations: [], expression: expr}} -> {:ok, expr}
      {:ok, _named} -> {:error, :named_declarations}
      {:error, _} = error -> error
    end
  end

  defp calculations(action, carried) do
    case Map.get(action, :calculations) do
      nil ->
        skip(why(carried, "calculations", :no_public_calculations))

      facts ->
        with {:ok, load} <- CalculationSchema.render_calculation_schema(facts),
             {:ok, results} <- CalculationSchema.render_calculation_result_schemas(facts) do
          {:ok, %{"load" => load, "results" => Map.new(results)}}
        else
          {:error, why} -> skip(why)
        end
    end
  end

  defp aggregates(action) do
    case Map.get(action, :aggregates) do
      nil ->
        skip(:no_public_aggregates)

      facts ->
        case CalculationSchema.render_aggregate_schemas(facts) do
          {:ok, pairs} -> {:ok, Map.new(pairs)}
          {:error, why} -> skip(why)
        end
    end
  end

  # -- validation errors / error carry ---------------------------------------

  defp validation_error(_action, []), do: skip(:no_inputs)

  defp validation_error(action, inputs) do
    fields =
      Enum.map(inputs, fn i ->
        type =
          case Map.get(i, :type_facts) do
            %{"type" => %{} = t} -> t
            _ -> %{"kind" => Map.get(i, :type) || "unknown"}
          end

        %{"name" => wire_input(action, i.name), "type" => type, "wire" => true}
      end)

    definition = %{"type" => %{"kind" => "typed_map", "fields" => fields}}

    outcome(
      ValidationErrorSchema.render(definition,
        formatter: &AshSurface.FieldName.emitted/1,
        resources: Map.get(action, :embedded_resources) || %{}
      )
    )
  end

  defp wire_input(action, name),
    do:
      AshSurface.FieldName.wire_argument(
        Map.get(action, :resource),
        Map.get(action, :action),
        name
      )

  defp error_ref(action, inputs) do
    names = Enum.map(inputs, &wire_input(action, &1.name))

    %{
      "carry" => ErrorSchema.carry(names),
      "catch_all" => ErrorShape.catch_all(),
      "field_errors" => ErrorSchema.field_errors(names),
      "shape" => "AshSurface.IR.ErrorShape",
      "types" => ErrorShape.types(),
      "zod" => ErrorSchema.union()
    }
  end

  # -- carried facts (JSON-isomorphic) ---------------------------------------

  @fact_keys ~w(get? read_action get_by not_found_error? enable_sort? enable_filter? allowed_loads
                denied_loads identities primary_key multitenancy sortable_fields relationships
                calculations aggregates)a

  defp facts(action, pagination) do
    action
    |> Map.take(@fact_keys)
    |> Map.put(:pagination, pagination)
    |> put_field_names(action)
    |> jsonish()
  end

  # Inverse wire-name tables (client name -> server name) so server-side names round-trip.
  defp put_field_names(facts, action) do
    names = Enum.map(Map.get(action, :inputs) || [], & &1.name)

    case AshSurface.FieldName.action_inverse(
           Map.get(action, :resource),
           Map.get(action, :action),
           names
         ) do
      {:ok, inverse} -> Map.put(facts, :field_names, inverse)
      {:error, _} -> facts
    end
  end

  defp jsonish(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), jsonish(v)} end)

  defp jsonish(list) when is_list(list), do: Enum.map(list, &jsonish/1)
  defp jsonish(v) when is_boolean(v) or is_nil(v), do: v
  defp jsonish(v) when is_atom(v), do: Atom.to_string(v)
  defp jsonish(v), do: v
end
