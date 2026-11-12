defmodule AshSurface.Resource.TypedQueryFields do
  @moduledoc """
  Verifies a typed query's `fields` selection against the public surface of an
  Ash resource (port of ash_typescript `VerifyTypedQueryFields`).

  A selection is a list of:

    * `name` - public attribute, aggregate, or calculation without required args
    * `{name, [nested]}` - relationship (or nested-capable field) with a nested selection
    * `{name, %{args: map, fields: [nested]}}` - calculation with arguments

  Returns refusals `%{code:, detail:}`; `[]` means admitted.
  """

  @type refusal :: %{code: String.t(), detail: String.t()}

  @spec verify(module(), term()) :: [refusal()]
  def verify(resource, fields), do: check(resource, fields, [], [])

  defp check(_resource, fields, path, _seen) when not is_list(fields) do
    [
      refusal(
        "typed_query_invalid_fields",
        "fields at #{inspect(path)} must be a list, got #{inspect(fields)}"
      )
    ]
  end

  defp check(resource, fields, path, _seen) do
    duplicates = duplicates(fields, path)

    duplicates ++ Enum.flat_map(fields, &check_field(resource, &1, path))
  end

  defp field_name(name) when is_atom(name), do: name
  defp field_name({name, _}) when is_atom(name), do: name
  defp field_name(_), do: nil

  defp check_field(resource, name, path) when is_atom(name),
    do: classify(resource, name, nil, path)

  defp check_field(resource, {name, nested}, path) when is_atom(name),
    do: classify(resource, name, {:nested, nested}, path)

  defp check_field(_resource, other, path) do
    [
      refusal(
        "typed_query_invalid_fields",
        "invalid field entry #{inspect(other)} at path #{inspect(path)}"
      )
    ]
  end

  defp classify(resource, name, selection, path) do
    full = path ++ [name]

    case lookup(resource, name) do
      nil ->
        [
          refusal(
            "typed_query_unknown_field",
            "unknown field #{inspect(name)} at path #{inspect(full)}"
          )
        ]

      {_kind, %{public?: false}} ->
        [
          refusal(
            "typed_query_private_field",
            "field #{inspect(name)} at path #{inspect(full)} is not public"
          )
        ]

      {:relationship, rel} ->
        case selection do
          {:nested, nested} when is_list(nested) and nested != [] ->
            check(rel.destination, nested, full, [])

          _ ->
            [
              refusal(
                "typed_query_requires_nested_fields",
                "relationship #{inspect(name)} at path #{inspect(full)} requires nested field selection"
              )
            ]
        end

      {:calculation, calc} ->
        calculation(calc, selection, full)

      {:attribute, attr} ->
        typed(attr.type, attr.constraints, name, selection, full)

      {_kind, _field} ->
        case selection do
          nil -> []
          _ -> [not_nestable(name, full)]
        end
    end
  end

  defp not_nestable(name, full) do
    refusal(
      "typed_query_field_not_nestable",
      "field #{inspect(name)} at path #{inspect(full)} does not support nested field selection"
    )
  end

  # Type-driven selection for attribute-like values: embedded resources, unions
  # and typed structs / constrained maps need (and only accept) nested selection.
  defp typed(type, constraints, name, selection, full) do
    kind = nested_kind(type, constraints || [])

    case {kind, selection} do
      {nil, nil} ->
        []

      {nil, _} ->
        [not_nestable(name, full)]

      {_, nil} ->
        [
          refusal(
            "typed_query_requires_nested_fields",
            "field #{inspect(name)} of #{kind_label(kind)} type at path #{inspect(full)} requires nested field selection"
          )
        ]

      {kind, {:nested, nested}} ->
        check_kind(kind, nested, full)
    end
  end

  defp kind_label({:resource, _}), do: "embedded resource"
  defp kind_label({:union, _}), do: "union"
  defp kind_label({:fields, _}), do: "typed struct"

  defp check_kind(_kind, nested, full) when not is_list(nested) and not is_map(nested) do
    [
      refusal(
        "typed_query_invalid_fields",
        "invalid nested selection #{inspect(nested)} at path #{inspect(full)}"
      )
    ]
  end

  defp check_kind({:resource, resource}, nested, full) when is_list(nested),
    do: check(resource, nested, full, [])

  defp check_kind({:resource, _}, nested, full),
    do: check_kind({:fields, []}, nested, full)

  defp check_kind({:fields, fields}, nested, full) when is_list(nested) do
    dups = duplicates(nested, full)
    dups ++ Enum.flat_map(nested, &check_struct_field(fields, &1, full))
  end

  defp check_kind({:fields, _}, nested, full) when is_map(nested) do
    [
      refusal(
        "typed_query_invalid_fields",
        "typed struct selection at path #{inspect(full)} must be a list, got #{inspect(nested)}"
      )
    ]
  end

  defp check_kind({:union, members}, nested, full) do
    entries = union_entries(nested)

    names = Enum.map(entries, fn {n, _} -> n end)

    dups =
      names
      |> Enum.frequencies()
      |> Enum.filter(fn {n, c} -> c > 1 and not is_nil(n) end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()
      |> Enum.map(fn n ->
        refusal(
          "typed_query_duplicate_field",
          "duplicate union member #{inspect(n)} at path #{inspect(full)}"
        )
      end)

    empty =
      if entries == [],
        do: [
          refusal(
            "typed_query_invalid_fields",
            "union selection at path #{inspect(full)} must name at least one member"
          )
        ],
        else: []

    empty ++ dups ++ Enum.flat_map(entries, &check_union_member(members, &1, full))
  end

  defp union_entries(map) when is_map(map),
    do: Enum.map(Enum.sort(map), &{elem(&1, 0), {:sel, elem(&1, 1)}})

  defp union_entries(list) when is_list(list) do
    Enum.flat_map(list, fn
      name when is_atom(name) -> [{name, :simple}]
      {name, sel} when is_atom(name) -> [{name, {:sel, sel}}]
      %{} = map -> union_entries(map)
      other -> [{{:invalid, other}, :invalid}]
    end)
  end

  defp check_union_member(_members, {{:invalid, other}, :invalid}, full) do
    [
      refusal(
        "typed_query_invalid_fields",
        "invalid union member entry #{inspect(other)} at path #{inspect(full)}"
      )
    ]
  end

  defp check_union_member(members, {name, sel}, full) do
    path = full ++ [name]

    case Keyword.fetch(members || [], name) do
      :error ->
        [
          refusal(
            "typed_query_unknown_union_member",
            "unknown union member #{inspect(name)} at path #{inspect(path)}"
          )
        ]

      {:ok, member} ->
        type = Keyword.get(member, :type)
        constraints = Keyword.get(member, :constraints, [])
        selection = if sel == :simple, do: nil, else: {:nested, elem(sel, 1)}
        typed(type, constraints, name, selection, path)
    end
  end

  defp check_struct_field(fields, name, full) when is_atom(name),
    do: struct_field(fields, name, nil, full)

  defp check_struct_field(fields, {name, sel}, full) when is_atom(name),
    do: struct_field(fields, name, {:nested, sel}, full)

  defp check_struct_field(_fields, other, full) do
    [
      refusal(
        "typed_query_invalid_fields",
        "invalid field entry #{inspect(other)} at path #{inspect(full)}"
      )
    ]
  end

  defp struct_field(fields, name, selection, full) do
    path = full ++ [name]

    case Keyword.fetch(fields, name) do
      :error ->
        [
          refusal(
            "typed_query_unknown_field",
            "unknown field #{inspect(name)} at path #{inspect(path)}"
          )
        ]

      {:ok, config} ->
        typed(
          Keyword.get(config, :type),
          Keyword.get(config, :constraints, []),
          name,
          selection,
          path
        )
    end
  end

  defp duplicates(fields, path) do
    fields
    |> Enum.map(&field_name/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {name, count} -> count > 1 and not is_nil(name) end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
    |> Enum.map(fn name ->
      refusal(
        "typed_query_duplicate_field",
        "duplicate field #{inspect(name)} at path #{inspect(path)}"
      )
    end)
  end

  @doc false
  # Classifies how a type is selected: `{:resource, mod}`, `{:union, members}`,
  # `{:fields, keyword}` (typed struct / constrained map), or nil (scalar).
  def nested_kind({:array, inner}, constraints),
    do: nested_kind(inner, Keyword.get(constraints, :items, []))

  def nested_kind(type, constraints) do
    type = Ash.Type.get_type(type)

    cond do
      not is_atom(type) or is_nil(type) ->
        nil

      Ash.Type.NewType.new_type?(type) ->
        nested_kind(
          Ash.Type.NewType.subtype_of(type),
          Ash.Type.NewType.constraints(type, constraints)
        )

      type == Ash.Type.Union ->
        {:union, Keyword.get(constraints, :types, [])}

      type in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Struct] ->
        struct_kind(type, constraints)

      Ash.Resource.Info.resource?(type) ->
        {:resource, type}

      true ->
        nil
    end
  end

  defp struct_kind(type, constraints) do
    instance = Keyword.get(constraints, :instance_of)
    fields = Keyword.get(constraints, :fields)

    cond do
      type == Ash.Type.Struct and is_atom(instance) and not is_nil(instance) and
          Ash.Resource.Info.resource?(instance) ->
        {:resource, instance}

      is_list(fields) ->
        {:fields, fields}

      true ->
        nil
    end
  end

  defp calculation(calc, selection, full) do
    required = Enum.filter(calc.arguments, &(not &1.allow_nil? and is_nil(&1.default)))

    case selection do
      nil when required != [] ->
        [
          refusal(
            "typed_query_calculation_requires_args",
            "calculation #{inspect(calc.name)} at path #{inspect(full)} requires arguments"
          )
        ]

      {:nested, %{} = spec} ->
        args = Map.get(spec, :args, %{})
        given = args |> Map.keys() |> Enum.map(&to_string/1)

        missing =
          required
          |> Enum.reject(&(to_string(&1.name) in given))
          |> Enum.map(fn arg ->
            refusal(
              "typed_query_calculation_requires_args",
              "calculation #{inspect(calc.name)} at path #{inspect(full)} is missing required argument #{inspect(arg.name)}"
            )
          end)

        missing ++ calculation_fields(calc, spec, full)

      {:nested, list} when is_list(list) and list != [] ->
        typed(calc.type, calc.constraints, calc.name, selection, full)

      nil ->
        typed(calc.type, calc.constraints, calc.name, nil, full)

      {:nested, other} when not is_list(other) ->
        [
          refusal(
            "typed_query_invalid_fields",
            "invalid calculation selection #{inspect(other)} at path #{inspect(full)}"
          )
        ]

      _ ->
        []
    end
  end

  defp calculation_fields(calc, spec, full) do
    case Map.fetch(spec, :fields) do
      {:ok, fields} when fields in [[], nil] ->
        typed(calc.type, calc.constraints, calc.name, nil, full)

      {:ok, fields} ->
        typed(calc.type, calc.constraints, calc.name, {:nested, fields}, full)

      :error ->
        typed(calc.type, calc.constraints, calc.name, nil, full)
    end
  end

  defp lookup(resource, name) do
    cond do
      attr = Ash.Resource.Info.attribute(resource, name) -> {:attribute, attr}
      calc = Ash.Resource.Info.calculation(resource, name) -> {:calculation, calc}
      agg = Ash.Resource.Info.aggregate(resource, name) -> {:aggregate, agg}
      rel = Ash.Resource.Info.relationship(resource, name) -> {:relationship, rel}
      true -> nil
    end
  end

  defp refusal(code, detail), do: %{code: code, detail: detail}
end
