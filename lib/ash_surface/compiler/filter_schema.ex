defmodule AshSurface.Compiler.FilterSchema do
  @moduledoc """
  Runtime-admission zod catalog of typed filter operators (the
  ash_typescript typed-filter surface ported to a rendered expression).

  A PURE string renderer, same contract as `AshSurface.Compiler.QuerySchema`:
  it emits a zod expression (a `z`-rooted member/call chain over literals)
  suitable for embedding behind `AshSurface.Projectors.JS.ZodGuard`, and
  returns `{:ok, binary} | {:error, term()}`. No discovery, no Ash
  introspection, no validation beyond its own inputs.

  ## Shape

  Given an action's inputs (IR-shaped entries with `name`/`type`, string-
  or atom-keyed as `AshSurface.Compiler.Schema` accepts them), fields are
  grouped by type kind and each group renders one union member per operator:

      z.union([
        z.object({field: z.enum(["name", "email"]), op: z.literal("contains"), value: z.string()}),
        ...
      ])

  ## Why `z.union`, not `z.discriminatedUnion("op", ...)` (executed finding, wave2-fl)

  Zod 4 builds the discriminator map lazily and throws
  `Duplicate discriminator value "eq"` at the first `safeParse` when two
  members share an `op` literal. This catalog repeats `op` literals across
  kinds (string `eq` vs integer `eq`) and across nesting levels, so a
  discriminated union is unusable; plain `z.union` is correct (first
  matching member wins; members are mutually exclusive by `field`/`op`/`value`).

  Operator catalog per kind (ash_typescript typed-filter operators):

  - string  → eq, neq, gt, gte, lt, lte, contains, starts_with, ends_with, in
  - ci_string → the string operators
  - integer / float / decimal → eq, neq, gt, gte, lt, lte, in
  - date / time / utc_datetime / utc_datetime_usec / datetime / naive_datetime /
    atom → eq, neq, gt, gte, lt, lte, in
  - boolean → eq, neq, in
  - uuid    → eq, neq, in
  - array   → has (element), has_any (array of elements), eq (whole array), in (array of arrays)
  - unknown kinds → eq, neq, in with `value: z.unknown()`

  An input may carry its own operator set under `"operators"` (strings or
  atoms); when present it replaces the catalog default for that field.
  `is_nil` (`value: z.boolean()`) is added when the input is nullable
  (`"allow_nil?" => true`) or lists it explicitly.

  Logical wrappers: `and` / `or` take `z.array(inner)`, `not` takes a SINGLE
  `inner` filter (ash_typescript's `not` is an array of filters; this surface
  is a tagged tree, so `not` negates one node and `[a, b]` is expressed as
  `not(and([a, b]))`). Pre-expanded to `max_depth` (default 2, cap 3) — no
  `z.lazy`, the guard has none. Expansion is geometric (about 3 wrapper copies of the whole inner union per
  level; measured 5-7x bytes per level on a 10-field set), hence the cap.

  Options (`render_filter_schema/2`): `connectives:` (subset of
  `["and", "or", "not"]`, from `filter_capabilities.boolean_connectives`),
  `max_depth:` (0..3).

  Entry facts: `"filterable" => false` removes the field; `"items"`/`"item_type"`
  (a type map with `"kind"`, or a kind string) types `has`/`has_any` elements;
  Whitelisted `"functions"` (contains, string_starts_with, string_ends_with, has)
  become operators (ash_typescript parity); other functions stay metadata. Ash operator
  names in `"operators"` are mapped through `operator_key/1`.

  Relationship facts: an input with `"relationship" => %{"filter_inputs" => [...]}`
  (pre-expanded destination inputs, a list of the same shape) renders
  `op: z.literal("related")` whose value is the destination's filter union
  (leaf operators only, rendered at depth 0, no further relationships; output is
  capped at 1 MB, else `{:error, {:filter_too_large, bytes, cap}}`).

  `in` / `has_any` wrap the base fragment in `z.array(...)`; `has` uses the
  array's ELEMENT fragment (`z.unknown()` when no item type); every other operator uses the
  base fragment.

  ## Grammar constraint (verified against ZodGuard)

  The guard admits literal-argument z-chains only, so the entire catalog
  renders as data: `z.enum([...])` with JSON-escaped string literals,
  `z.literal("eq")`, and pre-rendered value fragments. Every emitted string
  is self-checked against `ZodGuard.expression/1` before being returned —
  a renderer bug surfaces as `{:error, {:guard_rejected, text}}`, never as
  unadmitted embedded text.
  """

  alias AshSurface.Compiler.ZodType

  # ash_typescript whitelists these Ash predicate functions as filter operators
  # (`filter_types.ex` @function_atom_to_key); they map to surface keys here.
  @function_keys %{
    "contains" => "contains",
    "string_starts_with" => "starts_with",
    "string_ends_with" => "ends_with",
    "has" => "has"
  }

  @max_depth 2
  @max_depth_cap 3
  @max_bytes 1_000_000
  # Logical (and/or/not) nesting levels allowed inside a related destination.
  @related_depth 1
  # Related-variant degradation ladder (see `render_adaptive/3`): a filter above this many
  # bytes is re-rendered with narrower relationship variants.
  @adaptive_limit 450_000
  @array_element "z.unknown()"
  @connectives ~w(and or not)
  @ordered ["eq", "neq", "gt", "gte", "lt", "lte", "in"]

  @ash_operator_keys %{
    "==" => "eq",
    "!=" => "neq",
    "<" => "lt",
    "<=" => "lte",
    ">" => "gt",
    ">=" => "gte",
    "in" => "in",
    "is_nil" => "is_nil"
  }

  @operators %{
    "string" => [
      "eq",
      "neq",
      "gt",
      "gte",
      "lt",
      "lte",
      "contains",
      "starts_with",
      "ends_with",
      "in"
    ],
    "integer" => ["eq", "neq", "gt", "gte", "lt", "lte", "in"],
    "float" => ["eq", "neq", "gt", "gte", "lt", "lte", "in"],
    "decimal" => ["eq", "neq", "gt", "gte", "lt", "lte", "in"],
    "boolean" => ["eq", "neq", "in"],
    "uuid" => ["eq", "neq", "in"],
    "array" => ["has", "has_any", "eq", "in"],
    "ci_string" => [
      "eq",
      "neq",
      "contains",
      "starts_with",
      "ends_with",
      "gt",
      "gte",
      "lt",
      "lte",
      "in"
    ],
    "date" => @ordered,
    "time" => @ordered,
    "utc_datetime" => @ordered,
    "utc_datetime_usec" => @ordered,
    "datetime" => @ordered,
    "naive_datetime" => @ordered,
    "atom" => @ordered
  }

  @default_operators ["eq", "neq", "in"]

  @doc """
  Renders the filter-argument expression for an admitted field set.

  Returns the guard-admitted discriminated-union expression or an error:
  `:filter_inputs_not_a_list`, `:no_filterable_fields`,
  `{:filter_input_missing_name, entry}`, `{:filter_input_missing_type, entry}`,
  or `{:guard_rejected, text, reason}`.
  """
  @spec render_filter_schema(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_filter_schema(inputs, opts \\ [])

  def render_filter_schema(inputs, opts) when is_list(inputs) and is_list(opts) do
    with {:ok, depth} <- fetch_depth(opts),
         {:ok, conns} <- fetch_connectives(opts),
         {:ok, entries} <- normalize(inputs),
         {:ok, zod} <- render_adaptive(entries, depth, conns) do
      if byte_size(zod) > @max_bytes do
        {:error, {:filter_too_large, byte_size(zod), @max_bytes}}
      else
        case AshSurface.Projectors.JS.ZodGuard.expression(zod) do
          :ok -> {:ok, zod}
          error -> {:error, {:guard_rejected, zod, error}}
        end
      end
    end
  end

  def render_filter_schema(other, _opts) when not is_list(other),
    do: {:error, {:filter_inputs_not_a_list, other}}

  def render_filter_schema(_inputs, other), do: {:error, {:filter_opts_not_a_list, other}}

  # Relationship (`related`) variants are the largest part of a wide resource's filter (the
  # whole inner union repeats at every logical level, and the guard check is superlinear in
  # size). Ladder, each step only when the previous exceeds `@adaptive_limit`:
  #   1. destinations render with `@related_depth` logical levels, related at every level;
  #   2. destinations render leaf-only (depth 0), related at every level;
  #   3. destinations leaf-only and related valid at the top level and one logical level in
  #      (deeper levels are scalar-only).
  # Filters without relationships, or small enough, are unaffected.
  defp render_adaptive(entries, depth, conns) do
    steps = [{@related_depth, :all}, {0, :all}, {0, :shallow}]

    if Enum.any?(entries, &(&1.related != nil)) do
      Enum.reduce_while(steps, nil, fn {dest_depth, levels}, _acc ->
        case render_union(entries, {depth, conns, dest_depth, levels}, true) do
          {:ok, zod} = ok ->
            if byte_size(zod) > @adaptive_limit, do: {:cont, ok}, else: {:halt, ok}

          error ->
            {:halt, error}
        end
      end)
    else
      render_union(entries, {depth, conns, 0, :all}, true)
    end
  end

  @doc """
  Renders the filter zod expression of an embedded resource (its own typed filter, with its
  own logical combinators), from its public attributes under the mapped/formatted wire names.
  """
  @spec render_embedded(module(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_embedded(resource, opts \\ []) when is_atom(resource) do
    render_filter_schema(
      AshSurface.Compiler.ResourceFacts.embedded_filter_entries(resource),
      opts
    )
  end

  @doc """
  Maps an Ash filter operator name (`==`, `!=`, `<`, `<=`, `>`, `>=`, `in`,
  `is_nil`; atom or string) to its surface key. Surface keys map to
  themselves; anything else is `:error` (Ash *functions* such as `contains`
  are metadata, not operators — see `split_capabilities/1`).
  """
  @spec operator_key(atom() | String.t()) :: {:ok, String.t()} | :error
  def operator_key(op) when is_atom(op) and not is_nil(op), do: operator_key(Atom.to_string(op))

  def operator_key(op) when is_binary(op) do
    cond do
      Map.has_key?(@ash_operator_keys, op) -> {:ok, Map.fetch!(@ash_operator_keys, op)}
      op in surface_keys() -> {:ok, op}
      true -> :error
    end
  end

  def operator_key(_), do: :error

  @doc """
  Splits a capability entry into `%{operators: [surface keys] | nil,
  functions: [binary]}`. `"functions"` stays metadata; operator names that
  `operator_key/1` cannot map are returned under `:unmapped` rather than
  silently becoming union members.
  """
  @spec split_capabilities(map()) :: %{
          operators: [String.t()] | nil,
          functions: [String.t()],
          unmapped: [String.t()]
        }
  def split_capabilities(entry) when is_map(entry) do
    functions = to_names(field(entry, "functions"))

    case field(entry, "operators") do
      ops when is_list(ops) ->
        {mapped, unmapped} =
          ops
          |> Enum.map(&to_string/1)
          |> Enum.map(&{&1, operator_key(&1)})
          |> Enum.split_with(&match?({_, {:ok, _}}, &1))

        fn_keys = functions |> Enum.flat_map(&List.wrap(@function_keys[&1]))

        %{
          operators:
            (Enum.map(mapped, fn {_, {:ok, k}} -> k end) ++ fn_keys) |> Enum.uniq() |> Enum.sort(),
          functions: functions,
          unmapped: Enum.map(unmapped, &elem(&1, 0))
        }

      _ ->
        %{operators: nil, functions: functions, unmapped: []}
    end
  end

  defp surface_keys do
    ["is_nil", "contains", "starts_with", "ends_with", "has", "has_any", "related" | @ordered]
  end

  defp to_names(list) when is_list(list),
    do: list |> Enum.map(&to_string/1) |> Enum.uniq() |> Enum.sort()

  defp to_names(_), do: []

  defp fetch_depth(opts) do
    case Keyword.get(opts, :max_depth, @max_depth) do
      d when is_integer(d) and d >= 0 and d <= @max_depth_cap -> {:ok, d}
      other -> {:error, {:invalid_max_depth, other, @max_depth_cap}}
    end
  end

  defp fetch_connectives(opts) do
    case Keyword.get(opts, :connectives, @connectives) do
      list when is_list(list) ->
        names = Enum.map(list, &to_string/1)

        case Enum.reject(names, &(&1 in @connectives)) do
          [] -> {:ok, @connectives |> Enum.filter(&(&1 in names))}
          bad -> {:error, {:unknown_connectives, bad}}
        end

      other ->
        {:error, {:invalid_connectives, other}}
    end
  end

  ## Internals

  defp normalize([]), do: {:error, :no_filterable_fields}

  defp normalize(inputs) do
    inputs
    |> Enum.reject(&unfilterable?/1)
    |> case do
      [] -> [:none]
      kept -> kept
    end
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, acc} ->
      case normalize_entry(entry) do
        {:ok, e} -> {:cont, {:ok, [e | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.reverse(entries)}
      error -> error
    end
  end

  defp unfilterable?(entry) when is_map(entry) do
    field(entry, "filterable") == false or field(entry, "filterable?") == false
  end

  defp unfilterable?(_), do: false

  defp normalize_entry(:none), do: {:error, :no_filterable_fields}

  defp normalize_entry(entry) when is_map(entry) do
    with name when is_binary(name) <-
           field(entry, "name") || {:error, {:filter_input_missing_name, entry}},
         type when is_map(type) <-
           field(entry, "type") || {:error, {:filter_input_missing_type, entry}},
         kind when is_binary(kind) <-
           kind_name(field(type, "kind")) || {:error, {:filter_input_missing_kind, name}},
         {:ok, operators} <- checked_operators(name, entry),
         {:ok, related} <- normalize_related(field(entry, "relationship")) do
      {:ok,
       %{
         name: name,
         kind: kind,
         operators: operators,
         element: element_kind(entry),
         zod: field(entry, "zod"),
         element_zod: field(entry, "element_zod"),
         values: enum_values(kind, entry),
         nullable: field(entry, "allow_nil?") == true,
         related: related
       }}
    else
      {:error, _} = error -> error
      _ -> {:error, {:filter_input_malformed, entry}}
    end
  end

  defp normalize_entry(entry), do: {:error, {:filter_input_malformed, entry}}

  # A constrained atom (kind `enum`, `one_of`) carries its allowed values; eq/neq/in narrow to them.
  defp enum_values(kind, entry) when kind in ["atom", "enum"] do
    case field(entry, "values") do
      [_ | _] = values -> Enum.map(values, &to_string/1)
      _ -> nil
    end
  end

  defp enum_values(_kind, _entry), do: nil

  defp kind_name(kind) when is_atom(kind) and not is_nil(kind), do: Atom.to_string(kind)
  defp kind_name(kind), do: kind

  # Unmapped operator names and caller-injected "related" are typed refusals.
  defp checked_operators(name, entry) do
    case split_capabilities(entry) do
      %{unmapped: [_ | _] = unmapped} ->
        {:error, {:filter_input_unmapped_operators, name, unmapped}}

      %{operators: ops} when is_list(ops) ->
        if "related" in ops,
          do: {:error, {:filter_input_related_operator, name}},
          else: {:ok, ops}

      %{operators: nil} ->
        {:ok, nil}
    end
  end

  defp normalize_related(nil), do: {:ok, nil}

  defp normalize_related(rel) when is_map(rel) do
    case field(rel, "filter_inputs") do
      list when is_list(list) and list != [] ->
        # Destination inputs are leaf-only: relationships do not nest further.
        if Enum.all?(list, &is_map/1) do
          normalize(Enum.map(list, &Map.drop(&1, [:relationship, "relationship"])))
        else
          {:error, {:filter_input_malformed, list}}
        end

      _ ->
        {:ok, nil}
    end
  end

  defp normalize_related(_), do: {:ok, nil}

  defp element_kind(entry) do
    type = field(entry, "type")
    nested = if is_map(type), do: field(type, "items") || field(type, "item_type")

    case field(entry, "items") || field(entry, "item_type") || nested do
      kind when is_binary(kind) -> kind
      kind when is_atom(kind) and not is_nil(kind) -> Atom.to_string(kind)
      %{} = t -> kind_name(field(t, "kind"))
      _ -> nil
    end
  end

  # String- or atom-keyed lookup (serialized discovery vs IR struct idioms).
  defp field(map, name) when is_map(map) do
    case Map.fetch(map, name) do
      {:ok, v} when not is_nil(v) ->
        v

      _ ->
        Enum.find_value(map, fn
          {k, v} when is_atom(k) and not is_nil(v) ->
            if Atom.to_string(k) == name, do: {:found, v}

          _ ->
            nil
        end)
        |> case do
          {:found, v} -> v
          nil -> nil
        end
    end
  end

  # Union at `depth` remaining logical wrap levels. `top?` includes relationship variants;
  # destination unions are leaf-only. `cfg` = `{depth, conns, dest_depth, levels}` (see
  # `render_adaptive/3`): `levels == :shallow` repeats relationship variants only at the top
  # level and one logical level in.
  defp render_union(entries, {depth, conns, _dest_depth, levels} = cfg, top?) do
    with {:ok, scalar, related} <- leaf_variants(entries, cfg, top?) do
      case scalar ++ related ++ logical_variants(scalar, related, depth, conns, levels) do
        [] -> {:error, :no_filterable_fields}
        variants -> {:ok, union(variants)}
      end
    end
  end

  defp logical_variants(_scalar, _related, 0, _conns, _levels), do: []
  defp logical_variants([], [], _depth, _conns, _levels), do: []

  defp logical_variants(scalar, related, depth, conns, levels) do
    deeper = if levels == :shallow, do: [], else: related
    inner = union(scalar ++ related ++ logical_variants(scalar, deeper, depth - 1, conns, levels))

    Enum.map(conns, fn
      "and" ->
        "z.object({op: z.literal(\"and\"), value: z.array(" <> inner <> ")})"

      "or" ->
        "z.object({op: z.literal(\"or\"), value: z.array(" <> inner <> ")})"

      "not" ->
        # ash_typescript shape (array, conjunction negated) and the single filter.
        "z.object({op: z.literal(\"not\"), value: z.union([" <>
          inner <> ", z.array(" <> inner <> ").min(1)])})"
    end)
  end

  defp union(variants), do: "z.union([" <> Enum.join(variants, ", ") <> "])"

  defp leaf_variants(entries, cfg, top?) do
    scalar =
      for {{kind, op, element}, group} <- operator_groups(entries) do
        names = group |> Enum.map(& &1.name) |> Enum.sort() |> Enum.map_join(", ", &json_string/1)

        "z.object({field: z.enum([" <>
          names <>
          "]), op: z.literal(" <>
          json_string(op) <>
          "), value: " <> value_fragment(kind, op, element) <> "})"
      end

    with {:ok, related} <- related_variants(entries, cfg, top?) do
      {:ok, scalar, related}
    end
  end

  defp operator_groups(entries) do
    entries
    |> Enum.reject(&(&1.related != nil))
    |> Enum.flat_map(fn e -> Enum.map(operators_for(e), &{{e.kind, &1, element_for(e)}, e}) end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.sort_by(fn {{kind, op, element}, _} ->
      {kind, op_rank(kind, op), op, inspect(element)}
    end)
  end

  defp element_for(%{kind: "array", element_zod: zod}) when is_binary(zod), do: {:zod, zod}
  defp element_for(%{kind: "array", element: element}), do: element
  defp element_for(%{zod: zod}) when is_binary(zod), do: {:zod, zod}

  defp element_for(%{kind: kind, values: [_ | _] = values}) when kind in ["atom", "enum"],
    do: {:enum, values}

  defp element_for(_), do: nil

  defp op_rank(kind, op) do
    Enum.find_index(Map.get(@operators, kind, @default_operators) ++ ["is_nil"], &(&1 == op)) ||
      99
  end

  defp operators_for(%{operators: ops, kind: kind, nullable: nullable}) do
    base = ops || Map.get(@operators, kind, @default_operators)
    if nullable and "is_nil" not in base, do: base ++ ["is_nil"], else: base
  end

  defp related_variants(entries, cfg, true) do
    related = entries |> Enum.filter(&(&1.related != nil)) |> Enum.sort_by(& &1.name)
    render_related(related, cfg)
  end

  defp related_variants(_entries, _cfg, false), do: {:ok, []}

  defp render_related(related, {depth, conns, dest_depth, _levels}) do
    Enum.reduce_while(related, {:ok, []}, fn e, {:ok, acc} ->
      case render_union(e.related, {min(depth, dest_depth), conns, 0, :all}, false) do
        {:ok, dest} ->
          {:cont,
           {:ok,
            acc ++
              [
                "z.object({field: z.enum([" <>
                  json_string(e.name) <> "]), op: z.literal(\"related\"), value: " <> dest <> "})"
              ]}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp value_fragment(_kind, "is_nil", _el), do: "z.boolean()"
  defp value_fragment("array", "eq", el), do: "z.array(" <> element_fragment(el) <> ")"
  defp value_fragment("array", "in", el), do: "z.array(z.array(" <> element_fragment(el) <> "))"
  defp value_fragment("array", "has", el), do: element_fragment(el)
  defp value_fragment("array", "has_any", el), do: "z.array(" <> element_fragment(el) <> ")"

  defp value_fragment(_kind, op, {:zod, zod}) when op in ~w(in has_any),
    do: "z.array(" <> zod <> ")"

  defp value_fragment(_kind, _op, {:zod, zod}), do: zod

  defp value_fragment(kind, op, {:enum, values})
       when kind in ["atom", "enum"] and op in ~w(eq neq),
       do: enum_fragment(values)

  defp value_fragment(kind, "in", {:enum, values}) when kind in ["atom", "enum"],
    do: "z.array(" <> enum_fragment(values) <> ")"

  defp value_fragment(kind, op, _el) when op in ~w(in has_any),
    do: "z.array(" <> kind_base(kind) <> ")"

  defp value_fragment(kind, _op, _el), do: kind_base(kind)

  defp enum_fragment(values),
    do: "z.enum([" <> Enum.map_join(values, ", ", &json_string/1) <> "])"

  defp element_fragment(nil), do: @array_element
  defp element_fragment({:zod, zod}), do: zod

  defp element_fragment(kind),
    do: if(kind in ZodType.kinds(), do: ZodType.base(kind), else: @array_element)

  defp kind_base(kind) do
    if kind in ZodType.kinds(), do: ZodType.base(kind), else: "z.unknown()"
  end

  defp json_string(text), do: Jason.encode!(text)
end
