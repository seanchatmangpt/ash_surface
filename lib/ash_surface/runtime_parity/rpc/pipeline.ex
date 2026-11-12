defmodule AshSurface.RuntimeParity.Rpc.Pipeline do
  @moduledoc """
  Non-actuating RPC pipeline core (port of `AshTypescript.Rpc.Pipeline`, stages 1, 3 and 4).

    1. `parse_request/3` - parse and validate a client request into `Request` (typed refusals)
    2. (not ported) action execution: AshSurface never actuates (README: "it never actuates")
    3. `process_result/2` - apply field selection to an already-materialized result term
    4. `format_output/2` - format for client consumption

  `run_with_result/4` chains 1 + 3 + 4 over a caller-supplied result term.
  Entries come from the table installed with `Support.install/2`; an entry is a map
  `%{name, resource, action, get?, get_by, not_found_error?, enable_filter?, enable_sort?,
  allowed_loads, denied_loads, show_metadata, metadata_names, identities}`
  (see `entry/3`).
  """

  alias AshSurface.RuntimeParity.Rpc.{
    FieldFormatter,
    InputFormatter,
    OutputFormatter,
    Request,
    ResultProcessor,
    Support,
    ValueFormatter
  }

  alias AshSurface.RuntimeParity.RequestedFieldsProcessor
  alias AshSurface.RuntimeParity.RequestedFields.LoadRestrictions
  alias AshSurface.RuntimeParity.Rpc.ErrorBuilder
  alias AshSurface.ErrorFormatter

  @page_keys [:limit, :offset, :count, :after, :before]

  @doc "Build an entry map (defaults mirror the reference rpc_action options)."
  def entry(name, resource, action, opts \\ []) do
    Map.merge(
      %{
        name: name,
        resource: resource,
        action: action,
        get?: false,
        get_by: [],
        not_found_error?: true,
        enable_filter?: true,
        enable_sort?: true,
        allowed_loads: nil,
        denied_loads: nil,
        show_metadata: nil,
        metadata_names: [],
        identities: nil
      },
      Map.new(opts)
    )
  end

  @doc """
  Stage 1: parse and validate. `params` is the string-keyed client map
  (`"action"`, `"input"`, `"fields"`, `"filter"`, `"sort"`, `"page"`, `"identity"`, ...).
  Options: `:validation_mode?`, `:actor`, `:tenant`, `:context`.
  """
  def parse_request(params, opts \\ []), do: do_parse_request(params, opts)

  def run_with_result(params, result, opts \\ [], parse_opts \\ []) do
    case do_parse_request(params, parse_opts) do
      {:ok, request} ->
        with {:ok, processed} <- process_result(result, request) do
          format_output(%{success: true, data: processed}, request)
        else
          {:error, reason} -> error_response(reason, opts)
        end

      {:error, reason} ->
        error_response(reason, opts)
    end
  end

  @doc "Formatted failure envelope for a typed refusal term."
  def error_response(reason, _opts \\ []) do
    errors = reason |> ErrorBuilder.build_error_response() |> List.wrap()
    format_output(%{success: false, errors: errors})
  end

  # Under an explicit `AshSurface.FieldName.with_formatter/2` scope (the compile-option scope,
  # inherited by Tasks through `$callers`) the scoped formatter is the single source of client
  # spellings. A requested field, at ANY nesting depth (relationship / embedded destinations are
  # resolved and checked against their own field set), a filter key, or a sort field whose client
  # spelling is the Config-formatter spelling but not the scoped one is refused as an unknown
  # field, instead of resolving through the formatter's lenient string parse (camel under
  # snake_case). Explicit field_names overrides stay exempt. KD-10: ash_typescript is lenient
  # here; ash_surface is stricter inside a scope.
  defp check_scoped_spellings(params, resource) do
    case AshSurface.FieldName.scoped_formatter() do
      nil ->
        :ok

      formatter ->
        ctx = %{scoped: formatter, config: AshSurface.Config.output_field_formatter()}

        # Raw client params: normalised ones already had nested keys parsed to atoms.
        raw = fn name ->
          Enum.find_value([name, Macro.camelize(name), String.to_atom(name)], fn k ->
            Map.get(params, k)
          end)
        end

        with :ok <- check_scoped_fields(raw.("fields") || [], resource, ctx),
             :ok <- check_scoped_filter(raw.("filter"), resource, ctx) do
          check_scoped_sort(raw.("sort"), resource, ctx)
        end
    end
  end

  defp check_scoped_fields(fields, resource, ctx) when is_list(fields) do
    Enum.find_value(fields, :ok, fn
      name when is_binary(name) ->
        error_or_nil(check_scoped_name(name, resource, ctx))

      %{} = m ->
        Enum.find_value(m, nil, fn {name, sub} ->
          case check_scoped_name(name, resource, ctx) do
            {:error, _} = e ->
              e

            atom ->
              dest = atom && nested_resource(resource, atom)

              if dest && is_list(sub),
                do: error_or_nil(check_scoped_fields(sub, dest, ctx)),
                else: nil
          end
        end)

      _ ->
        nil
    end)
  end

  defp check_scoped_fields(_other, _resource, _ctx), do: :ok

  defp check_scoped_filter(%{} = filter, resource, ctx) do
    Enum.find_value(filter, :ok, fn {k, v} ->
      with true <- is_binary(k),
           {:error, _} = e <- check_scoped_name(k, resource, ctx) do
        e
      else
        _ -> error_or_nil(check_scoped_filter_value(v, resource, ctx))
      end
    end)
  end

  defp check_scoped_filter(list, resource, ctx) when is_list(list),
    do:
      Enum.find_value(list, :ok, fn f -> error_or_nil(check_scoped_filter(f, resource, ctx)) end)

  defp check_scoped_filter(_other, _resource, _ctx), do: :ok

  defp check_scoped_filter_value(%{} = v, resource, ctx) do
    # `v` is either a nested logical filter or a per-field operator map (operator names are
    # not field names, so only keys that spell a field are checked).
    check_scoped_filter(v, resource, ctx)
  end

  defp check_scoped_filter_value(list, resource, ctx) when is_list(list),
    do: check_scoped_filter(list, resource, ctx)

  defp check_scoped_filter_value(_, _resource, _ctx), do: :ok

  defp check_scoped_sort(sort, resource, ctx) when is_binary(sort) or is_list(sort) do
    sort
    |> List.wrap()
    |> Enum.flat_map(fn
      s when is_binary(s) -> String.split(s, ",")
      _ -> []
    end)
    |> Enum.find_value(:ok, fn raw ->
      name = String.replace(raw, ~r/^(\+\+|--|\+|-)/, "")
      error_or_nil(check_scoped_name(name, resource, ctx))
    end)
  end

  defp check_scoped_sort(_other, _resource, _ctx), do: :ok

  defp error_or_nil({:error, _} = e), do: e
  defp error_or_nil(_), do: nil

  # nil (no verdict), the admitted atom (accepted), or {:error, unknown_field}.
  defp check_scoped_name(name, resource, ctx) when is_binary(name) do
    compat = AshSurface.RuntimeParity.RequestedFields.Compat
    fmt = &AshSurface.FieldName.format/2
    admitted = admitted_atoms(resource)

    mapped =
      compat.original_field_name(compat.resolve_resource(resource, Support.handle()), name)

    # A declared mapping (field_names / typescript_field_names) is a verbatim wire name that wins
    # over every formatter, including when it equals the Config spelling of the field.
    override? = is_atom(mapped) and not is_nil(mapped)

    cond do
      override? ->
        mapped

      atom = Enum.find(admitted, &(fmt.(&1, ctx.scoped) == name)) ->
        atom

      atom = Enum.find(admitted, &(fmt.(&1, ctx.config) == name)) ->
        {:error, {:unknown_field, atom, resource, []}}

      true ->
        nil
    end
  end

  defp check_scoped_name(_name, _resource, _ctx), do: nil

  defp admitted_atoms(resource) do
    case Map.get(Support.resource_lookup(), resource) do
      %Ash.Info.Manifest.Resource{fields: fields, relationships: rels} ->
        for {k, _} <- Map.merge(fields || %{}, rels || %{}), is_atom(k), do: k

      _ ->
        []
    end
  end

  defp nested_resource(resource, atom) do
    cond do
      rel = Ash.Resource.Info.relationship(resource, atom) ->
        rel.destination

      attr = Ash.Resource.Info.attribute(resource, atom) ->
        embedded_module(attr.type)

      true ->
        nil
    end
  rescue
    _ -> nil
  end

  defp embedded_module({:array, t}), do: embedded_module(t)

  defp embedded_module(t) when is_atom(t) and not is_nil(t) do
    if Code.ensure_loaded?(t) and Ash.Resource.Info.resource?(t), do: t
  end

  defp embedded_module(_), do: nil

  defp do_parse_request(params, opts) do
    validation_mode? = Keyword.get(opts, :validation_mode?, false)
    input_formatter = Support.input_field_formatter()

    {input_data, other_params} = Map.pop(params, "input", %{})
    {identity, params_without_identity} = Map.pop(other_params, "identity")

    normalized_other_params =
      FieldFormatter.parse_input_fields(params_without_identity, input_formatter)

    normalized_params =
      normalized_other_params
      |> Map.put(:input, input_data)
      |> Map.put(:identity, identity)

    actor = Keyword.get(opts, :actor)
    tenant = normalized_params[:tenant] || Keyword.get(opts, :tenant)
    context = Keyword.get(opts, :context, %{})

    with {:ok, {domain, resource, action, rpc_action, entrypoint}} <-
           discover_action(normalized_params),
         resource_lookups = Support.resource_lookup(),
         type_index = %{},
         enable_filter? = entrypoint.enable_filter?,
         enable_sort? = entrypoint.enable_sort?,
         load_restrictions = LoadRestrictions.normalize(load_restrictions_of(entrypoint)),
         :ok <-
           validate_required_parameters_for_action_type(
             normalized_params,
             action,
             rpc_action,
             validation_mode?
           ),
         :ok <-
           validate_top_level_query_params(
             normalized_params,
             action,
             rpc_action,
             enable_filter?,
             enable_sort?
           ),
         requested_fields <-
           RequestedFieldsProcessor.atomize_requested_fields(
             normalized_params[:fields] || [],
             resource,
             Support.handle()
           ),
         :ok <- check_scoped_spellings(params, resource),
         {:ok, {select, load, template}} <-
           process_fields_unless_validation_mode(
             resource,
             action.name,
             requested_fields,
             validation_mode?,
             resource_lookups,
             type_index,
             enable_filter?: enable_filter?,
             enable_sort?: enable_sort?,
             load_restrictions: load_restrictions
           ),
         {:ok, input} <-
           parse_action_input(normalized_params, action, resource, resource_lookups, type_index),
         {:ok, get_by} <- parse_get_by(normalized_params, rpc_action, resource, resource_lookups),
         {:ok, pagination} <- parse_pagination(normalized_params) do
      formatted_sort = format_sort_string(normalized_params[:sort], input_formatter)

      exposed_metadata_fields = exposed_metadata_fields(entrypoint, action)

      metadata_enabled? =
        not Enum.empty?(exposed_metadata_fields)

      metadata_fields_param =
        normalized_params[:metadata_fields] || normalized_params["metadata_fields"]

      show_metadata =
        if metadata_enabled? do
          case metadata_fields_param do
            fields when is_list(fields) and fields != [] ->
              requested_fields =
                Enum.map(fields, fn
                  field when is_binary(field) ->
                    # First try to reverse map the original client field name
                    # This handles cases like "meta1" → :meta_1 where the mapping is exact
                    original =
                      Map.get(reverse_metadata_field_mappings(entrypoint), field)

                    if is_nil(original) do
                      internal_name = FieldFormatter.parse_input_field(field, input_formatter)

                      case internal_name do
                        atom when is_atom(atom) ->
                          atom

                        string when is_binary(string) ->
                          try do
                            String.to_existing_atom(string)
                          rescue
                            ArgumentError -> nil
                          end

                        _ ->
                          nil
                      end
                    else
                      original
                    end

                  field when is_atom(field) ->
                    field

                  _ ->
                    nil
                end)
                |> Enum.reject(&is_nil/1)

              Enum.filter(requested_fields, fn field ->
                field in exposed_metadata_fields
              end)

            _ ->
              if action.type in [:create, :update, :destroy] do
                exposed_metadata_fields
              else
                []
              end
          end
        else
          []
        end

      request =
        Request.new(%{
          domain: domain,
          resource: resource,
          action: action,
          rpc_action: rpc_action,
          entrypoint: entrypoint,
          tenant: tenant,
          actor: actor,
          context: context,
          select: select,
          load: load,
          extraction_template: template,
          input: input,
          identity: normalized_params[:identity],
          get_by: get_by,
          filter: normalized_params[:filter],
          sort: formatted_sort,
          pagination: pagination,
          show_metadata: show_metadata,
          resource_lookups: resource_lookups,
          type_index: type_index
        })

      {:ok, request}
    else
      error -> error
    end
  end

  @doc """
  Stage 2: Execute Ash action using the parsed request.

  Builds the appropriate Ash query/changeset and executes it.
  Returns the raw Ash result for further processing.

  @doc \"""
  Stage 3: Filter result fields using the extraction template.

  Applies field selection to the Ash result using the pre-computed template.
  Performance-optimized single-pass filtering.
  For unconstrained maps, returns the normalized result directly.
  Handles metadata extraction for both read and mutation actions.
  If the extraction template is empty for mutation actions (create/update), returns empty data.
  """
  @spec process_result(term(), Request.t()) :: {:ok, term()} | {:error, term()}
  def process_result(ash_result, %Request{} = request) do
    case ash_result do
      {:error, error} ->
        {:error, error}

      result when is_list(result) or is_map(result) or is_tuple(result) ->
        # For mutations with no field selection, use empty data
        # (metadata can still be added on top)
        is_mutation_with_no_fields =
          request.extraction_template == [] and
            request.action.type in [:create, :update, :destroy]

        if is_mutation_with_no_fields and Enum.empty?(request.show_metadata) do
          {:ok, %{}}
        else
          if unconstrained_map_action?(request.action) do
            {:ok, ResultProcessor.normalize_primitive(result)}
          else
            filtered =
              cond do
                is_mutation_with_no_fields ->
                  %{}

                # Plain map data carries no type to dispatch on, so typed map
                # returns are extracted against the declared `action.returns`
                # (otherwise nested arrays/embedded resources come back whole).
                typed_map_return?(request.action) ->
                  ResultProcessor.extract_value(
                    result,
                    request.action.returns,
                    [],
                    request.extraction_template,
                    request.resource_lookups
                  )

                true ->
                  ResultProcessor.process(
                    result,
                    request.extraction_template,
                    get_field_mapping_module(request.action, request.resource),
                    request.resource_lookups,
                    request.type_index
                  )
              end

            filtered_with_metadata = add_metadata(filtered, result, request)

            {:ok, filtered_with_metadata}
          end
        end

      primitive_value ->
        {:ok, ResultProcessor.normalize_primitive(primitive_value)}
    end
  end

  # Determines the module to use for field name mapping based on action return type
  # Returns:
  # - resource module for resource-returning actions
  # - TypedStruct module for typed_struct returns (if it has typescript_field_names/0)
  # - request.resource as fallback for CRUD actions
  defp get_field_mapping_module(action, default_resource) do
    if action.type != :action do
      default_resource
    else
      case Support.action_returns_field_selectable_type?(action) do
        {:ok, type, resource_module} when type in [:resource, :array_of_resource] ->
          resource_module

        {:ok, type, {module, _fields}} when type in [:typed_struct, :array_of_typed_struct] ->
          if Code.ensure_loaded?(module) and
               function_exported?(module, :typescript_field_names, 0),
             do: module,
             else: nil

        _ ->
          default_resource
      end
    end
  end

  @doc """
  Stage 4: Format output for client consumption.

  Applies output field formatting and final response structure.

  The error clause handles failures raised before a `%Request{}` exists (action
  discovery, identity resolution, parameter validation); errors are formatted the
  same way as in `format_output/2` so both paths agree on the response shape. The
  fallback clause formats bare data with no response envelope.
  """
  def format_output(%{success: false, errors: _} = filtered_result) do
    format_output_data(filtered_result, Support.output_field_formatter(), nil)
  end

  def format_output(filtered_result) do
    FieldFormatter.format_output_field_names(filtered_result, Support.output_field_formatter())
  end

  @doc """
  Stage 4: Format output for client consumption with type awareness.

  Applies type-aware output field formatting and final response structure.
  """
  def format_output(filtered_result, %Request{} = request) do
    formatter = Support.output_field_formatter()
    format_output_data(filtered_result, formatter, request)
  end

  defp discover_action(params) do
    case params[:action] do
      nil ->
        {:error, {:missing_required_parameter, :action}}

      "" ->
        {:error, {:missing_required_parameter, :action}}

      action_name when is_binary(action_name) or is_atom(action_name) ->
        case Map.get(Support.entry_table(), to_string(action_name)) do
          nil ->
            {:error, {:action_not_found, action_name}}

          e ->
            action = Support.get_action!(e.resource, e.action)
            augmented = augment_action_with_rpc_settings(action, e, e.resource)
            {:ok, {Ash.Resource.Info.domain(e.resource), e.resource, augmented, e, e}}
        end
    end
  end

  defp load_restrictions_of(%{allowed_loads: allowed}) when not is_nil(allowed),
    do: {:allow, allowed}

  defp load_restrictions_of(%{denied_loads: denied}) when not is_nil(denied), do: {:deny, denied}
  defp load_restrictions_of(_), do: :none

  @doc "Metadata field atoms exposed by an entry (`show_metadata` nil = all, false = none)."
  def exposed_metadata_fields(entry, action) do
    declared = Enum.map(Map.get(action, :metadata) || [], & &1.name)

    case entry.show_metadata do
      nil -> declared
      false -> []
      list when is_list(list) -> list
    end
  end

  defp metadata_field_mappings(entry), do: Map.new(entry.metadata_names || [])

  defp reverse_metadata_field_mappings(entry),
    do: Map.new(metadata_field_mappings(entry), fn {k, v} -> {v, k} end)

  defp augment_action_with_rpc_settings(action, rpc_action, _resource) do
    rpc_get? = Map.get(rpc_action, :get?, false)
    rpc_get_by = Map.get(rpc_action, :get_by) || []

    cond do
      rpc_get? ->
        Map.put(action, :get?, true)

      rpc_get_by != [] ->
        action
        |> Map.put(:get?, true)
        |> Map.put(:rpc_get_by_fields, rpc_get_by)

      true ->
        action
    end
  end

  defp parse_action_input(params, action, resource, resource_lookups, type_index) do
    raw_input = Map.get(params, :input, %{})

    if is_map(raw_input) do
      formatter = Support.input_field_formatter()

      case InputFormatter.format(
             raw_input,
             resource,
             action,
             formatter,
             resource_lookups,
             type_index
           ) do
        {:ok, parsed_input} ->
          converted_input =
            convert_keyword_tuple_inputs(parsed_input, resource, action, resource_lookups)

          {:ok, converted_input}

        {:error, _} = error ->
          error
      end
    else
      {:error, {:invalid_input_format, raw_input}}
    end
  end

  defp convert_keyword_tuple_inputs(input, resource, action, resource_lookups) do
    Enum.reduce(input, %{}, fn {key, value}, acc ->
      type_result = find_input_type(key, resource, action, resource_lookups)

      case type_result do
        {:tuple, constraints} ->
          converted_value = convert_map_to_tuple(value, constraints)
          Map.put(acc, key, converted_value)

        {:keyword, constraints} ->
          converted_value = convert_map_to_keyword(value, constraints)
          Map.put(acc, key, converted_value)

        _ ->
          Map.put(acc, key, value)
      end
    end)
  end

  defp find_input_type(field_name, resource, action, resource_lookups) do
    field_atom =
      cond do
        is_atom(field_name) ->
          field_name

        is_binary(field_name) ->
          try do
            String.to_existing_atom(field_name)
          rescue
            ArgumentError -> nil
          end

        true ->
          nil
      end

    if field_atom do
      case lookup_field_type(resource, field_atom, resource_lookups) do
        nil -> find_action_argument_type(field_atom, action)
        type -> classify_tuple_or_keyword_type(type)
      end
    else
      :other
    end
  end

  defp find_action_argument_type(field_atom, action) do
    case Enum.find(action.inputs, &(&1.name == field_atom)) do
      %{type: %Ash.Info.Manifest.Type{} = type_info} ->
        classify_tuple_or_keyword_type(type_info)

      _ ->
        :other
    end
  end

  # Classifies a manifest type as tuple, keyword, or other, following `:type_ref`
  # references to the named definition in the type lookup.
  defp classify_tuple_or_keyword_type(%Ash.Info.Manifest.Type{kind: :tuple} = type_info) do
    {:tuple, type_info}
  end

  defp classify_tuple_or_keyword_type(%Ash.Info.Manifest.Type{kind: :keyword} = type_info) do
    {:keyword, type_info}
  end

  defp classify_tuple_or_keyword_type(%Ash.Info.Manifest.Type{kind: :type_ref, module: module}) do
    Support.type_lookup()
    |> Ash.Info.Manifest.get_type!(module)
    |> classify_tuple_or_keyword_type()
  end

  defp classify_tuple_or_keyword_type(%Ash.Info.Manifest.Type{}), do: :other

  defp convert_map_to_tuple(value, type_info_or_constraints) when is_map(value) do
    field_order = get_tuple_field_names(type_info_or_constraints)

    tuple_values =
      Enum.map(field_order, fn field_name ->
        atom_key = field_name
        string_key = if is_atom(field_name), do: Atom.to_string(field_name), else: field_name

        # Map.fetch, not ||: a legitimate `false` or `nil` value must not fall
        # through to the other key form.
        case Map.fetch(value, atom_key) do
          {:ok, field_value} -> field_value
          :error -> Map.get(value, string_key)
        end
      end)

    List.to_tuple(tuple_values)
  end

  defp convert_map_to_tuple(value, _type_info_or_constraints), do: value

  defp convert_map_to_keyword(value, type_info_or_constraints) when is_map(value) do
    allowed_fields = get_tuple_field_names(type_info_or_constraints) |> MapSet.new()

    Enum.reduce(value, %{}, fn {key, val}, acc ->
      atom_key =
        cond do
          is_atom(key) ->
            key

          is_binary(key) ->
            try do
              String.to_existing_atom(key)
            rescue
              _ ->
                reraise ArgumentError,
                        "Invalid keyword field: #{inspect(key)}. Allowed fields: #{inspect(MapSet.to_list(allowed_fields))}",
                        __STACKTRACE__
            end

          true ->
            key
        end

      unless MapSet.member?(allowed_fields, atom_key) do
        raise ArgumentError,
              "Invalid keyword field: #{inspect(atom_key)}. Allowed fields: #{inspect(MapSet.to_list(allowed_fields))}"
      end

      Map.put(acc, atom_key, val)
    end)
  end

  defp convert_map_to_keyword(value, _type_info_or_constraints), do: value

  defp get_tuple_field_names(%Ash.Info.Manifest.Type{fields: fields})
       when is_list(fields) and fields != [] do
    Enum.map(fields, & &1.name)
  end

  defp get_tuple_field_names(%Ash.Info.Manifest.Type{element_types: ets})
       when is_list(ets) and ets != [] do
    Enum.map(ets, & &1.name)
  end

  defp get_tuple_field_names(_), do: []

  defp parse_get_by(params, rpc_action, resource, resource_lookups) do
    rpc_get_by = Map.get(rpc_action, :get_by) || []

    if rpc_get_by == [] do
      {:ok, nil}
    else
      raw_get_by = params[:get_by] || %{}

      formatter = Support.input_field_formatter()
      output_formatter = Support.output_field_formatter()
      res_struct = Support.resolve_resource(resource)
      parsed_get_by = FieldFormatter.parse_input_fields(raw_get_by, formatter)

      allowed_fields = MapSet.new(rpc_get_by)
      provided_fields = parsed_get_by |> Map.keys() |> MapSet.new()

      missing_fields = MapSet.difference(allowed_fields, provided_fields) |> MapSet.to_list()
      extra_fields = MapSet.difference(provided_fields, allowed_fields) |> MapSet.to_list()

      cond do
        not Enum.empty?(extra_fields) ->
          formatted_extra =
            Enum.map(extra_fields, &FieldFormatter.format_field_name(&1, output_formatter))

          formatted_allowed =
            Enum.map(
              rpc_get_by,
              &FieldFormatter.format_field_for_client(&1, res_struct, output_formatter)
            )

          {:error, {:unexpected_get_by_fields, formatted_extra, formatted_allowed}}

        not Enum.empty?(missing_fields) ->
          formatted_missing =
            Enum.map(
              missing_fields,
              &FieldFormatter.format_field_for_client(&1, res_struct, output_formatter)
            )

          {:error, {:missing_get_by_fields, formatted_missing}}

        true ->
          validated_get_by =
            Enum.reduce(rpc_get_by, %{}, fn field, acc ->
              value = Map.get(parsed_get_by, field)

              if lookup_field_exists?(resource, field, resource_lookups) do
                Map.put(acc, field, value)
              else
                acc
              end
            end)

          validate_scalar_get_by(validated_get_by)
      end
    end
  end

  # Top-level filter/sort/page must error when explicitly present but unusable
  # (breaking change in 0.18 — previously silently dropped). Absent params never
  # error; `page: %{}` counts as present. Nested envelopes are unaffected: their
  # gating is flags-only and handled in the FieldSelector.
  defp validate_top_level_query_params(params, action, rpc_action, enable_filter?, enable_sort?) do
    ash_get? = action.type == :read and Map.get(action, :get?, false)
    rpc_get? = Map.get(rpc_action, :get?, false)
    rpc_get_by = (Map.get(rpc_action, :get_by) || []) != []
    list_read? = action.type == :read and not (ash_get? or rpc_get? or rpc_get_by)

    with :ok <-
           validate_top_level_param(
             params[:filter],
             list_read?,
             enable_filter?,
             :filter_not_supported
           ),
         :ok <-
           validate_top_level_param(
             params[:sort],
             list_read?,
             enable_sort?,
             :sort_not_supported
           ) do
      validate_top_level_page(params[:page], list_read?, action)
    end
  end

  defp validate_top_level_param(nil, _list_read?, _enabled?, _error), do: :ok

  defp validate_top_level_param(_present, list_read?, enabled?, error) do
    cond do
      not list_read? -> {:error, {error, :top_level, :unsupported}}
      not enabled? -> {:error, {error, :top_level, :disabled}}
      true -> :ok
    end
  end

  defp validate_top_level_page(nil, _list_read?, _action), do: :ok

  defp validate_top_level_page(_present, list_read?, action) do
    if list_read? and Support.action_supports_pagination?(action) do
      :ok
    else
      {:error, {:pagination_not_supported, :top_level, :unsupported}}
    end
  end

  defp parse_pagination(params) do
    case params[:page] do
      nil ->
        {:ok, nil}

      page when is_map(page) ->
        formatter = Support.input_field_formatter()
        parsed_page = FieldFormatter.parse_input_fields(page, formatter)

        case Map.keys(parsed_page) -- @page_keys do
          [] -> {:ok, parsed_page}
          unknown_keys -> {:error, {:unknown_page_keys, Enum.map(unknown_keys, &to_string/1)}}
        end

      invalid ->
        {:error, {:invalid_pagination, invalid}}
    end
  end

  defp scalar_identity_value?(value), do: not (is_map(value) or is_list(value))

  @doc """
  Non-actuating identity resolution (the pure half of the reference's
  `maybe_apply_identity_filter/4`, lane GU-T11 addition).

  For `:update`/`:destroy` requests, validates `request.identity` against the entry's
  `identities` (default `[:_primary_key]`; `[]` = actor-scoped, no identity) and returns the
  equality filter keyword list the executor would apply. No query is built or run.

  Returns `{:ok, filter | nil}`, `{:error, {:missing_identity, map}}` or
  `{:error, {:invalid_identity, map}}`.
  """
  @spec resolve_identity(Request.t()) :: {:ok, keyword() | nil} | {:error, term()}
  def resolve_identity(%Request{action: %{type: type}} = request)
      when type in [:update, :destroy] do
    identities = Map.get(request.entrypoint, :identities) || [:_primary_key]
    resolve_identity(request.resource, request.identity, identities, request.resource_lookups)
  end

  def resolve_identity(%Request{}), do: {:ok, nil}

  defp resolve_identity(_resource, _identity, [], _lookups), do: {:ok, nil}

  defp resolve_identity(resource, identity, identities, lookups) when not is_nil(identity) do
    with {:ok, filter} <- build_identity_filter(resource, identity, identities, lookups),
         :ok <- validate_scalar_identity_filter(filter) do
      {:ok, filter}
    end
  end

  defp resolve_identity(resource, nil, identities, lookups) do
    output_formatter = Support.output_field_formatter()
    res_struct = Support.resolve_resource(resource)

    expected_keys =
      resource
      |> expected_identity_keys(identities, lookups)
      |> Enum.map(&FieldFormatter.format_field_for_client(&1, res_struct, output_formatter))

    {:error, {:missing_identity, %{expected_keys: expected_keys, identities: identities}}}
  end

  defp build_identity_filter(resource, identity, identities, lookups) when is_map(identity) do
    parsed_identity = parse_identity_input(resource, identity, Support.input_field_formatter())

    result =
      Enum.find_value(identities, fn
        :_primary_key ->
          primary_key_attrs = Ash.Info.Manifest.primary_key(lookups, resource)

          if length(primary_key_attrs) > 1 and
               Enum.all?(primary_key_attrs, &Map.has_key?(parsed_identity, &1)) do
            {:ok, primary_key_filter(resource, parsed_identity, lookups)}
          end

        identity_name ->
          identity_info = Ash.Info.Manifest.get_identity(lookups, resource, identity_name)

          if identity_info && Enum.all?(identity_info.keys, &Map.has_key?(parsed_identity, &1)) do
            {:ok, named_identity_filter(identity_info, parsed_identity)}
          end
      end)

    case result do
      {:ok, filter} ->
        {:ok, filter}

      nil ->
        output_formatter = Support.output_field_formatter()
        res_struct = Support.resolve_resource(resource)

        provided_keys =
          parsed_identity
          |> Map.keys()
          |> Enum.map(&FieldFormatter.format_field_name(&1, output_formatter))

        expected_keys =
          resource
          |> expected_identity_keys(identities, lookups)
          |> Enum.map(&FieldFormatter.format_field_for_client(&1, res_struct, output_formatter))

        {:error,
         {:invalid_identity,
          %{provided_keys: provided_keys, expected_keys: expected_keys, identities: identities}}}
    end
  end

  defp build_identity_filter(resource, identity, identities, lookups) do
    if :_primary_key in identities do
      {:ok, primary_key_filter(resource, identity, lookups)}
    else
      {:error,
       {:invalid_identity,
        %{message: "Primary key identity not allowed for this action", identities: identities}}}
    end
  end

  defp expected_identity_keys(resource, identities, lookups) do
    identities
    |> Enum.flat_map(fn
      :_primary_key ->
        Ash.Info.Manifest.primary_key(lookups, resource)

      identity_name ->
        case Ash.Info.Manifest.get_identity(lookups, resource, identity_name) do
          nil -> []
          identity -> identity.keys
        end
    end)
    |> Enum.uniq()
  end

  defp primary_key_filter(resource, primary_key_value, lookups) do
    primary_key_fields = Ash.Info.Manifest.primary_key(lookups, resource)

    if is_map(primary_key_value) do
      Enum.map(primary_key_fields, fn field -> {field, Map.get(primary_key_value, field)} end)
    else
      [{List.first(primary_key_fields), primary_key_value}]
    end
  end

  defp parse_identity_input(resource, identity, formatter) do
    Enum.into(identity, %{}, fn {key, value} ->
      internal_key =
        case Support.original_field_name(Support.resolve_resource(resource), key) do
          nil -> FieldFormatter.parse_input_field(key, formatter)
          original -> original
        end

      {internal_key, value}
    end)
  end

  defp validate_scalar_identity_filter(filter) do
    invalid_keys =
      filter
      |> Enum.reject(fn {_key, value} -> scalar_identity_value?(value) end)
      |> Enum.map(fn {key, _value} -> key end)

    if invalid_keys == [] do
      :ok
    else
      output_formatter = Support.output_field_formatter()

      formatted_keys =
        Enum.map_join(invalid_keys, ", ", &FieldFormatter.format_field_name(&1, output_formatter))

      {:error,
       {:invalid_identity,
        %{
          message:
            "Identity values must be scalar equality operands. Non-scalar value provided for: #{formatted_keys}"
        }}}
    end
  end

  defp named_identity_filter(identity, parsed_identity) do
    Enum.map(identity.keys, fn key ->
      value =
        case Map.fetch(parsed_identity, key) do
          {:ok, value} -> value
          :error -> Map.get(parsed_identity, Atom.to_string(key))
        end

      {key, value}
    end)
  end

  defp validate_scalar_get_by(get_by) do
    invalid_keys =
      get_by
      |> Enum.reject(fn {_key, value} -> scalar_identity_value?(value) end)
      |> Enum.map(fn {key, _value} -> key end)

    if invalid_keys == [] do
      {:ok, get_by}
    else
      output_formatter = Support.output_field_formatter()

      formatted_keys =
        Enum.map_join(invalid_keys, ", ", &FieldFormatter.format_field_name(&1, output_formatter))

      {:error,
       {:invalid_get_by,
        %{
          message:
            "getBy values must be scalar equality operands. Non-scalar value provided for: #{formatted_keys}"
        }}}
    end
  end

  defdelegate format_sort_string(sort, formatter), to: FieldFormatter

  defp format_output_data(%{success: true, data: result_data} = result, formatter, request) do
    {actual_data, metadata} =
      if is_map(result_data) and Map.has_key?(result_data, :data) and
           Map.has_key?(result_data, :metadata) do
        {result_data.data, result_data.metadata}
      else
        {result_data, Map.get(result, :metadata)}
      end

    # Determine how to format the output based on action return type
    formatted_data =
      format_action_output(
        actual_data,
        request.action,
        request.resource,
        formatter,
        request.resource_lookups,
        request.type_index
      )

    base_response = %{
      FieldFormatter.format_field_name("success", formatter) => true,
      FieldFormatter.format_field_name("data", formatter) => formatted_data
    }

    case metadata do
      nil ->
        base_response

      meta when is_map(meta) ->
        # Values were already formatted via ValueFormatter in add_mutation_metadata,
        # so only the top-level metadata keys need to be camelized here.
        formatted_metadata =
          Enum.into(meta, %{}, fn {key, value} ->
            {FieldFormatter.format_field_name(key, formatter), value}
          end)

        Map.put(
          base_response,
          FieldFormatter.format_field_name("metadata", formatter),
          formatted_metadata
        )
    end
  end

  defp format_output_data(%{success: false, errors: errors}, formatter, _request) do
    formatted_errors = Enum.map(errors, &ErrorFormatter.format(&1, formatter))

    %{
      FieldFormatter.format_field_name("success", formatter) => false,
      FieldFormatter.format_field_name("errors", formatter) => formatted_errors
    }
  end

  defp format_output_data(%{success: true}, formatter, _request) do
    %{
      FieldFormatter.format_field_name("success", formatter) => true
    }
  end

  # Formats action output based on action return type
  # - Resource-returning actions use OutputFormatter for full resource field mapping
  # - Composite types (typed maps, typed structs) use ValueFormatter with type constraints
  # - Unconstrained maps are passed through unchanged — the action opted out of
  #   typing, so its keys are the caller's responsibility and must not be renamed
  defp format_action_output(
         data,
         action,
         default_resource,
         formatter,
         resource_lookups,
         type_index
       ) do
    if action.type != :action do
      OutputFormatter.format(
        data,
        default_resource,
        action.name,
        formatter,
        resource_lookups,
        type_index
      )
    else
      case Support.action_returns_field_selectable_type?(action) do
        {:ok, type, resource_module} when type in [:resource, :array_of_resource] ->
          OutputFormatter.format(
            data,
            resource_module,
            action.name,
            formatter,
            resource_lookups,
            type_index
          )

        {:ok, type, _}
        when type in [:typed_map, :array_of_typed_map, :typed_struct, :array_of_typed_struct] ->
          format_generic_action_output(data, action, formatter, resource_lookups, type_index)

        {:ok, type, _} when type in [:unconstrained_map, :array_of_unconstrained_map] ->
          data

        _ ->
          format_generic_action_output(data, action, formatter, resource_lookups, type_index)
      end
    end
  end

  defp format_generic_action_output(data, action, formatter, resource_lookups, type_index) do
    ValueFormatter.format(
      data,
      action.returns,
      [],
      formatter,
      :output,
      resource_lookups,
      type_index
    )
  end

  defp unconstrained_map_action?(action) do
    case Support.action_returns_field_selectable_type?(action) do
      {:ok, type, _} when type in [:unconstrained_map, :array_of_unconstrained_map] -> true
      _ -> false
    end
  end

  defp typed_map_return?(action) do
    case Support.action_returns_field_selectable_type?(action) do
      {:ok, type, _} when type in [:typed_map, :array_of_typed_map] -> true
      _ -> false
    end
  end

  defp validate_required_parameters_for_action_type(params, action, _rpc_action, validation_mode?) do
    needs_fields =
      if validation_mode? do
        false
      else
        case action.type do
          :read ->
            true

          type when type in [:create, :update, :destroy] ->
            false

          :action ->
            case Support.action_returns_field_selectable_type?(action) do
              {:ok, type, _} when type in [:unconstrained_map, :array_of_unconstrained_map] ->
                false

              {:ok, _, _} ->
                true

              _ ->
                false
            end

          _ ->
            false
        end
      end

    validate_fields_if_needed(params, needs_fields)
  end

  # In validation mode with no fields, skip field processing and return empty result
  defp process_fields_unless_validation_mode(
         _resource,
         _action_name,
         [],
         true = _validation_mode?,
         _resource_lookups,
         _type_index,
         _opts
       ) do
    {:ok, {[], [], []}}
  end

  defp process_fields_unless_validation_mode(
         resource,
         action_name,
         requested_fields,
         _validation_mode?,
         _resource_lookups,
         _type_index,
         opts
       ) do
    RequestedFieldsProcessor.process(
      resource,
      action_name,
      requested_fields,
      Support.handle(),
      opts
    )
  end

  defp validate_fields_if_needed(_params, false), do: :ok

  defp validate_fields_if_needed(params, true) do
    fields = params[:fields]

    cond do
      is_nil(fields) ->
        {:error, {:missing_required_parameter, :fields}}

      not is_list(fields) ->
        {:error, {:invalid_fields_type, fields}}

      Enum.empty?(fields) ->
        {:error, {:empty_fields_array, fields}}

      true ->
        :ok
    end
  end

  defp lookup_field_exists?(resource, field_name, resource_lookups) do
    case Ash.Info.Manifest.get_resource(resource_lookups, resource) do
      %Ash.Info.Manifest.Resource{} = r -> Ash.Info.Manifest.Resource.has_field?(r, field_name)
      nil -> false
    end
  end

  defp lookup_field_type(resource, field_name, resource_lookups) do
    case Ash.Info.Manifest.get_field(resource_lookups, resource, field_name) do
      %Ash.Info.Manifest.Field{type: %Ash.Info.Manifest.Type{} = type} -> type
      _ -> nil
    end
  end

  defp add_metadata(filtered_result, original_result, %Request{} = request) do
    if Enum.empty?(request.show_metadata) do
      filtered_result
    else
      case request.action.type do
        :read ->
          add_read_metadata(
            filtered_result,
            original_result,
            request.show_metadata,
            request.entrypoint,
            request.action
          )

        action_type when action_type in [:create, :update, :destroy] ->
          add_mutation_metadata(
            filtered_result,
            original_result,
            request.show_metadata,
            request.entrypoint,
            request.action
          )

        _ ->
          filtered_result
      end
    end
  end

  defp add_read_metadata(filtered_result, original_result, show_metadata, entrypoint, action)
       when is_list(filtered_result) do
    if is_list(original_result) do
      Enum.zip(filtered_result, original_result)
      |> Enum.map(fn {filtered_record, original_record} ->
        do_add_read_metadata(filtered_record, original_record, show_metadata, entrypoint, action)
      end)
    else
      filtered_result
    end
  end

  defp add_read_metadata(filtered_result, original_result, show_metadata, entrypoint, action)
       when is_map(filtered_result) do
    if Map.has_key?(filtered_result, :results) do
      updated_results =
        Enum.zip(filtered_result[:results] || [], original_result.results)
        |> Enum.map(fn {filtered_record, original_record} ->
          do_add_read_metadata(
            filtered_record,
            original_record,
            show_metadata,
            entrypoint,
            action
          )
        end)

      Map.put(filtered_result, :results, updated_results)
    else
      do_add_read_metadata(filtered_result, original_result, show_metadata, entrypoint, action)
    end
  end

  defp add_read_metadata(filtered_result, _original_result, _show_metadata, _entrypoint, _action) do
    filtered_result
  end

  defp do_add_read_metadata(filtered_record, original_record, show_metadata, entrypoint, action)
       when is_map(filtered_record) do
    metadata_map = Map.get(original_record, :__metadata__, %{})
    formatter = Support.output_field_formatter()

    formatted_metadata =
      format_metadata(metadata_map, show_metadata, entrypoint, action, formatter)

    Map.merge(filtered_record, formatted_metadata)
  end

  defp do_add_read_metadata(
         filtered_record,
         _original_record,
         _show_metadata,
         _entrypoint,
         _action
       ) do
    filtered_record
  end

  defp add_mutation_metadata(filtered_result, original_result, show_metadata, entrypoint, action) do
    metadata_map = Map.get(original_result, :__metadata__, %{})
    formatter = Support.output_field_formatter()

    extracted_metadata =
      format_metadata(metadata_map, show_metadata, entrypoint, action, formatter)

    %{data: filtered_result, metadata: extracted_metadata}
  end

  # Extracts the configured metadata fields and formats each value using the
  # metadata field's declared Ash type. This routes through the same
  # type-driven dispatch as attribute/calculation values: typed maps get their
  # nested keys camelized, unconstrained `:map` / `{:array, :map}` metadata
  # passes through unchanged (so caller-provided keys like `_id` survive).
  defp format_metadata(metadata_map, show_metadata, entrypoint, action, formatter) do
    metadata_defs = Map.get(action || %{}, :metadata, []) || []

    Enum.reduce(show_metadata, %{}, fn metadata_field, acc ->
      mapped_field_name =
        case Map.get(metadata_field_mappings(entrypoint), metadata_field) do
          mapped when is_binary(mapped) -> mapped
          _ -> metadata_field
        end

      value = Map.get(metadata_map, metadata_field)
      {type, constraints} = lookup_metadata_type(metadata_defs, metadata_field)
      formatted_value = ValueFormatter.format(value, type, constraints, formatter, :output)
      Map.put(acc, mapped_field_name, formatted_value)
    end)
  end

  defp lookup_metadata_type(metadata_defs, field_name) do
    case Enum.find(metadata_defs, &(&1.name == field_name)) do
      nil -> {nil, []}
      %{type: type} -> {type, []}
    end
  end
end
