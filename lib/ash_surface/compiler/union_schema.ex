# Lane L21 / wave2-un (v26.11.11). Union type parity with ash_typescript: their
# `__type: "Union"` members project to Zod-executable unions.
#
# SHARED CONTRACT: constraint fragments come from `ZodType.fragment/1`
# (frozen ordering, regex emitted as a literal, which ZodGuard admits).
# `render_members/2` is the primary renderer; `render_union_schema/1`
# (tagged `{type, value}` facts) stays as documented API.

defmodule AshSurface.Compiler.UnionSchema do
  @moduledoc """
  Renders Zod union schemas from union type facts.

  ## `render_members/2` (primary, ash_typescript wire form)

  Members are `%{"name", "type", "tag", "tag_value"}` (atom or string keys).
  `type` is a kind string/atom or a full nested definition (`%{"type" =>
  %{"kind" => ..}}`, `%{"kind" => ..}`, arrays via `item_type`/`items`,
  nested unions via `members`). Output:

      z.union([z.object({name: <frag>}).strict(), ...])

  - zero members -> `z.any()`
  - a member with `tag`/`tag_value` adds a literal tag field (default
    storage `:map_with_tag`): `z.object({name: <frag>, <tag>: z.literal(<tag_value>)})`;
    with `storage: :type_and_value` it renders
    `z.object({<discriminator>: z.literal(<tag_value>), value: <frag>})`
  - `ZodGuard` has no `refine`, so "exactly one key" is approximated by a
    union of single-key strict objects.
  - names that are not plain identifiers are quoted.
  - container kinds delegate to `EmbeddedSchema.render/2` when that function
    is exported (guarded `function_exported?/3`), else `z.unknown()`.
  - nesting deeper than `:max_depth` (default 8) -> `{:error, {:union_depth_exceeded, n}}`.

  Options: `:storage`, `:discriminator` (default `"type"`), `:max_depth`.

  ## `render_union_schema/1` (tagged `{type, value}` facts)

  Facts `%{tag, kind, constraints}`: all tagged -> `z.discriminatedUnion`
  over `z.object({<discriminator>: z.literal(tag), value: frag}).strict()`;
  otherwise `z.union`. Every emitted expression passes
  `AshSurface.Projectors.JS.ZodGuard.expression/1` when names/tags are literals
  the guard admits (use `*_admitted/1,2` to prove it).
  """

  alias AshSurface.Compiler.ZodType
  alias AshSurface.Projectors.JS.ZodGuard

  @default_depth 8
  @ident ~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/

  # ---------------------------------------------------------------- members

  @spec render_members(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_members(members, opts \\ [])

  def render_members(members, opts) when is_list(members) do
    do_members(members, opts, 0)
  end

  def render_members(other, _opts), do: {:error, {:union_members_not_a_list, other}}

  @spec render_members_admitted(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_members_admitted(members, opts \\ []) do
    members |> render_members(opts) |> admit()
  end

  defp do_members([], _opts, _depth), do: {:ok, "z.any()"}

  defp do_members(members, opts, depth) do
    max = Keyword.get(opts, :max_depth, @default_depth)

    if depth >= max do
      {:error, {:union_depth_exceeded, depth}}
    else
      with :ok <- check_member_collisions(members) do
        render_each(members, opts, depth)
      end
    end
  end

  # Distinct member names that emit one key would silently drop a member: refuse.
  defp check_member_collisions(members) do
    members
    |> Enum.filter(&(is_map(&1) and is_binary(get(&1, "name"))))
    |> Enum.map(&get(&1, "name"))
    |> Enum.map(&{&1, AshSurface.FieldName.emitted(&1)})
    |> AshSurface.Compiler.EmittedKeys.check(:union)
  end

  defp render_each(members, opts, depth) do
    members
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {m, i}, {:ok, acc} ->
      case member(m, i, opts, depth) do
        {:ok, s} -> {:cont, {:ok, [s | acc]}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, parts} -> {:ok, "z.union([" <> Enum.join(Enum.reverse(parts), ", ") <> "])"}
      error -> error
    end
  end

  defp member(m, index, opts, depth) when is_map(m) do
    name = get(m, "name")
    tag = get(m, "tag")
    tag_value = get(m, "tag_value")

    cond do
      "__proto__" in [name, tag, Keyword.get(opts, :discriminator)] ->
        {:error, {:denied_field_name, "__proto__"}}

      not (is_binary(name) and name != "") ->
        {:error, {:invalid_union_member, m, index}}

      not (is_nil(tag) or (is_binary(tag) and tag != "")) ->
        {:error, {:invalid_union_member, m, index}}

      not (is_nil(tag_value) or is_binary(tag_value) or is_number(tag_value) or
               is_boolean(tag_value)) ->
        {:error, {:invalid_union_member, m, index}}

      true ->
        with {:ok, frag} <- type_fragment(get(m, "type"), opts, depth) do
          object(name, tag, tag_value, frag, opts, m, index)
        end
    end
  end

  defp member(m, index, _opts, _depth), do: {:error, {:invalid_union_member, m, index}}

  defp object(name, nil, nil, frag, opts, m, index) do
    case Keyword.get(opts, :storage, :map_with_tag) do
      :type_and_value ->
        field = discriminator(opts)

        if field == "value" do
          {:error, {:duplicate_member_key, "value", m, index}}
        else
          {:ok, "z.object({#{key(field)}: z.literal(#{lit(name)}), value: #{frag}}).strict()"}
        end

      _ ->
        {:ok, "z.object({#{member_key(name)}: #{frag}}).strict()"}
    end
  end

  defp object(name, tag, tag_value, frag, opts, m, index) do
    value = if is_nil(tag_value), do: name, else: tag_value
    field = tag || discriminator(opts)

    case Keyword.get(opts, :storage, :map_with_tag) do
      :type_and_value ->
        if field == "value" do
          {:error, {:duplicate_member_key, "value", m, index}}
        else
          {:ok, "z.object({#{key(field)}: z.literal(#{lit(value)}), value: #{frag}}).strict()"}
        end

      _ ->
        if field == name do
          {:error, {:duplicate_member_key, name, m, index}}
        else
          {:ok,
           "z.object({#{member_key(name)}: #{frag}, #{key(field)}: z.literal(#{lit(value)})}).strict()"}
        end
    end
  end

  # Member names are field names: the explicitly configured output formatter applies; tags,
  # tag values and the discriminator are protocol literals and never formatted.
  defp member_key(name), do: name |> AshSurface.FieldName.emitted() |> key()

  defp discriminator(opts), do: Keyword.get(opts, :discriminator, "type")

  defp key(name) do
    if Regex.match?(@ident, name) and not String.starts_with?(name, "__"),
      do: name,
      else: Jason.encode!(name)
  end

  defp lit(v), do: Jason.encode!(v)

  # ---------------------------------------------------------- type fragments

  defp type_fragment(nil, _opts, _depth), do: {:ok, "z.unknown()"}

  defp type_fragment(kind, opts, depth) when is_atom(kind) or is_binary(kind),
    do: type_fragment(%{"type" => %{"kind" => to_string(kind)}}, opts, depth)

  defp type_fragment(def, opts, depth) when is_map(def) do
    type = get(def, "type")
    type_map = if is_map(type), do: type, else: %{}
    kind = get(type_map, "kind") || get(def, "kind") || if(is_binary(type), do: type)
    kind = if is_atom(kind) and not is_nil(kind), do: Atom.to_string(kind), else: kind
    nullable? = get(def, "allow_nil?") == true
    constraints = get(def, "constraints") || %{}

    cond do
      kind == "union" ->
        members = get(def, "members") || get(type_map, "members") || []
        with {:ok, f} <- do_members(members, opts, depth + 1), do: {:ok, wrap_null(f, nullable?)}

      kind == "array" ->
        item = get(def, "item_type") || get(type_map, "item_type") || get(type_map, "items")
        item = if is_nil(item), do: get(def, "items"), else: item

        with {:ok, f} <- type_fragment(item, opts, depth + 1),
             do: {:ok, wrap_null("z.array(#{f})", nullable?)}

      kind in ~w(embedded_resource typed_struct typed_map map struct keyword tuple resource) ->
        container(def, type_map, kind, nullable?, opts)

      is_binary(kind) ->
        {:ok,
         ZodType.fragment(%{
           "type" => scalar_type(type_map, def, kind),
           "constraints" => constraints,
           "allow_nil?" => nullable?
         })}

      true ->
        {:ok, "z.unknown()"}
    end
  end

  defp type_fragment(_other, _opts, _depth), do: {:ok, "z.unknown()"}

  # Keep enum values (and any other type-level facts) alongside the kind.
  defp scalar_type(type_map, def, kind) do
    base = if is_map(get(def, "type")), do: type_map, else: %{}

    base =
      if is_nil(get(def, "values")),
        do: base,
        else: Map.put_new(base, "values", get(def, "values"))

    stringify_keys(base) |> Map.put("kind", kind)
  end

  defp stringify_keys(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp container(def, type_map, kind, nullable?, opts) do
    embedded = AshSurface.Compiler.EmbeddedSchema

    if Code.ensure_loaded?(embedded) and function_exported?(embedded, :render, 2) do
      d = Map.put(def, "type", Map.put(type_map, "kind", kind))

      eopts =
        Keyword.take(opts, [:resources, :cycle_depth, :schema_suffix, :non_resources, :max_bytes])

      case embedded.render(d, eopts) do
        {:ok, f} -> {:ok, strip_optional(f) |> wrap_null(nullable?)}
        {:error, _} = e -> e
      end
    else
      {:ok, wrap_null("z.unknown()", nullable?)}
    end
  end

  # Union members are required keys of their wrapper object.
  defp strip_optional(f), do: String.replace_suffix(f, ".optional()", "")

  defp wrap_null(f, true) do
    if String.ends_with?(f, ".nullable()"), do: f, else: f <> ".nullable()"
  end

  defp wrap_null(f, _), do: f

  # ------------------------------------------- tagged {type, value} facts API

  @spec render_union_schema(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_union_schema(facts, opts \\ [])

  def render_union_schema(facts, opts) when is_list(facts) do
    with :ok <- validate_facts(facts),
         :ok <- check_disc(facts, opts),
         do: {:ok, do_render(facts, opts)}
  end

  def render_union_schema(other, _opts), do: {:error, {:union_facts_not_a_list, other}}

  @doc "Renders then proves via `ZodGuard.expression/1` (fail-closed)."
  @spec render_union_schema_admitted(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_union_schema_admitted(facts, opts \\ []) do
    facts |> render_union_schema(opts) |> admit()
  end

  defp admit({:error, _} = e), do: e

  defp admit({:ok, expr}) do
    case ZodGuard.expression(expr) do
      :ok -> {:ok, expr}
      {:error, reason} -> {:error, {:zod_guard_refused, reason}}
    end
  end

  defp validate_facts([]), do: {:error, :union_facts_empty}

  defp validate_facts(facts) do
    case Enum.find_index(facts, &(not fact?(fact(&1)))) do
      nil -> :ok
      index -> {:error, {:invalid_union_fact, Enum.at(facts, index), index}}
    end
  end

  defp check_disc(facts, opts) do
    tags = facts |> Enum.map(&fact/1) |> Enum.map(& &1.tag) |> Enum.filter(&is_binary/1)

    cond do
      discriminator(opts) == "value" and tags != [] ->
        {:error, {:duplicate_member_key, "value"}}

      true ->
        case tags -- Enum.uniq(tags) do
          [] -> :ok
          [dup | _] -> {:error, {:duplicate_tag, dup}}
        end
    end
  end

  defp fact(map) when is_map(map) do
    %{tag: get(map, "tag"), kind: get(map, "kind"), constraints: get(map, "constraints") || %{}}
  end

  defp fact(other), do: other

  defp fact?(%{kind: kind}) when is_atom(kind) and not is_nil(kind), do: true
  defp fact?(_), do: false

  defp do_render(raw_facts, opts) do
    facts = Enum.map(raw_facts, &fact/1)
    disc = discriminator(opts)

    if facts != [] and Enum.all?(facts, &(is_binary(&1.tag) and &1.tag != "")) do
      members =
        Enum.map_join(facts, ", ", fn %{tag: tag} = m ->
          "z.object({#{key(disc)}: z.literal(#{lit(tag)}), value: #{member_fragment(m)}}).strict()"
        end)

      "z.discriminatedUnion(#{lit(disc)}, [#{members}])"
    else
      "z.union([#{Enum.map_join(facts, ", ", &member_fragment/1)}])"
    end
  end

  defp member_fragment(%{kind: kind, constraints: constraints}) do
    ZodType.fragment(%{
      "type" => %{"kind" => Atom.to_string(kind)},
      "constraints" => constraints,
      "allow_nil?" => get(constraints, "allow_nil?") == true
    })
  end

  defp get(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, String.to_existing_atom(key))
      v -> v
    end
  rescue
    ArgumentError -> nil
  end

  defp get(_, _), do: nil
end
