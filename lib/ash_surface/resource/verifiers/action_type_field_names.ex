defmodule AshSurface.Resource.Verifiers.ActionTypeFieldNames do
  @moduledoc """
  Port of ash_typescript `VerifyActionTypes`: field names inside the return type
  of every public generic action and inside every public action argument type
  must be client-safe (`AshSurface.Naming.invalid_name?/1` false) unless a
  mapping covers them.

  Walks raw Ash types (no manifest): `:map`/`:keyword`/`:tuple`/`:struct` `fields`
  constraints, `:union` members, arrays, `Ash.Type.NewType` subtypes (and their
  `typescript_field_names/0` callback), custom composite types
  (`composite_types/1`), `typed_struct_fields/0` structs, embedded resources and
  resource references (mapped through the target resource's `field_names`).

  Returns refusal maps `%{code: "invalid_action_type_field_names", detail: _}`.
  """

  alias AshSurface.Naming

  @code "invalid_action_type_field_names"

  @spec refusals(module()) :: [map()]
  def refusals(resource) do
    errors =
      resource
      |> Ash.Resource.Info.actions()
      |> Enum.filter(& &1.public?)
      |> Enum.flat_map(&action_errors/1)

    errors
    |> Enum.group_by(fn {context, _kind, _name} -> context end)
    |> Enum.sort()
    |> Enum.map(fn {context, entries} ->
      lines =
        Enum.map_join(entries, "\n", fn {_c, kind, name} ->
          "    - #{kind} #{name} -> #{Naming.make_name_better(name)}"
        end)

      %{code: @code, detail: "invalid field names in #{context}:\n#{lines}"}
    end)
  end

  defp action_errors(action) do
    returns =
      case action do
        %{type: :action, returns: type} when not is_nil(type) ->
          walk(
            type,
            Map.get(action, :constraints) || [],
            "return type of action #{action.name}",
            %{}
          )

        _ ->
          []
      end

    args =
      Enum.flat_map(action.arguments, fn arg ->
        if arg.public? do
          walk(
            arg.type,
            arg.constraints || [],
            "argument #{arg.name} of action #{action.name}",
            %{}
          )
        else
          []
        end
      end)

    returns ++ args
  end

  # --- type walking -------------------------------------------------------

  defp walk(nil, _c, _ctx, _v), do: []

  defp walk({:array, inner}, c, ctx, v), do: walk(inner, Keyword.get(c || [], :items, []), ctx, v)

  defp walk(type, c, ctx, v) do
    mod = Ash.Type.get_type(type)
    c = c || []

    cond do
      is_atom(mod) and Map.has_key?(v, {mod, c}) ->
        []

      mod == Ash.Type.Union ->
        union(c, ctx, v)

      is_atom(mod) and Ash.Type.NewType.new_type?(mod) ->
        new_type(mod, c, ctx, Map.put(v, {mod, c}, true))

      mod in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple] ->
        field_list(Keyword.get(c, :fields, []), %{}, :field, ctx, v)

      mod == Ash.Type.Struct ->
        struct_type(c, ctx, v)

      is_atom(mod) and Ash.Resource.Info.resource?(mod) ->
        resource_fields(mod, :embedded_field, ctx, Map.put(v, {mod, c}, true))

      is_atom(mod) and composite?(mod, c) ->
        composite(mod, c, ctx, Map.put(v, {mod, c}, true))

      is_atom(mod) and exported?(mod, :typed_struct_fields, 0) ->
        typed_struct(mod, ctx, Map.put(v, {mod, c}, true))

      true ->
        []
    end
  end

  defp union(c, ctx, v) do
    c
    |> Keyword.get(:types, [])
    |> Enum.flat_map(fn {_name, cfg} ->
      walk(Keyword.get(cfg, :type), Keyword.get(cfg, :constraints, []), ctx, v)
    end)
  end

  defp new_type(mod, c, ctx, v) do
    mappings = mappings(mod)
    sub = mod.subtype_of()
    sub_c = Keyword.merge(mod.subtype_constraints() || [], c)

    case Ash.Type.get_type(sub) do
      Ash.Type.Struct ->
        case Keyword.get(sub_c, :instance_of) do
          inst when is_atom(inst) and not is_nil(inst) ->
            if Ash.Resource.Info.resource?(inst) do
              resource_fields(inst, :resource_field, ctx, v)
            else
              field_list(Keyword.get(sub_c, :fields, []), mappings, :struct_field, ctx, v)
            end

          _ ->
            field_list(Keyword.get(sub_c, :fields, []), mappings, :struct_field, ctx, v)
        end

      s when s in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple] ->
        field_list(Keyword.get(sub_c, :fields, []), mappings, :field, ctx, v)

      _ ->
        walk(sub, sub_c, ctx, v)
    end
  end

  defp struct_type(c, ctx, v) do
    inst = Keyword.get(c, :instance_of)

    cond do
      Keyword.get(c, :fields, []) != [] ->
        field_list(Keyword.get(c, :fields), mappings(inst), :struct_field, ctx, v)

      is_atom(inst) and not is_nil(inst) and Ash.Resource.Info.resource?(inst) ->
        if Map.has_key?(v, {inst, :resource}),
          do: [],
          else: resource_fields(inst, :resource_field, ctx, Map.put(v, {inst, :resource}, true))

      is_atom(inst) and not is_nil(inst) and Ash.Type.NewType.new_type?(inst) ->
        walk(inst, [], ctx, v)

      is_atom(inst) and not is_nil(inst) and exported?(inst, :typed_struct_fields, 0) ->
        typed_struct(inst, ctx, v)

      true ->
        []
    end
  end

  defp field_list(fields, mappings, kind, ctx, v) do
    Enum.flat_map(fields || [], fn {name, cfg} ->
      own =
        if invalid?(Map.get(mappings, name, name)), do: [{ctx, kind, name}], else: []

      own ++ walk(Keyword.get(cfg, :type), Keyword.get(cfg, :constraints, []), ctx, v)
    end)
  end

  defp typed_struct(mod, ctx, v) do
    mappings = mappings(mod)

    Enum.flat_map(mod.typed_struct_fields(), fn {name, opts} ->
      own =
        if invalid?(Map.get(mappings, name, name)),
          do: [{ctx, :typed_struct_field, name}],
          else: []

      own ++ walk(Keyword.get(opts, :type), Keyword.get(opts, :constraints, []), ctx, v)
    end)
  end

  defp composite?(mod, c) do
    exported?(mod, :composite?, 1) and mod.composite?(c)
  rescue
    _ -> false
  end

  defp composite(mod, c, ctx, v) do
    mappings = mappings(mod)

    fields = if exported?(mod, :composite_types, 1), do: mod.composite_types(c), else: []

    Enum.flat_map(fields, fn
      {name, storage, type, fc} when is_atom(storage) ->
        composite_field(name, type, fc, mappings, ctx, v)

      {name, type, fc} ->
        composite_field(name, type, fc, mappings, ctx, v)
    end)
  end

  defp composite_field(name, type, fc, mappings, ctx, v) do
    own =
      if invalid?(Map.get(mappings, name, name)), do: [{ctx, :composite_field, name}], else: []

    own ++ walk(type, fc, ctx, v)
  end

  defp resource_fields(mod, kind, ctx, v) do
    mappings = resource_mappings(mod)

    calcs = Enum.filter(Ash.Resource.Info.public_calculations(mod), &Map.get(&1, :field?, true))
    typed = Ash.Resource.Info.public_attributes(mod) ++ calcs

    typed_errors =
      Enum.flat_map(typed, fn f ->
        own = if invalid?(Map.get(mappings, f.name, f.name)), do: [{ctx, kind, f.name}], else: []
        own ++ walk(f.type, f.constraints || [], ctx, v)
      end)

    other =
      (Ash.Resource.Info.public_aggregates(mod) ++ Ash.Resource.Info.public_relationships(mod))
      |> Enum.flat_map(fn f ->
        if invalid?(Map.get(mappings, f.name, f.name)), do: [{ctx, kind, f.name}], else: []
      end)

    typed_errors ++ other
  end

  defp resource_mappings(mod) do
    if AshSurface.Resource in Spark.extensions(mod) do
      case AshSurface.Resource.Info.field_names(mod) do
        nil -> %{}
        names -> Map.new(names)
      end
    else
      %{}
    end
  rescue
    _ -> %{}
  end

  defp mappings(mod) when is_atom(mod) and not is_nil(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :typescript_field_names, 0),
      do: Map.new(mod.typescript_field_names()),
      else: %{}
  end

  defp mappings(_), do: %{}

  defp exported?(mod, fun, arity),
    do: Code.ensure_loaded?(mod) and function_exported?(mod, fun, arity)

  defp invalid?(name) when is_binary(name), do: Naming.invalid_name?(name)
  defp invalid?(name), do: Naming.invalid_name?(name)
end
