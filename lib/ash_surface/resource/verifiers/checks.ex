defmodule AshSurface.Resource.Verifiers.Checks do
  @moduledoc """
  Resource-level legality checks ported from ash_typescript verifiers
  (`VerifyUniqueInputFieldNames`, `VerifyMapFieldNames`, `VerifyMappableTypes`).
  Called from `AshSurface.Resource.Validator`; each returns refusal maps
  (`%{code:, detail:}`), never raises.
  """

  alias AshSurface.Compiler.{TypeFacts, ZodType}
  alias AshSurface.FieldName.Mapping
  alias AshSurface.Naming

  @doc "All checks for a compiled resource."
  @spec refusals(module()) :: [map()]
  def refusals(resource) do
    input_name_refusals(resource) ++
      invalid_field_name_refusals(resource) ++
      invalid_typed_name_refusals(resource) ++
      map_field_refusals(resource) ++
      unmappable_type_refusals(resource) ++
      AshSurface.Resource.Verifiers.ActionTypeFieldNames.refusals(resource)
  end

  # Port of ash_typescript `VerifyFieldNames`: a public attribute, calculation or aggregate
  # whose name is awkward for a client identifier (`?`, `_<digit>`) must carry a
  # resource-level `field_names` mapping.
  defp invalid_field_name_refusals(resource) do
    mapped = resource |> AshSurface.Resource.Info.field_names() |> safe_map()

    for {kind, items} <- [
          attribute: Ash.Resource.Info.public_attributes(resource),
          calculation: Ash.Resource.Info.public_calculations(resource),
          aggregate: Ash.Resource.Info.public_aggregates(resource)
        ],
        item <- items,
        Naming.invalid_name?(item.name),
        not Map.has_key?(mapped, item.name) do
      refusal(
        "invalid_field_names",
        "Invalid field names found: #{kind} #{inspect(item.name)} cannot be used as a client " <>
          "field name; add `field_names #{item.name}: #{inspect(Naming.make_name_better(item.name))}` " <>
          "to the surface section"
      )
    end
  end

  # Port of ash_typescript `VerifyMapFieldNames`: map / keyword / tuple / struct constraint
  # `fields` and union member names, at any nesting depth (through arrays, unions and
  # NewTypes), must not be awkward unless the NewType's `typescript_field_names/0` remaps them.
  defp invalid_typed_name_refusals(resource) do
    args =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.filter(& &1.public?)
      |> Enum.flat_map(& &1.arguments)
      |> Enum.filter(& &1.public?)

    items =
      Ash.Resource.Info.public_attributes(resource) ++
        Ash.Resource.Info.public_calculations(resource) ++ args

    items
    |> Enum.flat_map(fn item ->
      for bad <- walk_names(item.type, item.constraints || [], %{}, 0),
          do: typed_name_refusal(item, bad)
    end)
    |> Enum.uniq()
  end

  @hint "Create a custom Ash.Type.NewType with a typescript_field_names/0 callback, e.g. " <>
          "`defmodule MyApp.MyCustomType do use Ash.Type.NewType, subtype_of: :map, " <>
          "constraints: [fields: [...]]; def typescript_field_names, do: [field_1: \"field1\"] end`"

  defp typed_name_refusal(item, {:union_member, name}) do
    refusal(
      "invalid_field_names",
      "Invalid union member names found on #{inspect(item.name)}: union member #{inspect(name)} " <>
        "(suggest #{inspect(Naming.make_name_better(name))}). Rename the member."
    )
  end

  defp typed_name_refusal(item, {:field, name}) do
    refusal(
      "invalid_field_names",
      "Invalid field names found in map/keyword/tuple type of #{inspect(item.name)}: " <>
        "#{inspect(name)} (suggest #{inspect(Naming.make_name_better(name))}). #{@hint}"
    )
  end

  @field_types [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Struct, Ash.Type.Tuple]
  @max_depth 16

  defp walk_names(_type, _constraints, _mapped, depth) when depth > @max_depth, do: []

  defp walk_names({:array, inner}, constraints, mapped, depth),
    do: walk_names(inner, Keyword.get(constraints, :items, []) || [], mapped, depth + 1)

  defp walk_names(type, constraints, mapped, depth) when is_atom(type) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.NewType.new_type?(type) ->
        {sub, merged} =
          Ash.Info.Manifest.Generator.TypeResolver.unwrap_new_type(type, constraints)

        walk_names(sub, merged, newtype_mapped(type), depth + 1)

      type in @field_types ->
        fields = Keyword.get(constraints, :fields)

        if is_list(fields) and Keyword.keyword?(fields) do
          Enum.flat_map(fields, fn {name, cfg} ->
            own =
              if Naming.invalid_name?(name) and not Map.has_key?(mapped, name),
                do: [{:field, name}],
                else: []

            own ++
              walk_names(
                Keyword.get(cfg, :type),
                Keyword.get(cfg, :constraints, []) || [],
                %{},
                depth + 1
              )
          end)
        else
          []
        end

      type == Ash.Type.Union ->
        types = Keyword.get(constraints, :types)

        if is_list(types) and Keyword.keyword?(types) do
          Enum.flat_map(types, fn {name, cfg} ->
            own = if Naming.invalid_name?(name), do: [{:union_member, name}], else: []

            own ++
              walk_names(
                Keyword.get(cfg, :type),
                Keyword.get(cfg, :constraints, []) || [],
                %{},
                depth + 1
              )
          end)
        else
          []
        end

      true ->
        []
    end
  end

  defp walk_names(_type, _constraints, _mapped, _depth), do: []

  defp newtype_mapped(module) do
    if function_exported?(module, :typescript_field_names, 0) do
      module.typescript_field_names() |> safe_map()
    else
      %{}
    end
  end

  # Action input names (accepted attributes + arguments) must stay unique once
  # formatted and mapped through `argument_names`.
  defp input_name_refusals(resource) do
    arg_names = AshSurface.Resource.Info.argument_names(resource) |> safe_map()

    resource
    |> Ash.Resource.Info.actions()
    |> Enum.filter(& &1.public?)
    |> Enum.flat_map(fn action ->
      accepted = Map.get(action, :accept) |> List.wrap()
      args = action.arguments |> Enum.filter(& &1.public?) |> Enum.map(& &1.name)
      fields = Enum.uniq(accepted ++ args)
      mapped = arg_names |> Map.get(action.name, []) |> safe_map()

      fields
      |> Enum.group_by(&Mapping.resolve(&1, field_names: mapped))
      |> Enum.filter(fn {_client, atoms} -> length(atoms) > 1 end)
      |> Enum.sort()
      |> Enum.map(fn {client, atoms} ->
        refusal(
          "unique_input_field_names",
          "action #{inspect(action.name)} inputs #{inspect(atoms)} all map to #{inspect(client)}; add argument_names"
        )
      end)
    end)
  end

  # Typed map / keyword / struct constraint `fields` keys must not collide once formatted.
  defp map_field_refusals(resource) do
    resource
    |> typed_fields()
    |> Enum.flat_map(fn {owner, keys} ->
      case Mapping.verify(fields: keys) do
        {:error, {:collision, client, atoms}} ->
          [
            refusal(
              "invalid_map_field_names",
              "#{owner} map fields #{inspect(atoms)} all map to #{inspect(client)}"
            )
          ]

        _ ->
          []
      end
    end)
  end

  defp typed_fields(resource) do
    attrs = Ash.Resource.Info.public_attributes(resource)

    args =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.filter(& &1.public?)
      |> Enum.flat_map(& &1.arguments)
      |> Enum.filter(& &1.public?)

    for item <- attrs ++ args,
        fields = Keyword.get(item.constraints || [], :fields),
        is_list(fields) and fields != [] do
      {inspect(item.name), Enum.map(fields, fn {k, _} -> k end)}
    end
  end

  # Every public attribute/argument/calculation type must map to a Zod kind.
  defp unmappable_type_refusals(resource) do
    items =
      Ash.Resource.Info.public_attributes(resource) ++
        Ash.Resource.Info.public_calculations(resource) ++
        (resource
         |> Ash.Resource.Info.actions()
         |> Enum.filter(& &1.public?)
         |> Enum.flat_map(& &1.arguments)
         |> Enum.filter(& &1.public?))

    for item <- items,
        kinds = unmappable(item),
        kinds != [] do
      refusal(
        "unmappable_type",
        "#{inspect(item.name)} has type #{inspect(item.type)} with unmappable kinds #{inspect(kinds)}; add a zod_mapping_overrides entry"
      )
    end
  end

  @container_kinds ~w(union embedded_resource typed_struct typed_map resource)

  defp unmappable(item) do
    analysis = TypeFacts.analyze(item.type, item.constraints)
    # Container kinds are rendered by EmbeddedSchema / UnionSchema, not the ZodType table.
    Enum.reject(ZodType.unmappable_kinds([analysis.definition]), &(&1 in @container_kinds))
  rescue
    _ -> []
  end

  defp safe_map(nil), do: %{}
  defp safe_map(v) when is_map(v), do: v

  defp safe_map(v) when is_list(v),
    do: if(Keyword.keyword?(v), do: Map.new(v), else: %{})

  defp safe_map(_), do: %{}

  defp refusal(code, detail), do: %{code: code, detail: detail}
end
