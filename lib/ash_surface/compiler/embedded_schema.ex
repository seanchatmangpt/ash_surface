defmodule AshSurface.Compiler.EmbeddedSchema do
  @moduledoc """
  Zod rendering for structured containers: embedded resources, typed structs,
  typed maps, keywords and tuples (port of AshTypescript `SchemaCore`
  typed-container handling, Zod 4 only).

  Input is a string-keyed type definition as serialized by discovery:

      %{"type" => %{"kind" => "embedded_resource" | "typed_struct" | "typed_map" |
                      "map" | "struct" | "keyword" | "tuple" | "resource",
                    "fields" => [%{"name" => "n", "type" => %{...},
                                   "allow_nil?" => bool, "omittable" => bool}],
                    "resource" => "My.Embedded",      # embedded_resource lookup key
                    "instance_of" => "My.Resource"},  # struct/resource reference
        "allow_nil?" => bool, "omittable" => bool}

  Rules:

    * fields present -> `z.object({...}).strict()`; no fields ->
      `z.record(z.string(), z.unknown())`
    * `allow_nil?` -> `.nullable()`, `omittable` -> `.optional()`
    * `instance_of` naming a resource (or kind `resource`) -> INLINED from
      `opts[:resources]` (cycle/byte-cap rules below); a name absent from
      `:resources` degrades to `z.record(z.string(), z.unknown())`
    * an `embedded_resource` without inline fields is resolved through
      `opts[:resources]` (`%{"My.Embedded" => [field, ...]}`); revisiting a
      resource already on the expansion path is a cycle. With no
      `:cycle_depth` option it yields `{:error, {:cyclic_schema, path}}`;
      with `cycle_depth: n` each resource may re-enter `n` times, after
      which the expansion terminates in `z.record(z.string(), z.unknown())`.
      `z.lazy` is never emitted.

  `select: [names]` narrows the TOP-LEVEL container to the named fields (port of
  `build_map_type(fields, selected)`: typed-query field selection); `primitive_fields/2` lists
  the names selectable as plain strings.

  Scalar and nested non-container fields are delegated to
  `AshSurface.Compiler.ZodType.fragment/1`. Output is byte-deterministic:
  list-form fields keep declared order; map-form fields are emitted in
  sorted-by-name order (maps carry no order). Omittability is any of
  `omittable`, `optional`, `required?: false` or `default`, yielding exactly
  one `.optional()`. A `struct` with a non-resource `instance_of` and no
  fields is `z.object({}).strict()`. Atom-keyed field maps are accepted; a
  non-map field yields `{:error, {:invalid_field, field}}`. Output larger than
  `opts[:max_bytes]` (default 1_000_000) yields
  `{:error, {:schema_too_large, bytes, cap}}` (guards `cycle_depth` blowup). `array` with a container item renders
  `z.array(<container>)`; `union` delegates to `UnionSchema.render_members/2`
  when exported. Output is `ZodGuard`-admissible (no bare identifier references; the
  `:schema_suffix` option names the schema constants; default `Config.zod_schema_suffix()`). A struct `instance_of` is a resource reference unless
  the type says `"resource?" => false` or the name is in `opts[:non_resources]`.
  """

  alias AshSurface.Compiler.ZodType

  @containers ~w(embedded_resource typed_struct typed_map map struct keyword tuple)
  @record "z.record(z.string(), z.unknown())"
  @default_max_bytes 1_000_000

  @type result ::
          {:ok, String.t()}
          | {:error,
             {:cyclic_schema, [String.t()]}
             | {:schema_too_large, non_neg_integer(), pos_integer()}
             | {:invalid_field, term()}
             | {:denied_field_name, String.t()}}

  @doc "True when the definition's kind is a structured container handled here."
  @spec container?(map()) :: boolean()
  def container?(%{"type" => %{"kind" => "array"} = type}), do: container_item?(type)

  def container?(%{"type" => %{"kind" => kind}}),
    do: kind in @containers or kind in ["resource", "union"]

  def container?(_), do: false

  defp container_item?(type) do
    case item_definition(type) do
      nil -> false
      item -> container?(item)
    end
  end

  # An array's item may be a bare type map (`%{"kind" => ..}`) or a full definition.
  defp item_definition(%{"items" => %{"type" => %{"kind" => _}} = item}), do: item
  defp item_definition(%{"items" => %{"kind" => _} = item}), do: %{"type" => item}
  defp item_definition(%{"item" => %{"type" => %{"kind" => _}} = item}), do: item
  defp item_definition(%{"item" => %{"kind" => _} = item}), do: %{"type" => item}
  defp item_definition(_), do: nil

  @doc "Renders a container definition. Non-containers delegate to `ZodType.fragment/1`."
  @spec render(map(), keyword()) :: result()
  def render(definition, opts \\ []) when is_map(definition) do
    state = build_state(opts)
    with {:ok, out} <- do_render(definition, state, []), do: cap(out, state)
  end

  @doc """
  Names (wire spelling, as emitted by `render/2`) of the top-level fields of a container
  definition that are selectable as plain strings: scalars, a map/struct/keyword/tuple WITHOUT
  declared subfields, and arrays of those. A field that needs nested selection (embedded
  resource, union, resource reference, container with declared subfields, array of those) is
  not primitive (port of the `__primitiveFields` set of `build_map_type/2`).
  """
  @spec primitive_fields(map(), keyword()) :: [String.t()]
  def primitive_fields(%{"type" => type}, opts \\ []) when is_map(type) do
    state = build_state(opts)
    names = wire_names(type)

    type
    |> fields_of(state)
    |> Enum.map(&rename(&1, names))
    |> Enum.filter(&primitive?(&1, state))
    |> Enum.map(&field_key(&1))
  end

  defp primitive?(%{"type" => %{"kind" => "array"} = type}, state) do
    case item_definition(type) do
      nil -> true
      item -> primitive?(item, state)
    end
  end

  defp primitive?(%{"type" => %{"kind" => kind} = type}, state) do
    cond do
      kind in ["embedded_resource", "union", "resource"] -> false
      kind in @containers -> fields_of(type, state) == []
      true -> true
    end
  end

  defp primitive?(_field, _state), do: true

  defp field_key(%{"wire" => true, "name" => name}), do: to_string(name)
  defp field_key(%{"name" => name}), do: AshSurface.FieldName.emitted(name)

  @doc """
  Renders `definition` as a DECLARATIONS program with exact recursion (F1-refs).

  Resources that are cyclic (reach themselves) or shared (referenced more than once) are
  emitted once as named declarations `<Name><suffix>`; single-use acyclic resources stay
  inline. Inside a declaration, any property whose value mentions a declared identifier is
  a zod 4 getter (`get child() { return Node.optional() }`), so evaluation is lazy and the
  emitted `.mjs` has no declaration-order, TDZ or ReferenceError hazard, and recursion is
  validated exactly at any depth (no `cycle_depth` truncation, which would accept invalid
  data past the cut). Declarations are sorted by identifier (deterministic bytes).

  Returns `{:ok, %{declarations: [{identifier, expr}], expression: expr}}`; every `expr`
  is admitted by `ZodGuard.expression(expr, identifiers: identifiers)` with
  `identifiers = Enum.map(declarations, &elem(&1, 0))`. References reached through a
  `union` stay inline (a cycle through a union is `{:cyclic_schema, _}`).
  """
  @spec render_program(map(), keyword()) ::
          {:ok, %{declarations: [{String.t(), String.t()}], expression: String.t()}}
          | {:error, term()}
  def render_program(definition, opts \\ []) when is_map(definition) do
    state = build_state(opts)

    with {:ok, named} <- plan(definition, state),
         state = %{state | named: named},
         {:ok, decls} <- render_declarations(named, state),
         {:ok, expr} <- do_render(definition, state, []),
         expr = strip_refs(expr),
         :ok <- cap_total([expr | Enum.map(decls, &elem(&1, 1))], state) do
      {:ok, %{declarations: decls, expression: expr}}
    end
  end

  @doc "Source text for a `render_program/2` result: `const X = ...;` per declaration."
  @spec declarations_source(%{declarations: [{String.t(), String.t()}]}) :: String.t()
  def declarations_source(%{declarations: decls}),
    do: Enum.map_join(decls, "", fn {id, expr} -> "const #{id} = #{expr};\n" end)

  @ref_open "\u0001"
  @ref_close "\u0002"

  defp strip_refs(text), do: String.replace(text, [@ref_open, @ref_close], "")

  defp cap_total(exprs, state) do
    bytes = exprs |> Enum.map(&byte_size/1) |> Enum.sum()

    if bytes > state.max_bytes,
      do: {:error, {:schema_too_large, bytes, state.max_bytes}},
      else: :ok
  end

  # name -> identifier for resources that are cyclic or referenced more than once.
  defp plan(definition, state) do
    root = refs(definition, state)
    {reach, counts} = walk(root, state, MapSet.new(), Enum.frequencies(root))

    cyclic =
      Enum.filter(reach, fn name ->
        name in reachable(body_refs(name, state), state, MapSet.new())
      end)

    shared = for {name, n} <- counts, n > 1, do: name
    names = (cyclic ++ shared) |> Enum.uniq() |> Enum.sort()

    pairs = Enum.map(names, &{&1, identifier(&1, state.suffix)})

    case pairs |> Enum.frequencies_by(&elem(&1, 1)) |> Enum.find(fn {_, n} -> n > 1 end) do
      nil -> {:ok, Map.new(pairs)}
      {id, _} -> {:error, {:identifier_collision, id}}
    end
  end

  defp walk([], _state, seen, counts), do: {seen, counts}

  defp walk([name | rest], state, seen, counts) do
    if MapSet.member?(seen, name) do
      walk(rest, state, seen, counts)
    else
      body = body_refs(name, state)
      counts = Enum.reduce(body, counts, fn n, acc -> Map.update(acc, n, 1, &(&1 + 1)) end)
      walk(rest ++ body, state, MapSet.put(seen, name), counts)
    end
  end

  defp reachable([], _state, seen), do: seen

  defp reachable([name | rest], state, seen) do
    if MapSet.member?(seen, name),
      do: reachable(rest, state, seen),
      else: reachable(rest ++ body_refs(name, state), state, MapSet.put(seen, name))
  end

  defp body_refs(name, state) do
    state.resources |> Map.get(name, []) |> normalize() |> Enum.flat_map(&refs(&1, state))
  end

  defp refs(%{"type" => %{"kind" => "array"} = type}, state) do
    case item_definition(type) do
      nil -> []
      item -> refs(item, state)
    end
  end

  defp refs(%{"type" => %{"kind" => kind} = type}, state) do
    cond do
      kind == "union" ->
        []

      kind == "resource" or
          (kind in ["struct", "embedded_resource"] and resource_ref?(type, state)) ->
        ref_name(type, state)

      kind == "embedded_resource" and not match?(%{"fields" => [_ | _]}, type) ->
        ref_name(type, state)

      kind in @containers ->
        type |> fields_of(state) |> Enum.flat_map(&refs(&1, state))

      true ->
        []
    end
  end

  defp refs(_definition, _state), do: []

  defp ref_name(type, state) do
    name = type["instance_of"] || type["resource"]
    if is_binary(name) and Map.has_key?(state.resources, name), do: [name], else: []
  end

  defp identifier(name, suffix) do
    base = String.replace(name, ~r/[^A-Za-z0-9_]/, "_")
    base = if Regex.match?(~r/\A[0-9]/, base), do: "_" <> base, else: base
    base <> suffix
  end

  defp render_declarations(named, state) do
    named
    |> Enum.sort_by(fn {_name, id} -> id end)
    |> Enum.reduce_while({:ok, []}, fn {name, id}, {:ok, acc} ->
      type = %{"kind" => "embedded_resource", "resource" => name}

      case container(type, state, []) do
        {:ok, body} -> {:cont, {:ok, [{id, strip_refs(body)} | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, decls} -> {:ok, Enum.reverse(decls)}
      error -> error
    end
  end

  defp named_ref(type, state) do
    with %{} <- state.named,
         [name] <- ref_name(type, state),
         id when is_binary(id) <- Map.get(state.named, name) do
      {:ok, @ref_open <> id <> @ref_close}
    else
      _ -> :error
    end
  end

  defp build_state(opts) do
    %{
      resources: Keyword.get(opts, :resources, %{}),
      depth: Keyword.get(opts, :cycle_depth),
      suffix: Keyword.get(opts, :schema_suffix) || AshSurface.Config.zod_schema_suffix(),
      non_resources: Keyword.get(opts, :non_resources, []),
      max_bytes: Keyword.get(opts, :max_bytes, @default_max_bytes),
      object_suffix:
        AshSurface.Compiler.ObjectMode.explicit_suffix(Keyword.get(opts, :object_mode)),
      select: opts |> Keyword.get(:select) |> select_names(),
      named: nil
    }
  end

  defp select_names(nil), do: nil
  defp select_names(names) when is_list(names), do: MapSet.new(names, &to_string/1)

  # `select:` narrows the first (top-level) container only; its children render with the
  # selection cleared (nested containers render whole).
  defp selected(fields, %{select: nil}), do: fields

  defp selected(fields, %{select: names}),
    do: Enum.filter(fields, &(is_map(&1) and to_string(&1["name"]) in names))

  defp do_render(%{"type" => %{"kind" => kind} = type} = definition, state, path) do
    cond do
      (kind == "resource" or kind in ["struct", "embedded_resource"]) and
          match?({:ok, _}, named_ref(type, state)) ->
        {:ok, ref} = named_ref(type, state)
        {:ok, wrap(ref, definition)}

      kind == "array" and container_item?(type) ->
        with {:ok, item} <- do_render(item_definition(type), state, path) do
          {:ok, wrap("z.array(#{item})", definition)}
        end

      kind == "union" ->
        render_union(type, definition, state)

      kind == "resource" or
          (kind in ["struct", "embedded_resource"] and resource_ref?(type, state)) ->
        with {:ok, body} <- reference(type, state, path), do: {:ok, wrap(body, definition)}

      kind in @containers ->
        with {:ok, body} <- container(type, state, path), do: {:ok, wrap(body, definition)}

      true ->
        {:ok, wrap_scalar(definition)}
    end
  end

  defp do_render(definition, _state, _path), do: {:ok, ZodType.fragment(definition)}

  defp render_union(type, definition, state) do
    opts = [
      resources: state.resources,
      cycle_depth: state.depth,
      schema_suffix: state.suffix,
      non_resources: state.non_resources,
      max_bytes: state.max_bytes
    ]

    members = if is_map(type), do: Map.get(type, "members") || [], else: []

    case AshSurface.Compiler.UnionSchema.render_members(members, opts) do
      {:ok, body} -> {:ok, wrap(body, definition)}
      other -> other
    end
  end

  defp resource_ref?(%{"fields" => [_ | _]}, _state), do: false
  defp resource_ref?(%{"kind" => "embedded_resource"}, _state), do: false
  defp resource_ref?(%{"resource?" => false}, _state), do: false

  defp resource_ref?(%{"instance_of" => name}, state) when is_binary(name),
    do: name not in state.non_resources

  defp resource_ref?(_, _state), do: false

  # Resource references are inlined from `opts[:resources]` (guard-admissible; the
  # guard refuses bare identifiers). Unknown resources degrade to the record fallback.
  defp reference(type, state, path) do
    name = type["instance_of"] || type["resource"]

    if is_binary(name) and Map.has_key?(state.resources, name) do
      container(%{"kind" => "embedded_resource", "resource" => name}, state, path)
    else
      {:ok, @record}
    end
  end

  defp container(type, state, path) do
    key = type["resource"]

    case type |> fields_of(state) |> selected(state) do
      [] when :erlang.map_get("kind", type) == "struct" and is_map_key(type, "instance_of") ->
        {:ok, "z.object({})" <> state.object_suffix}

      [] ->
        {:ok, @record}

      fields ->
        enter(key, state, path, fn state2, path2 ->
          render_fields(fields, %{state2 | select: nil}, path2, wire_names(type))
        end)
    end
  end

  defp fields_of(%{"fields" => fields}, _state) when is_list(fields) and fields != [],
    do: normalize(fields)

  defp fields_of(%{"fields" => fields}, _state) when is_map(fields) and map_size(fields) > 0,
    do: normalize(fields)

  defp fields_of(%{"kind" => "embedded_resource", "resource" => name}, state)
       when is_binary(name) do
    state.resources |> Map.get(name, []) |> normalize()
  end

  defp fields_of(_type, _state), do: []

  defp normalize(fields) when is_map(fields) do
    fields
    |> Enum.sort_by(fn {name, _} -> to_string(name) end)
    |> Enum.map(fn
      {name, f} when is_map(f) -> f |> stringify() |> Map.put_new("name", to_string(name))
      {_name, f} -> f
    end)
  end

  defp normalize(fields) when is_list(fields),
    do: Enum.map(fields, fn f -> if is_map(f), do: stringify(f), else: f end)

  # Atom keys -> string keys (deep, keys only; values untouched).
  defp stringify(map) when is_map(map) and not is_struct(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), stringify(v)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(other), do: other

  defp cap(out, state) do
    bytes = byte_size(out)

    if bytes > state.max_bytes,
      do: {:error, {:schema_too_large, bytes, state.max_bytes}},
      else: {:ok, out}
  end

  # Cycle tracking: only named (resource-keyed) containers participate.
  defp enter(nil, state, path, fun), do: fun.(state, path)

  defp enter(key, state, path, fun) do
    seen = Enum.count(path, &(&1 == key))

    cond do
      seen == 0 -> fun.(state, path ++ [key])
      state.depth == nil -> {:error, {:cyclic_schema, path ++ [key]}}
      seen > state.depth -> {:ok, @record}
      true -> fun.(state, path ++ [key])
    end
  end

  # Type-level wire names (`"field_names"` on a map/struct/keyword type, from a NewType
  # `typescript_field_names/0` callback): the mapped name is emitted verbatim as the key.
  defp wire_names(%{"field_names" => names}) when is_map(names), do: stringify(names)
  defp wire_names(_type), do: %{}

  defp rename(%{"name" => name} = field, names) when map_size(names) > 0 do
    case Map.fetch(names, to_string(name)) do
      {:ok, mapped} -> field |> Map.put("name", mapped) |> Map.put("wire", true)
      :error -> field
    end
  end

  defp rename(field, _names), do: field

  defp render_fields(fields, state, path, names) do
    with :ok <- check_collisions(fields, names, path) do
      do_render_fields(fields, state, path, names)
    end
  end

  # Distinct field names that emit one key would silently drop a field: refuse (EmittedKeys).
  defp check_collisions(fields, names, path) do
    fields
    |> Enum.map(&rename(&1, names))
    |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, "name")))
    |> Enum.map(fn
      %{"wire" => true, "name" => n} -> {n, to_string(n)}
      %{"name" => n} -> {n, AshSurface.FieldName.emitted(n)}
    end)
    |> AshSurface.Compiler.EmittedKeys.check({:container, Enum.reverse(path)})
  end

  defp do_render_fields(fields, state, path, names) do
    fields
    |> Enum.reduce_while({:ok, []}, fn field, {:ok, acc} ->
      case render_field(rename(field, names), state, path) do
        {:ok, line} -> {:cont, {:ok, [line | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, lines} ->
        cap(
          "z.object({ " <> Enum.join(Enum.reverse(lines), ", ") <> " })" <> state.object_suffix,
          state
        )

      error ->
        error
    end
  end

  defp render_field(field, _state, _path) when not is_map(field),
    do: {:error, {:invalid_field, field}}

  # `__proto__` is refused (ZodGuard denies the key; emitted as a plain object-literal key
  # it would set the prototype instead of defining a property).
  defp render_field(%{"name" => name}, _state, _path) when name in ["__proto__", :__proto__],
    do: {:error, {:denied_field_name, "__proto__"}}

  defp render_field(field, state, path) do
    # `"wire" => true`: the name is final (a `field_names` mapping, verbatim); every other
    # key goes through the explicitly configured output formatter.
    name =
      if field["wire"] == true,
        do: to_string(field["name"]),
        else: AshSurface.FieldName.emitted(field["name"])

    definition = Map.put_new(field, "type", %{"kind" => "unknown"})

    with {:ok, expr} <- do_render(definition, state, path) do
      if state.named != nil and String.contains?(expr, @ref_open),
        do: {:ok, "get #{key(name)}() { return #{expr} }"},
        else: {:ok, "#{key(name)}: #{expr}"}
    end
  end

  # nullable then optional, applied to container bodies only; scalars get
  # `.nullable()` from ZodType.fragment/1 and `.optional()` here.
  defp wrap(body, definition) do
    body
    |> nullable(definition)
    |> optional(definition)
  end

  # ZodType.fragment/1 already appends `.optional()` for "optional", "required?"
  # == false and "default"; "omittable" adds it only when absent (one place).
  defp wrap_scalar(definition) do
    expr = ZodType.fragment(definition)
    if String.ends_with?(expr, ".optional()"), do: expr, else: optional(expr, definition)
  end

  defp nullable(body, %{"allow_nil?" => true}), do: body <> ".nullable()"
  defp nullable(body, _), do: body

  defp optional(body, definition) do
    if omittable?(definition) and not String.ends_with?(body, ".optional()"),
      do: body <> ".optional()",
      else: body
  end

  defp omittable?(definition) do
    definition["omittable"] == true or definition["optional"] == true or
      definition["required?"] == false or Map.has_key?(definition, "default")
  end

  defp key(name) do
    if Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, name) and
         not String.starts_with?(name, "__"),
       do: name,
       else: Jason.encode!(name)
  end
end
