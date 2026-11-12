defmodule AshSurface.Compiler.ZodType do
  @moduledoc """
  The single Zod 4 type-fragment table shared by `Compiler.Schema`,
  `Compiler.UnionSchema`, `Projector.Expo` and the filter/query/selection
  schemas.

  Definitions are string-keyed (atom-keyed keys are accepted too):
  `"type" => %{"kind" => kind}`, `"constraints"`, `"allow_nil?"`,
  `"subtype_of"`, `"subtype_constraints"`, plus for arrays
  `"items"`/`"item_type"` (a definition or `%{"kind" => ...}`).

  Optionality is split from nullability: `allow_nil?: true` renders
  `.nullable()`; an omittable field (`"optional" => true`, `"required?" => false`
  or a `"default"` key) renders `.optional()`; both render
  `.nullable().optional()`.

  Custom mapping: `fragment/2` takes `overrides: %{kind => zod_expression}`;
  by default `Application.get_env(:ash_surface, :zod_mapping_overrides, %{})`
  is consulted. `unmappable_kinds/2` is the compile-time verifier: kinds that
  neither the table nor an override covers.
  """

  @base %{
    "string" => "z.string()",
    "ci_string" => "z.string()",
    "integer" => "z.number().int()",
    "boolean" => "z.boolean()",
    # Better than ash_typescript (z.uuid(): RFC 9562 version/variant only): z.guid()
    # accepts every 8-4-4-4-12 hex UUID, the set Ecto/Ash accept.
    "uuid" => "z.guid()",
    "float" => "z.number()",
    "decimal" => "z.string()",
    "date" => "z.iso.date()",
    "time" => "z.iso.time()",
    "utc_datetime" => "z.iso.datetime()",
    "utc_datetime_usec" => "z.iso.datetime()",
    "datetime" => "z.iso.datetime()",
    # Better than ash_typescript (requires Z): zoneless ISO is what naive_datetime is.
    "naive_datetime" => "z.iso.datetime({local: true})",
    "duration" => "z.iso.duration()",
    "binary" => "z.string()",
    "atom" => "z.string()",
    "term" => "z.any()",
    "map" => "z.record(z.string(), z.unknown())",
    "array" => "z.array(z.unknown())",
    "vector" => "z.array(z.number())",
    # Matches ash_typescript (UUIDv7 => z.uuid()); z.guid() would loosen, not improve.
    "uuid_v7" => "z.uuid()",
    "time_usec" => "z.iso.time()",
    "duration_name" => "z.string()",
    "url_encoded_binary" => "z.string()",
    "module" => "z.string()",
    "file" => "z.any()",
    "function" => "z.any()",
    "any" => "z.any()",
    "keyword" => "z.record(z.string(), z.unknown())",
    "tuple" => "z.record(z.string(), z.unknown())",
    "struct" => "z.record(z.string(), z.unknown())",
    "enum" => "z.string()",
    "binary_id" => "z.guid()",
    "date_time" => "z.iso.datetime()",
    "ltree" => "z.union([z.string(), z.array(z.string())])"
  }

  @numeric_kinds ~w(integer float)
  @string_kinds ~w(string ci_string uuid uuid_v7 binary_id date_time date time time_usec utc_datetime utc_datetime_usec datetime
                   naive_datetime duration binary atom decimal)
  @length_kinds ~w(string ci_string binary array)
  @string_length_kinds ~w(string ci_string binary)

  @doc "All kinds in the table, sorted."
  @spec kinds() :: [String.t()]
  def kinds, do: @base |> Map.keys() |> Enum.sort()

  @doc "Base fragment for a kind (`z.unknown()` when unmapped)."
  @spec base(String.t(), keyword()) :: String.t()
  def base(kind, opts \\ []) when is_binary(kind) do
    Map.get(overrides(opts), kind) || Map.get(@base, kind, "z.unknown()")
  end

  @doc "Kinds in `definitions` covered by neither the table nor an override."
  @spec unmappable_kinds([map()], keyword()) :: [String.t()]
  def unmappable_kinds(definitions, opts \\ []) when is_list(definitions) do
    known = Map.keys(@base) ++ Map.keys(overrides(opts))

    definitions
    |> Enum.flat_map(&all_kinds(&1, opts))
    |> Enum.reject(&(is_nil(&1) or &1 in known))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp all_kinds(%{} = definition, opts) do
    type = get(definition, "type")
    type = if is_map(type), do: type, else: %{}

    children =
      [
        get(type, "items"),
        get(type, "item_type"),
        get(definition, "items"),
        get(definition, "item_type")
      ]
      |> Enum.flat_map(&child_defs/1)
      |> Kernel.++(child_defs(get(type, "fields")))
      |> Kernel.++(child_defs(get(definition, "fields")))
      |> Kernel.++(child_defs(get(type, "members")))
      |> Kernel.++(child_defs(get(definition, "members")))

    own = if module_override(definition, opts) == nil, do: [kind_of(definition)], else: []
    own ++ Enum.flat_map(children, &all_kinds(&1, opts))
  end

  defp all_kinds(_, _opts), do: []

  defp child_defs(nil), do: []
  defp child_defs(list) when is_list(list), do: Enum.flat_map(list, &child_defs/1)
  defp child_defs(%{"kind" => _} = t), do: [%{"type" => t}]

  defp child_defs(%{kind: kind} = t),
    do: [%{"type" => %{"kind" => to_string(kind), "items" => get(t, "items")}}]

  defp child_defs(%{} = m) do
    if Map.has_key?(m, "type") or Map.has_key?(m, :type) or Map.has_key?(m, "subtype_of"),
      do: [m],
      else: m |> Map.values() |> Enum.flat_map(&child_defs/1)
  end

  defp child_defs({_name, %{} = d}), do: child_defs(d)
  defp child_defs(_), do: []

  @doc "Full Zod expression for a definition, including constraint chain."
  @spec fragment(map(), keyword()) :: String.t()
  def fragment(definition, opts \\ [])

  def fragment(%{"type" => %{"kind" => kind}} = definition, opts) when is_binary(kind) do
    kind
    |> value_fragment(definition, constraints_of(definition, "constraints"), opts)
    |> wrap(definition)
  end

  def fragment(%{"subtype_of" => subtype} = definition, opts) when is_binary(subtype) do
    subtype
    |> value_fragment(definition, constraints_of(definition, "subtype_constraints"), opts)
    |> wrap(definition)
  end

  def fragment(%{type: %{kind: kind}} = definition, opts),
    do: fragment(stringify(definition, kind), opts)

  def fragment(_, _opts), do: "z.unknown()"

  defp stringify(definition, kind) do
    type = get(definition, "type")

    %{
      "type" => %{
        "kind" => to_string(kind),
        "items" => get(type, "items"),
        "values" => get(type, "values")
      },
      "constraints" => get(definition, "constraints"),
      "subtype_constraints" => get(definition, "subtype_constraints"),
      "subtype_of" => get(definition, "subtype_of"),
      "values" => get(definition, "values"),
      "items" => get(definition, "items"),
      "required?" => get(definition, "required?"),
      "allow_nil?" => get(definition, "allow_nil?"),
      "allow_nil" => get(definition, "allow_nil"),
      "has_default" => get(definition, "has_default"),
      "optional" => get(definition, "optional")
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> then(fn m ->
      if Map.has_key?(definition, :default) or Map.has_key?(definition, "default"),
        do: Map.put(m, "default", get(definition, "default")),
        else: m
    end)
  end

  defp value_fragment(kind, definition, constraints, opts) do
    case module_override(definition, opts) do
      expr when is_binary(expr) ->
        expr

      nil ->
        case one_of_values(constraints) do
          [] -> base_for(kind, definition, opts) <> constraint_chain(kind, constraints)
          values -> enum_fragment(kind, values)
        end
    end
  end

  # Built-in third-party Ash types (ash_typescript `ZodSchemaGenerator.third_party_types/0`),
  # matched by module name (no hard dependency on the third-party package). A configured
  # `zod_mapping_overrides` entry for the same module wins.
  @third_party_types %{
    "AshMoney.Types.Money" => "z.object({ amount: z.string(), currency: z.string() })"
  }

  @doc "Built-in module-keyed Zod expressions for third-party Ash types."
  @spec third_party_types() :: %{String.t() => String.t()}
  def third_party_types, do: @third_party_types

  # Module-keyed override (ash_typescript `type_mapping_overrides` /
  # `zod_mapping_overrides` `{Module, expr}` entries): the definition's
  # `"type" => %{"module" => "Mod"}` is looked up by `inspect(Mod)`.
  defp module_override(definition, opts) do
    with %{} = type <- get(definition, "type"),
         module when is_binary(module) <- get(type, "module") do
      Map.get(overrides(opts), module) || Map.get(@third_party_types, module) ||
        type_name_expression(module, kind_of(definition))
    else
      _ -> nil
    end
  end

  # A custom Ash type declaring `typescript_type_name/0` (ash_typescript's "this type is
  # mappable" marker) is admitted without an override: well-known TS names map to their
  # Zod primitive, any other declared name validates as `z.unknown()`.
  @type_name_zod %{
    "string" => "z.string()",
    "number" => "z.number()",
    "boolean" => "z.boolean()"
  }

  defp type_name_expression(module, kind) do
    mod = String.to_existing_atom("Elixir." <> module)

    if Code.ensure_loaded?(mod) and function_exported?(mod, :typescript_type_name, 0) do
      Map.get(@type_name_zod, mod.typescript_type_name()) ||
        (kind == "unknown" && storage_expression(mod)) || "z.unknown()"
    else
      (kind == "unknown" && storage_expression(mod)) || nil
    end
  rescue
    ArgumentError -> nil
  end

  # Hand-rolled `use Ash.Type` module (kind "unknown", no override): derive the schema from
  # `Ash.Type.storage_type/1` (ash_typescript `SchemaCore.storage_derived_schema/2`). Only
  # storage types with an unambiguous JSON wire form derive; anything else returns nil and
  # stays refused as unmappable (divergence KD-06: the reference falls back to `z.any()`).
  defp storage_expression(mod) do
    if Ash.Type.ash_type?(mod) and not Ash.Type.NewType.new_type?(mod) and
         Ash.Type.builtin?(mod) == false do
      storage_schema(Ash.Type.storage_type(mod))
    end
  rescue
    _ -> nil
  end

  @storage_kinds %{
    boolean: "boolean",
    uuid: "uuid",
    binary_id: "uuid",
    date: "date",
    time: "time",
    time_usec: "time_usec",
    naive_datetime: "naive_datetime",
    utc_datetime: "utc_datetime",
    utc_datetime_usec: "utc_datetime_usec",
    decimal: "decimal",
    binary: "binary",
    integer: "integer",
    float: "float",
    string: "string",
    ci_string: "string",
    atom: "string",
    map: "map",
    jsonb: "map"
  }

  defp storage_schema({:array, inner}) do
    case storage_schema(inner) do
      nil -> nil
      item -> "z.array(#{item})"
    end
  end

  defp storage_schema(storage) do
    case Map.get(@storage_kinds, storage) do
      nil -> nil
      kind -> Map.fetch!(@base, kind)
    end
  end

  defp base_for("enum", definition, _opts) do
    type = get(definition, "type") || %{}

    case get(type, "values") || get(definition, "values") do
      [_ | _] = values -> enum_fragment("string", values)
      _ -> "z.string()"
    end
  end

  defp base_for("array", definition, opts) do
    case items_of(definition) do
      nil -> base("array", opts)
      item -> "z.array(#{fragment(item, opts)})"
    end
  end

  # AshPostgres.Ltree: `escape?: true` is the array form only (ref: type_mapper map_ltree).
  defp base_for("ltree", definition, opts) do
    if cget(constraints_of(definition, "constraints"), "escape?") == true and
         not Map.has_key?(overrides(opts), "ltree"),
       do: "z.array(z.string())",
       else: base("ltree", opts)
  end

  defp base_for(kind, _definition, opts), do: base(kind, opts)

  defp items_of(definition) do
    type = get(definition, "type") || %{}

    item =
      get(type, "items") || get(type, "item_type") || get(definition, "items") ||
        get(definition, "item_type")

    case item do
      %{"kind" => _} = t -> %{"type" => t}
      %{kind: _} = t -> %{"type" => %{"kind" => to_string(t.kind)}}
      %{} = m when map_size(m) > 0 -> m
      _ -> nil
    end
  end

  # one_of: sorted standalone z.enum for string-valued kinds; literal union
  # for numeric kinds.
  defp enum_fragment(kind, values) when kind in @numeric_kinds do
    case values |> Enum.uniq() |> Enum.sort() |> Enum.map(&"z.literal(#{Jason.encode!(&1)})") do
      [one] -> one
      many -> "z.union([#{Enum.join(many, ", ")}])"
    end
  end

  defp enum_fragment(_kind, values) do
    rendered =
      values
      |> Enum.map(&to_string/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map_join(", ", &Jason.encode!/1)

    "z.enum([#{rendered}])"
  end

  defp one_of_values(constraints) do
    case cget(constraints, "one_of") do
      values when is_list(values) -> values
      _ -> []
    end
  end

  defp constraint_chain(_kind, constraints) when map_size(constraints) == 0, do: ""

  defp constraint_chain(kind, constraints) do
    numeric_bound(constraints, kind, "min", "min") <>
      numeric_bound(constraints, kind, "max", "max") <>
      numeric_bound(constraints, kind, "greater_than", "gt") <>
      numeric_bound(constraints, kind, "less_than", "lt") <>
      min_length_bound(constraints, kind) <>
      length_bound(constraints, kind, "max_length", "max") <>
      regex_constraint(constraints, kind)
  end

  defp numeric_bound(constraints, kind, key, zod) when kind in @numeric_kinds do
    case cget(constraints, key) do
      value when is_number(value) ->
        ".#{zod}(#{AshSurface.Compiler.NumberLiteral.render!(value)})"

      _ ->
        ""
    end
  end

  defp numeric_bound(_constraints, _kind, _key, _zod), do: ""

  # allow_empty?: false enforces non-empty only when the key is explicitly
  # present (schema_core.ex require_non_empty?/effective_min_length).
  defp min_length_bound(constraints, kind) when kind in @string_length_kinds do
    explicit = cget(constraints, "min_length")
    explicit = if is_integer(explicit), do: explicit, else: nil

    case cget(constraints, "allow_empty?") do
      false -> ".min(#{max(explicit || 1, 1)})"
      _ -> if explicit, do: ".min(#{explicit})", else: ""
    end
  end

  defp min_length_bound(constraints, kind),
    do: length_bound(constraints, kind, "min_length", "min")

  defp length_bound(constraints, kind, key, zod) when kind in @length_kinds do
    case cget(constraints, key) do
      value when is_integer(value) -> ".#{zod}(#{value})"
      _ -> ""
    end
  end

  defp length_bound(_constraints, _kind, _key, _zod), do: ""

  defp regex_constraint(constraints, kind) when kind in @string_kinds do
    case cget(constraints, "match") do
      source when is_binary(source) ->
        flags = js_flags(cget(constraints, "match_flags"))

        case translate_regex(source, flags) do
          {:ok, body} -> ".regex(/#{escape_slashes(body)}/#{flags})"
          {:error, _} -> ""
        end

      _ ->
        ""
    end
  end

  defp regex_constraint(_constraints, _kind), do: ""

  @doc """
  Constraints that `fragment/2` drops instead of rendering: a `match` source
  that is not safe for JS (typed reason from `regex_check/1`). Dropping is
  never silent: callers read this channel alongside `fragment/2`.
  """
  @spec dropped_constraints(map(), keyword()) :: [map()]
  def dropped_constraints(definition, _opts \\ []) do
    {kind, constraints} =
      cond do
        match?(%{"type" => %{"kind" => k}} when is_binary(k), definition) ->
          {definition["type"]["kind"], constraints_of(definition, "constraints")}

        is_binary(get(definition, "subtype_of")) ->
          {get(definition, "subtype_of"), constraints_of(definition, "subtype_constraints")}

        match?(%{type: %{kind: _}}, definition) ->
          {to_string(definition.type.kind), constraints_of(definition, "constraints")}

        true ->
          {nil, %{}}
      end

    with true <- kind in @string_kinds,
         source when is_binary(source) <- cget(constraints, "match"),
         {:error, reason} <- translate_regex(source, js_flags(cget(constraints, "match_flags"))) do
      [%{constraint: "match", source: source, reason: reason}]
    else
      _ -> []
    end
  end

  # Escape only unescaped `/`; existing backslash pairs pass through untouched.
  defp escape_slashes(source), do: escape_slashes(source, "")
  defp escape_slashes("", acc), do: acc

  defp escape_slashes(<<"\\", c::utf8, rest::binary>>, acc),
    do: escape_slashes(rest, acc <> <<"\\", c::utf8>>)

  defp escape_slashes(<<"/", rest::binary>>, acc), do: escape_slashes(rest, acc <> "\\/")

  defp escape_slashes(<<c::utf8, rest::binary>>, acc),
    do: escape_slashes(rest, acc <> <<c::utf8>>)

  defp escape_slashes(<<b, rest::binary>>, acc), do: escape_slashes(rest, acc <> <<b>>)

  @doc "True when a regex source is safe to emit as a JS literal (no PCRE-only syntax)."
  @spec regex_safe_for_js?(String.t()) :: boolean()
  def regex_safe_for_js?(source) when is_binary(source), do: regex_check(source) == :ok

  @doc "`:ok` or `{:error, reason}` (typed) for a PCRE source against JS semantics."
  @spec regex_check(String.t()) :: :ok | {:error, term()}
  def regex_check(source) when is_binary(source) do
    case translate_regex(source, "") do
      {:ok, _} -> :ok
      {:error, _} = e -> e
    end
  end

  # Escapes that mean something in PCRE but a different thing (identity) in JS.
  @pcre_escapes ~c"pPzZhHRKQEAGXg"

  # Parses the source honouring escapes and character classes. Returns the
  # JS-faithful body: an unescaped `$` outside a class becomes `(?=\n?$)`
  # (PCRE `$` also matches before one final newline) unless the `m` flag is on.
  defp translate_regex("", _flags), do: {:error, :empty_pattern}

  defp translate_regex(source, flags) do
    if String.contains?(source, ["\n", "\r", "\u2028", "\u2029"]),
      do: {:error, :raw_line_terminator},
      else:
        scan_regex(String.to_charlist(source), false, 0, :start, String.contains?(flags, "m"), [])
  end

  defp scan_regex([], true, _d, _p, _m, _acc), do: {:error, :unterminated_class}
  defp scan_regex([], false, d, _p, _m, _acc) when d != 0, do: {:error, :unbalanced_parens}
  defp scan_regex([], false, _d, _p, _m, acc), do: {:ok, acc |> Enum.reverse() |> to_string()}
  defp scan_regex([?\\], _c, _d, _p, _m, _acc), do: {:error, :trailing_backslash}

  defp scan_regex([?\\, e | _], _c, _d, _p, _m, _acc) when e in @pcre_escapes,
    do: {:error, {:pcre_only, <<?\\, e>>}}

  # JS (no `u` flag) reads these as identity escapes; PCRE gives them meaning.
  defp scan_regex([?\\, ?e | rest], c, d, _p, m, acc),
    do: scan_regex(rest, c, d, :atom, m, Enum.reverse(~c"\\x1b") ++ acc)

  defp scan_regex([?\\, ?a | rest], c, d, _p, m, acc),
    do: scan_regex(rest, c, d, :atom, m, Enum.reverse(~c"\\x07") ++ acc)

  defp scan_regex([?\\, e | _], _c, _d, _p, _m, _acc) when e in ~c"NVo",
    do: {:error, {:pcre_only, <<?\\, e>>}}

  defp scan_regex([?\\, ?x, ?{ | rest], c, d, _p, m, acc) do
    bin = List.to_string(rest)

    case Regex.run(~r/\A([0-9a-fA-F]{1,2})\}/, bin) do
      [whole, hex] ->
        tail = binary_part(bin, byte_size(whole), byte_size(bin) - byte_size(whole))
        hex = String.pad_leading(hex, 2, "0")

        scan_regex(
          String.to_charlist(tail),
          c,
          d,
          :atom,
          m,
          Enum.reverse(String.to_charlist("\\x" <> hex)) ++ acc
        )

      _ ->
        {:error, {:pcre_only, "\\x{...}"}}
    end
  end

  defp scan_regex([?\\, b | rest], false, d, _p, m, acc) when b in ~c"bB",
    do: scan_regex(rest, false, d, :assertion, m, [b, ?\\ | acc])

  defp scan_regex([?\\, e | rest], c, d, _p, m, acc),
    do: scan_regex(rest, c, d, :atom, m, [e, ?\\ | acc])

  defp scan_regex([?[ | rest], true, d, p, m, acc) do
    if Regex.match?(~r/\A:\^?[a-z]+:\]/, List.to_string(rest)),
      do: {:error, {:pcre_only, "[[:class:]]"}},
      else: scan_regex(rest, true, d, p, m, [?[ | acc])
  end

  # `[]x]` / `[^]x]`: PCRE reads the leading `]` as a literal, JS as an empty class.
  defp scan_regex([?[, ?] | _], false, _d, _p, _m, _acc),
    do: {:error, {:pcre_only, "leading ] in class"}}

  defp scan_regex([?[, ?^, ?] | _], false, _d, _p, _m, _acc),
    do: {:error, {:pcre_only, "leading ] in class"}}

  defp scan_regex([?[ | rest], false, d, _p, m, acc),
    do: scan_regex(rest, true, d, :atom, m, [?[ | acc])

  defp scan_regex([?] | rest], true, d, _p, m, acc),
    do: scan_regex(rest, false, d, :atom, m, [?] | acc])

  defp scan_regex([ch | rest], true, d, p, m, acc),
    do: scan_regex(rest, true, d, p, m, [ch | acc])

  defp scan_regex([?(, ??, ?: | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d + 1, :open, m, [?:, ??, ?( | acc])

  defp scan_regex([?(, ??, x | rest], false, d, _p, m, acc) when x in [?=, ?!],
    do: scan_regex(rest, false, d + 1, :open, m, [x, ??, ?( | acc])

  defp scan_regex([?(, ??, ?<, x | _], false, _d, _p, _m, _acc) when x in [?=, ?!],
    do: {:error, {:pcre_only, "(?<" <> <<x>>}}

  defp scan_regex([?(, ??, ?<, x | rest], false, d, _p, m, acc) when x not in [?=, ?!],
    do: scan_regex(rest, false, d + 1, :open, m, [x, ?<, ??, ?( | acc])

  defp scan_regex([?(, ??, x | _], false, _d, _p, _m, _acc),
    do: {:error, {:pcre_only, "(?" <> <<x>>}}

  defp scan_regex([?(, ??], false, _d, _p, _m, _acc), do: {:error, {:pcre_only, "(?"}}

  defp scan_regex([?( | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d + 1, :open, m, [?( | acc])

  defp scan_regex([?) | _], false, 0, _p, _m, _acc), do: {:error, :unbalanced_parens}

  defp scan_regex([?) | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d - 1, :atom, m, [?) | acc])

  defp scan_regex([?| | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d, :open, m, [?| | acc])

  defp scan_regex([q | _], false, _d, p, _m, _acc)
       when q in [?*, ?+, ??] and p in [:start, :open, :assertion],
       do: {:error, {:nothing_to_repeat, <<q>>}}

  defp scan_regex([?{ | rest], false, d, p, m, acc) do
    bin = List.to_string(rest)

    case Regex.run(~r/\A\d+(,\d*)?\}/, bin) do
      nil ->
        scan_regex(rest, false, d, :atom, m, [?{ | acc])

      [whole | _] when p in [:start, :open, :assertion, :quant, :lazy] ->
        {:error, {:nothing_to_repeat, "{" <> whole}}

      [whole | _] ->
        tail = binary_part(bin, byte_size(whole), byte_size(bin) - byte_size(whole))

        scan_regex(
          String.to_charlist(tail),
          false,
          d,
          :quant,
          m,
          Enum.reverse(String.to_charlist("{" <> whole)) ++ acc
        )
    end
  end

  defp scan_regex([?+ | _], false, _d, p, _m, _acc) when p in [:quant, :lazy],
    do: {:error, {:pcre_only, "possessive quantifier"}}

  defp scan_regex([?? | rest], false, d, :quant, m, acc),
    do: scan_regex(rest, false, d, :lazy, m, [?? | acc])

  defp scan_regex([q | _], false, _d, p, _m, _acc) when q in [?*, ??] and p in [:quant, :lazy],
    do: {:error, {:nothing_to_repeat, <<q>>}}

  defp scan_regex([?^ | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d, :assertion, m, [?^ | acc])

  defp scan_regex([q | rest], false, d, _p, m, acc) when q in [?*, ?+, ??],
    do: scan_regex(rest, false, d, :quant, m, [q | acc])

  defp scan_regex([?$ | rest], false, d, _p, false, acc),
    do: scan_regex(rest, false, d, :assertion, false, Enum.reverse(~c"(?=\\n?$)") ++ acc)

  defp scan_regex([ch | rest], false, d, _p, m, acc),
    do: scan_regex(rest, false, d, :atom, m, [ch | acc])

  defp js_flags(flags) when is_binary(flags) do
    flags
    |> String.graphemes()
    |> Enum.filter(&(&1 in ~w(i m s)))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join()
  end

  defp js_flags(_), do: ""

  defp wrap(expr, definition) do
    expr
    |> then(
      &if(get(definition, "allow_nil?") == true or get(definition, "allow_nil") == true,
        do: &1 <> ".nullable()",
        else: &1
      )
    )
    |> then(&if(omittable?(definition), do: &1 <> ".optional()", else: &1))
  end

  defp omittable?(definition) do
    get(definition, "optional") == true or get(definition, "required?") == false or
      get(definition, "has_default") == true or
      Map.has_key?(definition, "default") or Map.has_key?(definition, :default)
  end

  defp kind_of(%{"type" => %{"kind" => kind}}), do: kind
  defp kind_of(%{"subtype_of" => kind}) when is_binary(kind), do: kind
  defp kind_of(_), do: nil

  defp overrides(opts) do
    raw =
      Keyword.get_lazy(opts, :overrides, fn ->
        Application.get_env(:ash_surface, :zod_mapping_overrides, %{})
      end)

    if Enumerable.impl_for(raw) do
      for {k, v} when is_binary(v) <- raw, into: %{}, do: {override_key(k), v}
    else
      %{}
    end
  end

  defp override_key(k) when is_binary(k), do: k

  defp override_key(k) when is_atom(k) do
    name = Atom.to_string(k)
    if String.starts_with?(name, "Elixir."), do: inspect(k), else: name
  end

  defp override_key(k), do: inspect(k)

  defp constraints_of(definition, name) do
    case get(definition, name) do
      %{} = constraints -> constraints
      _ -> %{}
    end
  end

  defp get(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, String.to_atom(key))
      value -> value
    end
  end

  defp get(_, _), do: nil

  defp cget(constraints, key), do: get(constraints, key)
end
