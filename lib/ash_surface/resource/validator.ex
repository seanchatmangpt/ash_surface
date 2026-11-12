defmodule AshSurface.Resource.Validator do
  @moduledoc false

  # Admission law (ontology.ttl: surf:AshSurfaceSpec validate delegate, arity 1,
  # `:ok | {:error, [%{code: _, detail: _}]}`): surface projection metadata is
  # admitted only against the EXACT public action set of the compiled resource.
  #
  # Transport kinds mirror the projection facet one_of in ontology.ttl
  # (surf:TransportAuto/Http/Channel). `:auto` is a projection-side preference
  # meaning "preserve all admitted alternatives"; it is not a runtime transport
  # and therefore does not borrow AshSurface.Transport's runtime list.
  #
  # Offline classes mirror the runtime's offline semantics: `:online_only` (no
  # offline behavior), `:cache_last` (serve last observed state offline),
  # `:queue_reconcile` (queue DO commands offline, reconcile via receipts).
  @admitted_transports [:auto, :http, :phoenix_channel]
  @admitted_offline_classes [:online_only, :cache_last, :queue_reconcile]

  @spec validate(map()) :: :ok | {:error, [map()]}
  def validate(%{surface: entities} = compiled) when is_list(entities) do
    {typed_queries, projections} =
      Enum.split_with(entities, &match?(%AshSurface.Dsl.TypedQuery{}, &1))

    if Enum.all?(projections, &projection_shape?/1) do
      refusals =
        duplicate_refusals(projections) ++
          admission_refusals(compiled, projections) ++
          kind_refusals(projections) ++
          option_refusals(compiled, projections) ++
          typed_query_refusals(compiled, typed_queries) ++
          naming_refusals(compiled)

      if refusals == [], do: :ok, else: {:error, refusals}
    else
      {:error, invalid_compilation("every surface projection must declare an atom :action")}
    end
  end

  def validate(_compiled) do
    {:error,
     invalid_compilation(
       "compiled AshSurface extension state must contain a surface projection list"
     )}
  end

  defp projection_shape?(%{action: action}) when is_atom(action), do: true
  defp projection_shape?(_projection), do: false

  defp duplicate_refusals(projections) do
    projections
    |> Enum.map(& &1.action)
    |> Enum.frequencies()
    |> Enum.filter(fn {_action, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn action ->
      %{
        code: "duplicate_action_projection",
        detail: "surface projection for #{inspect(action)} is declared more than once"
      }
    end)
  end

  # Metadata naming anything outside the resource's exact public action set is
  # refused instead of silently becoming a second application model.
  defp admission_refusals(_compiled, []), do: []

  defp admission_refusals(compiled, projections) do
    case public_action_set(compiled) do
      nil ->
        invalid_compilation(
          "compiled AshSurface extension state must reference the Ash resource whose exact public action set admits every projection"
        )

      public_actions ->
        known = MapSet.new(public_actions)

        resource = Map.get(compiled, :resource)

        projections
        |> Enum.uniq_by(& &1.action)
        |> Enum.reject(&MapSet.member?(known, &1.action))
        |> Enum.sort_by(& &1.action)
        |> Enum.map(fn projection ->
          action = projection.action
          label = inspect(Map.get(projection, :name) || action)

          set = "it is not in the exact public action set #{inspect(Enum.sort(public_actions))}"

          reason =
            if Ash.Resource.Info.action(resource, action),
              do: "action #{inspect(action)} is not `public?` (#{set})",
              else: set

          %{
            code: "unknown_action_projection",
            detail: "surface projection #{label} names #{inspect(action)}: #{reason}"
          }
        end)
    end
  end

  defp public_action_set(%{resource: resource}) do
    if Ash.Resource.Info.resource?(resource) do
      resource
      |> Ash.Resource.Info.public_actions()
      |> Enum.map(& &1.name)
    else
      nil
    end
  end

  defp public_action_set(_compiled), do: nil

  defp kind_refusals(projections) do
    Enum.flat_map(projections, fn projection ->
      kind_refusal(
        projection,
        :transport,
        @admitted_transports,
        "unknown_transport_projection",
        "transport"
      ) ++
        kind_refusal(
          projection,
          :offline,
          @admitted_offline_classes,
          "unknown_offline_class_projection",
          "offline class"
        )
    end)
  end

  defp kind_refusal(projection, field, admitted, code, label) do
    case Map.get(projection, field) do
      nil ->
        []

      kind ->
        if Enum.member?(admitted, kind) do
          []
        else
          [
            %{
              code: code,
              detail:
                "surface projection for #{inspect(projection.action)} declares #{label} #{inspect(kind)}; admitted kinds are " <>
                  inspect(admitted)
            }
          ]
        end
    end
  end

  # Projection option law (zod port lane 12). Options are read with Map.get so a
  # projection struct predating the regenerated DSL fields validates as before.
  defp option_refusals(compiled, projections) do
    resource = Map.get(compiled, :resource)

    resource? =
      is_atom(resource) and not is_nil(resource) and Ash.Resource.Info.resource?(resource)

    duplicate_name_refusals(projections) ++
      Enum.flat_map(projections, &projection_option_refusals(&1, resource, resource?))
  end

  defp duplicate_name_refusals(projections) do
    projections
    |> Enum.map(&Map.get(&1, :name))
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_name, count} -> count > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn name ->
      refusal(
        "duplicate_projection_name",
        "surface projection name #{inspect(name)} is declared more than once"
      )
    end)
  end

  defp projection_option_refusals(projection, resource, resource?) do
    action = projection.action
    get? = Map.get(projection, :get?) == true
    get_by = List.wrap(Map.get(projection, :get_by))
    allowed = Map.get(projection, :allowed_loads)
    denied = Map.get(projection, :denied_loads)

    conflict =
      if get? and get_by != [] do
        [
          refusal(
            "get_and_get_by_conflict",
            "surface projection for #{inspect(action)} declares both get? and get_by"
          )
        ]
      else
        []
      end

    loads =
      if present?(allowed) and present?(denied) do
        [
          refusal(
            "allowed_and_denied_loads_conflict",
            "surface projection for #{inspect(action)} declares both allowed_loads and denied_loads"
          )
        ]
      else
        []
      end

    if resource? do
      conflict ++
        loads ++
        identity_refusals(projection, resource) ++
        load_path_refusals(projection, resource) ++
        relationship_destination_refusals(projection, resource) ++
        get_by_refusals(action, get_by, resource) ++
        read_action_refusals(projection, resource) ++
        metadata_refusals(projection, resource)
    else
      conflict ++ loads
    end
  end

  defp present?(nil), do: false
  defp present?([]), do: false
  defp present?(_), do: true

  # Load-path law (port of ash_typescript VerifyRpc allowed_loads/denied_loads existence check):
  # every entry is a public relationship, calculation or aggregate of the resource; nested
  # selections recurse into the relationship destination or embedded attribute type; plain
  # attributes are never load paths.
  defp load_path_refusals(projection, resource) do
    for key <- [:allowed_loads, :denied_loads],
        loads = Map.get(projection, key),
        present?(loads),
        invalid = invalid_load_paths(loads, resource, []),
        invalid != [] do
      refusal(
        "invalid_load_paths",
        "surface projection for #{inspect(projection.action)}: #{key} contains invalid load paths: " <>
          Enum.map_join(invalid, ", ", &Enum.join(&1, "."))
      )
    end
  end

  defp invalid_load_paths(loads, resource, prefix) do
    loads
    |> List.wrap()
    |> Enum.flat_map(fn
      {name, nested} when is_atom(name) -> check_load(name, List.wrap(nested), resource, prefix)
      name when is_atom(name) -> check_load(name, nil, resource, prefix)
      _other -> [prefix ++ ["?"]]
    end)
  end

  defp check_load(name, nested, resource, prefix) do
    path = prefix ++ [name]

    case load_target(resource, name) do
      :leaf when nested in [nil, []] -> []
      :leaf -> [path]
      {:dest, _dest} when nested in [nil, []] -> []
      {:dest, dest} -> invalid_load_paths(nested, dest, path)
      :unknown -> [path]
    end
  end

  defp load_target(resource, name) do
    cond do
      rel = Ash.Resource.Info.public_relationship(resource, name) -> {:dest, rel.destination}
      Ash.Resource.Info.public_calculation(resource, name) -> :leaf
      Ash.Resource.Info.public_aggregate(resource, name) -> :leaf
      attr = Ash.Resource.Info.public_attribute(resource, name) -> embedded_target(attr)
      true -> :unknown
    end
  end

  defp embedded_target(%{type: type}) do
    inner =
      case type do
        {:array, t} -> t
        t -> t
      end

    if is_atom(inner) and Code.ensure_loaded?(inner) and Ash.Resource.Info.resource?(inner) and
         Ash.Resource.Info.embedded?(inner),
       do: {:dest, inner},
       else: :unknown
  end

  # Port of ash_typescript VerifyRpc relationship-destination law: a public relationship into
  # another surface resource whose primary read action is not `public?` cannot be selected.
  defp relationship_destination_refusals(%{action: action} = projection, resource) do
    case Ash.Resource.Info.action(resource, action) do
      %{type: :read} ->
        for rel <- Ash.Resource.Info.public_relationships(resource),
            AshSurface.Resource in Spark.extensions(rel.destination),
            read = Ash.Resource.Info.primary_action(rel.destination, :read),
            not read.public? do
          refusal(
            "relationship_destination_read_not_public",
            "surface projection for #{inspect(Map.get(projection, :name) || action)}: relationship " <>
              "#{inspect(rel.name)} destination #{inspect(rel.destination)} primary read action " <>
              "#{inspect(read.name)} is not `public?`"
          )
        end

      _ ->
        []
    end
  end

  defp identity_refusals(projection, resource) do
    known = resource |> Ash.Resource.Info.identities() |> Enum.map(& &1.name)
    has_pk? = Ash.Resource.Info.primary_key(resource) != []

    projection
    |> Map.get(:identities)
    |> List.wrap()
    |> Enum.flat_map(fn
      :_primary_key ->
        if has_pk? do
          []
        else
          [
            refusal(
              "unknown_identity_projection",
              "surface projection for #{inspect(projection.action)}: Resource has no primary key, " <>
                "but the :_primary_key identity is configured"
            )
          ]
        end

      identity ->
        if identity in known do
          []
        else
          available =
            if known == [],
              do: "No identities are defined on this resource.",
              else: "Available identities: #{inspect(known)}"

          [
            refusal(
              "unknown_identity_projection",
              "surface projection for #{inspect(projection.action)} names identity #{inspect(identity)}, " <>
                "which is not declared on the resource (Identity not found on resource). #{available}"
            )
          ]
        end
    end)
  end

  defp get_by_refusals(action, get_by, resource) do
    get_by
    |> Enum.reject(fn field ->
      match?(%{public?: true}, Ash.Resource.Info.attribute(resource, field))
    end)
    |> Enum.map(fn field ->
      refusal(
        "get_by_not_public_attribute",
        "surface projection for #{inspect(action)} get_by names #{inspect(field)}, which is not a public attribute"
      )
    end)
  end

  # Metadata option law (F1-meta): show_metadata is nil | false | [] | existing metadata
  # names of the action; metadata_field_names maps existing metadata names to valid,
  # collision-free JS identifiers (AshSurface.FieldName.Mapping, type_names path).
  defp metadata_refusals(projection, resource) do
    action_name = projection.action
    show = Map.get(projection, :show_metadata)
    names = Map.get(projection, :metadata_field_names)

    action = Ash.Resource.Info.action(resource, action_name)
    known = if action, do: action |> Map.get(:metadata, []) |> Enum.map(& &1.name), else: []

    show_refusals =
      cond do
        show in [nil, false, []] ->
          []

        is_list(show) ->
          case Enum.reject(show, &(is_atom(&1) and &1 in known)) do
            [] ->
              []

            bad ->
              [
                refusal(
                  "unknown_show_metadata",
                  "surface projection for #{inspect(Map.get(projection, :name) || action_name)}: show_metadata contains unknown metadata fields #{inspect(bad)}, not metadata of the action #{inspect(action_name)} (known: #{inspect(known)})"
                )
              ]
          end

        true ->
          [
            refusal(
              "invalid_show_metadata",
              "surface projection for #{inspect(action_name)} show_metadata must be nil, false or a list of metadata names, got #{inspect(show)}"
            )
          ]
      end

    show_refusals ++
      metadata_name_refusals(action_name, names, known) ++
      metadata_wire_refusals(action_name, show, names, resource)
  end

  # Wire-name law for shown metadata (port of ash_typescript VerifyMetadataFieldNames): a shown
  # metadata field's wire name (its metadata_field_names mapping or itself) must be a valid client
  # identifier and must not collide with a public resource field's wire name.
  defp metadata_wire_refusals(action, show, names, resource) when is_list(show) and show != [] do
    mapping = if names, do: Map.new(names), else: %{}

    resource_wires =
      [
        Ash.Resource.Info.public_attributes(resource),
        Ash.Resource.Info.public_calculations(resource),
        Ash.Resource.Info.public_aggregates(resource),
        Ash.Resource.Info.public_relationships(resource)
      ]
      |> Enum.concat()
      |> Enum.map(& &1.name)
      |> then(fn fields ->
        renames = safe_map(AshSurface.Resource.Info.field_names(resource))
        Enum.map(fields, &to_string(Map.get(renames, &1, &1)))
      end)

    show
    |> Enum.filter(&is_atom/1)
    |> Enum.flat_map(fn meta ->
      mapped? = Map.has_key?(mapping, meta)
      wire = to_string(Map.get(mapping, meta, meta))

      cond do
        AshSurface.Naming.invalid_name?(wire) ->
          [
            refusal(
              "invalid_metadata_field_names",
              "surface projection for #{inspect(action)}: Invalid metadata field name #{inspect(meta)}" <>
                if(mapped?,
                  do: " (mapped to #{inspect(wire)}, which is still invalid)",
                  else:
                    " (suggest #{inspect(AshSurface.Naming.make_name_better(meta))}; add metadata_field_names)"
                )
            )
          ]

        wire in resource_wires ->
          [
            refusal(
              "invalid_metadata_field_names",
              "surface projection for #{inspect(action)}: " <>
                if(mapped?,
                  do:
                    "Mapped metadata field conflicts with resource field: #{inspect(meta)} => #{inspect(wire)}",
                  else: "Metadata field conflicts with resource field: #{inspect(meta)}"
                )
            )
          ]

        true ->
          []
      end
    end)
  end

  defp metadata_wire_refusals(_action, _show, _names, _resource), do: []

  defp safe_map(m) when is_map(m), do: m
  defp safe_map(m) when is_list(m), do: if(Keyword.keyword?(m), do: Map.new(m), else: %{})
  defp safe_map(_), do: %{}

  defp metadata_name_refusals(_action, nil, _known), do: []

  defp metadata_name_refusals(action, names, known) do
    if Keyword.keyword?(names) or is_map(names) do
      pairs = Enum.to_list(names)

      case AshSurface.FieldName.Mapping.verify(
             fields: known,
             type_names: Map.new(pairs)
           ) do
        :ok ->
          []

        {:error, reason} ->
          [
            refusal(
              "invalid_metadata_field_names",
              "surface projection for #{inspect(action)} metadata_field_names refused: #{inspect(reason)}"
            )
          ]
      end
    else
      [
        refusal(
          "invalid_metadata_field_names",
          "surface projection for #{inspect(action)} metadata_field_names must be a keyword list or map, got #{inspect(names)}"
        )
      ]
    end
  end

  defp read_action_refusals(projection, resource) do
    case Map.get(projection, :read_action) do
      nil ->
        []

      name ->
        case Ash.Resource.Info.action(resource, name) do
          %{type: :read, public?: true} ->
            []

          _ ->
            [
              refusal(
                "read_action_not_public_read",
                "surface projection for #{inspect(projection.action)} names read_action #{inspect(name)}, which is not `public?` (read_action must be a public read action)"
              )
            ]
        end
    end
  end

  # Typed query law (zod port wave3-09): name, action and fields admission.
  @valid_name ~r/^[a-z][a-z0-9_]*$/

  defp typed_query_refusals(_compiled, []), do: []

  defp typed_query_refusals(compiled, typed_queries) do
    resource = Map.get(compiled, :resource)

    resource? =
      is_atom(resource) and not is_nil(resource) and Ash.Resource.Info.resource?(resource)

    name_refusals(typed_queries) ++
      if resource? do
        Enum.flat_map(typed_queries, &typed_query_resource_refusals(&1, resource))
      else
        []
      end
  end

  defp name_refusals(typed_queries) do
    names = Enum.map(typed_queries, & &1.name)

    invalid =
      names
      |> Enum.uniq()
      |> Enum.reject(&(is_atom(&1) and Regex.match?(@valid_name, Atom.to_string(&1))))
      |> Enum.map(fn name ->
        refusal(
          "typed_query_invalid_name",
          "typed query name #{inspect(name)} must be a lowercase identifier matching #{inspect(@valid_name.source)}"
        )
      end)

    duplicates =
      names
      |> Enum.frequencies()
      |> Enum.filter(fn {_name, count} -> count > 1 end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()
      |> Enum.map(fn name ->
        refusal(
          "typed_query_duplicate_name",
          "typed query name #{inspect(name)} is declared more than once"
        )
      end)

    invalid ++ duplicates
  end

  defp typed_query_resource_refusals(query, resource) do
    case Ash.Resource.Info.action(resource, query.action) do
      %{public?: true, type: :read} ->
        AshSurface.Resource.TypedQueryFields.verify(resource, query.fields)

      %{public?: true, type: type} ->
        [
          refusal(
            "typed_query_non_read_action",
            "typed query #{inspect(query.name)} names action #{inspect(query.action)} of type #{inspect(type)}; only read actions are admitted"
          )
        ]

      other ->
        [
          refusal(
            "typed_query_unknown_action",
            "typed query #{inspect(query.name)} names action #{inspect(query.action)}, which is " <>
              if(other, do: "not `public?`", else: "not a public action of the resource")
          )
        ]
    end
  end

  # Resource-level naming options (type_name / namespace / field_names /
  # argument_names). Mapping errors are verifier refusals, never raises.
  defp naming_refusals(%{resource: resource}) when is_atom(resource) and not is_nil(resource) do
    if Ash.Resource.Info.resource?(resource) do
      type_name_refusals(resource) ++
        field_name_refusals(resource) ++
        argument_name_refusals(resource) ++
        AshSurface.Resource.Verifiers.Checks.refusals(resource)
    else
      []
    end
  end

  defp naming_refusals(_compiled), do: []

  defp type_name_refusals(resource) do
    case AshSurface.Resource.Info.type_name(resource) do
      nil -> []
      name -> identifier_refusal("invalid_type_name", "type_name", name)
    end
  end

  defp identifier_refusal(code, label, value) do
    if is_binary(value) and AshSurface.Naming.identifier?(value) do
      []
    else
      [refusal(code, "#{label} #{inspect(value)} must be a string usable as an identifier")]
    end
  end

  defp field_name_refusals(resource) do
    case AshSurface.Resource.Info.field_names(resource) do
      nil ->
        []

      names ->
        with {:ok, map} <- keyword_map(names, "field_names"),
             {:error, reason} <-
               AshSurface.FieldName.Mapping.build(
                 fields: public_field_names(resource),
                 field_names: map
               ) do
          [mapping_refusal("invalid_field_names", "field_names", reason)]
        else
          {:invalid, detail} -> [refusal("invalid_field_names", detail)]
          _ok -> []
        end
    end
  end

  defp argument_name_refusals(resource) do
    case AshSurface.Resource.Info.argument_names(resource) do
      nil ->
        []

      names when is_list(names) or is_map(names) ->
        names
        |> Enum.sort()
        |> Enum.flat_map(fn
          {action_name, arg_names} -> action_argument_refusals(resource, action_name, arg_names)
          other -> [refusal("invalid_argument_names", "invalid entry #{inspect(other)}")]
        end)

      other ->
        [
          refusal(
            "invalid_argument_names",
            "argument_names must be a keyword, got #{inspect(other)}"
          )
        ]
    end
  end

  defp action_argument_refusals(resource, action_name, arg_names) do
    action = is_atom(action_name) && Ash.Resource.Info.action(resource, action_name)

    with %{} <- action,
         {:ok, map} <- keyword_map(arg_names, "argument_names[#{inspect(action_name)}]"),
         {:error, reason} <-
           AshSurface.FieldName.Mapping.verify_names(map, Enum.map(action.arguments, & &1.name)) do
      [
        mapping_refusal(
          "invalid_argument_names",
          "argument_names[#{inspect(action_name)}]",
          reason
        )
      ]
    else
      nil -> [unknown_action_names(action_name)]
      false -> [unknown_action_names(action_name)]
      {:invalid, detail} -> [refusal("invalid_argument_names", detail)]
      _ok -> []
    end
  end

  defp unknown_action_names(action_name) do
    refusal(
      "invalid_argument_names",
      "argument_names names action #{inspect(action_name)}, which does not exist on the resource"
    )
  end

  defp keyword_map(value, label) when is_map(value) or is_list(value) do
    if Enum.all?(value, &match?({k, _} when is_atom(k), &1)) do
      {:ok, Map.new(value)}
    else
      {:invalid, "#{label} must be a keyword of atom keys, got #{inspect(value)}"}
    end
  end

  defp keyword_map(value, label),
    do: {:invalid, "#{label} must be a keyword of atom keys, got #{inspect(value)}"}

  defp public_field_names(resource) do
    Enum.map(Ash.Resource.Info.public_attributes(resource), & &1.name) ++
      Enum.map(Ash.Resource.Info.public_calculations(resource), & &1.name) ++
      Enum.map(Ash.Resource.Info.public_aggregates(resource), & &1.name)
  end

  defp mapping_refusal(code, label, reason),
    do: refusal(code, "#{label}: #{inspect(reason)}")

  defp refusal(code, detail), do: %{code: code, detail: detail}

  defp invalid_compilation(detail) do
    [%{code: "invalid_surface_compilation", detail: detail}]
  end
end
