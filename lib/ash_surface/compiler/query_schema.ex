defmodule AshSurface.Compiler.QuerySchema do
  @moduledoc """
  Runtime-admission zod envelopes for query pagination and sort.

  Both renderers are PURE string renderers: they emit a zod expression
  (a `z`-rooted member/call chain over literals) suitable for embedding
  behind `AshSurface.Projectors.JS.ZodGuard`, and return
  `{:ok, binary} | {:error, reason}`. They perform no discovery, touch no
  Ash resources, and validate nothing at render time beyond their own
  inputs (the no-second-discovery contract the schema section carries).

  ## Canonical get-input renderer

  `render_get_input_schema/1` here is canonical; `IdentitySchema`'s variant
  must delegate to or match it (identical sorted strict object output).

  ## Grammar constraint (verified against ZodGuard)

  `ZodGuard` admits exactly: `z`-rooted member/call chains whose argument
  values are literals (string/number/bool/null/array/object) — NO regex
  literals and NO function callbacks. Therefore:

  - `.refine(fn ...)` / `.superRefine(fn ...)` wrappers are NOT admitted
    (function literals are outside the grammar), and
  - the sort constraint renders as `.regex("<pattern>")` with the pattern
    as a double-quoted JSON string — the maximal in-grammar spelling.

  Downstream consumers needing a real `RegExp` at JS runtime must convert
  at the embed site (`new RegExp(pattern)`); the guard's charter is
  syntactic confinement of embedded text, and this renderer stays inside it.
  """

  # DOCUMENTED FALLBACK only: used when the caller supplies no `max_limit`
  # (no Ash-derived bound available). Not an Ash fact; flagged in the receipt.
  @max_limit 500

  @doc """
  Renders the pagination envelope:

      z.object({
        limit: z.number().int().positive().max(500),
        offset: z.number().int().min(0).optional(),
        cursor: z.string().optional()
      }).strict()

  Returns `{:ok, zod_binary}`. Takes no input, so it cannot fail on caller
  data; the error tuple exists for uniformity with `render_sort_schema/1`.
  """
  @spec render_pagination_schema() :: {:ok, String.t()} | {:error, term()}
  def render_pagination_schema do
    zod =
      "z.object({limit: z.number().int().positive().max(#{inspect(@max_limit)}), " <>
        "offset: z.number().int().min(0).optional(), " <>
        "cursor: z.string().optional()}).strict()"

    {:ok, zod}
  end

  @doc """
  Renders the sort envelope for an admitted field set:

      z.string().regex("^(?:[+-]?<f1>|[+-]?<f2>...)(?:,[+-]?(?:<f1>|<f2>...))*$")

  A valid sort string is comma-separated `[+]field` / `-field` tokens where
  every field is a member of `admitted_fields` (a bare field means `+`).
  Empty `admitted_fields` is an error (the regex would admit only the empty
  string); non-identifier field names are refused rather than escaped into
  the pattern (fail closed on untrusted field lists).
  """
  @spec render_sort_schema([String.t()]) :: {:ok, String.t()} | {:error, term()}
  def render_sort_schema(admitted_fields), do: render_sort_schema(admitted_fields, [])

  @doc """
  Sort envelope with options. Prefix class accepts `+`, `-`, `++`, `--`
  (ash_typescript sort modes). `array?: true` emits
  `z.union([<string-form>, z.array(<string-form>)])`.
  """
  @spec render_sort_schema([String.t()], keyword() | map()) ::
          {:ok, String.t()} | {:error, term()}
  def render_sort_schema(admitted_fields, opts) when is_list(admitted_fields) do
    opts = Map.new(opts)

    with :ok <- validate_fields(admitted_fields) do
      alternatives = Enum.join(admitted_fields, "|")
      prefix = "(?:\\+\\+|--|[+-])?"

      pattern =
        "^" <>
          prefix <> "(?:" <> alternatives <> ")(?:," <> prefix <> "(?:" <> alternatives <> "))*$"

      # Regex LITERAL, not a string argument: zod 4 `.regex(str)` throws
      # (core/checks.js calls `def.pattern.test`). Fields are ASCII identifiers
      # and the prefix has no `/`, so the body needs no slash escaping.
      str = "z.string().regex(/#{pattern}/)"

      if Map.get(opts, :array?, false) == true,
        do: {:ok, "z.union([" <> str <> ", z.array(" <> str <> ")])"},
        else: {:ok, str}
    end
  end

  def render_sort_schema(other, _opts), do: {:error, {:sort_fields_not_a_list, other}}

  @doc """
  Renders the pagination input envelope for an action's capabilities.

  Options (map or keyword): `offset?`, `keyset?`, `required?`, `countable?`.

    * offset only: `z.object({limit, offset?, count?}).strict()`
    * keyset only: `z.object({limit, after?, before?, count?}).strict()`
    * both: `z.union([offset, keyset])`
    * `count` appears only when `countable?`
    * not `required?`: the whole envelope gets `.optional()`

  Neither `offset?` nor `keyset?`: `{:error, :pagination_unsupported}`.
  """
  @spec render_pagination_schema(map() | keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_pagination_schema(opts) when is_list(opts),
    do: render_pagination_schema(Map.new(opts))

  def render_pagination_schema(%{} = opts) do
    offset? = Map.get(opts, :offset?, false) == true
    keyset? = Map.get(opts, :keyset?, false) == true

    count =
      if Map.get(opts, :countable?, false) == true,
        do: ["count: z.boolean().optional()"],
        else: []

    with :ok <- validate_max_limit(opts) do
      render_pagination(opts, offset?, keyset?, count)
    end
  end

  defp validate_max_limit(opts) do
    case Map.get(opts, :max_limit) do
      nil -> :ok
      n when is_integer(n) and n > 0 -> :ok
      other -> {:error, {:invalid_max_limit, other}}
    end
  end

  defp render_pagination(opts, offset?, keyset?, count) do
    limit = limit_entry(opts)

    offset = object([limit, "offset: z.number().int().min(0).optional()"] ++ count)

    keyset =
      object([limit, "after: z.string().optional()", "before: z.string().optional()"] ++ count)

    base =
      case {offset?, keyset?} do
        {true, true} -> {:ok, "z.union([#{offset}, #{keyset}])"}
        {true, false} -> {:ok, offset}
        {false, true} -> {:ok, keyset}
        _ -> {:error, :pagination_unsupported}
      end

    with {:ok, zod} <- base do
      if Map.get(opts, :required?, false) == true,
        do: {:ok, zod},
        else: {:ok, zod <> ".optional()"}
    end
  end

  @doc """
  Page-envelope parameters for an action: `%{sort: zod | nil, page: zod | nil}`.
  Get actions yield `nil` for both. Input map keys: `read?`, `get?`,
  `enable_sort?`, `sortable_fields` (resource field names), `pagination`
  (opts for `render_pagination_schema/1`, or nil), `sort_array?`.
  """
  @spec render_query_params(map()) ::
          {:ok, %{sort: String.t() | nil, page: String.t() | nil}} | {:error, term()}
  def render_query_params(%{} = p) do
    if Map.get(p, :get?, false) == true or Map.get(p, :read?, true) != true do
      {:ok, %{sort: nil, page: nil}}
    else
      with {:ok, sort} <- query_sort(p), {:ok, page} <- query_page(Map.get(p, :pagination)) do
        {:ok, %{sort: sort, page: page}}
      end
    end
  end

  defp query_sort(p) do
    fields = Map.get(p, :sortable_fields) || []

    if Map.get(p, :enable_sort?, false) == true and fields != [] do
      render_sort_schema(fields |> Enum.map(&to_string/1) |> Enum.uniq() |> Enum.sort(),
        array?: Map.get(p, :sort_array?, true)
      )
    else
      {:ok, nil}
    end
  end

  defp query_page(nil), do: {:ok, nil}
  defp query_page(false), do: {:ok, nil}
  defp query_page(opts), do: render_pagination_schema(opts)

  @doc "Offset page result: `{results, hasMore, limit, offset, count?, type: \"offset\"}`."
  @spec render_offset_result_schema(String.t(), keyword() | map()) :: {:ok, String.t()}
  def render_offset_result_schema(record_zod, _opts \\ []) when is_binary(record_zod) do
    {:ok,
     object([
       "results: z.array(" <> record_zod <> ")",
       "hasMore: z.boolean()",
       "limit: z.number().int()",
       "offset: z.number().int()",
       "count: z.number().int().nullable().optional()",
       "type: z.literal(\"offset\")"
     ])}
  end

  @doc "Keyset page result with cursors, `type: \"keyset\"`."
  @spec render_keyset_result_schema(String.t(), keyword() | map()) :: {:ok, String.t()}
  def render_keyset_result_schema(record_zod, _opts \\ []) when is_binary(record_zod) do
    {:ok,
     object([
       "results: z.array(" <> record_zod <> ")",
       "hasMore: z.boolean()",
       "limit: z.number().int()",
       "after: z.string().nullable()",
       "before: z.string().nullable()",
       "previousPage: z.string().nullable()",
       "nextPage: z.string().nullable()",
       "count: z.number().int().nullable().optional()",
       "type: z.literal(\"keyset\")"
     ])}
  end

  @doc """
  Page result by flags (`offset?`, `keyset?`, `required?`). Mixed is a union;
  not `required?` is `z.union([z.array(record), page])`. Neither flag:
  `{:error, :pagination_unsupported}`.
  """
  @spec render_page_result_schema(String.t(), keyword() | map()) ::
          {:ok, String.t()} | {:error, term()}
  def render_page_result_schema(record_zod, flags) when is_binary(record_zod) do
    flags = Map.new(flags)
    {:ok, off} = render_offset_result_schema(record_zod)
    {:ok, key} = render_keyset_result_schema(record_zod)

    page =
      case {Map.get(flags, :offset?, false) == true, Map.get(flags, :keyset?, false) == true} do
        {true, true} -> {:ok, "z.union([" <> off <> ", " <> key <> "])"}
        {true, false} -> {:ok, off}
        {false, true} -> {:ok, key}
        _ -> {:error, :pagination_unsupported}
      end

    with {:ok, pg} <- page do
      if Map.get(flags, :required?, false) == true,
        do: {:ok, pg},
        else: {:ok, "z.union([z.array(" <> record_zod <> "), " <> pg <> "])"}
    end
  end

  @doc """
  Typed-query input envelope: strict object over the given parts
  (`input`, `page`, `filter`, `sort` zod strings; nil/absent parts are
  omitted). Every part is optional unless `required: [:input]` names it.
  """
  @spec render_typed_query_input_schema(map(), keyword()) :: {:ok, String.t()}
  def render_typed_query_input_schema(parts, opts \\ []) when is_map(parts) do
    required = Keyword.get(opts, :required, [])

    entries =
      for k <- [:input, :page, :filter, :sort], z = Map.get(parts, k), is_binary(z) do
        z =
          if k in required or String.ends_with?(z, ".optional()"), do: z, else: z <> ".optional()"

        "#{k}: #{z}"
      end

    {:ok, object(entries)}
  end

  @doc """
  Renders the sort envelope from field descriptors, using only sortable
  fields. Descriptors are names, or maps with `name`/`:name` and
  `sortable?`/`:sortable?`. No sortable fields: `{:error, :sort_fields_empty}`.
  """
  @spec render_sort_schema_from_fields([String.t() | map()]) ::
          {:ok, String.t()} | {:error, term()}
  def render_sort_schema_from_fields(fields) when is_list(fields) do
    fields
    |> Enum.flat_map(fn
      name when is_binary(name) -> [name]
      %{} = f -> if flag(f, :sortable?), do: [to_string(attr(f, :name))], else: []
    end)
    |> Enum.uniq()
    |> Enum.sort()
    |> render_sort_schema()
  end

  @doc """
  Renders a get/get_by input: a strict object over `[{name, zod}]` key fields
  (all required). An empty list yields `z.object({}).strict()`.
  """
  @spec render_get_input_schema([{String.t(), String.t()}]) ::
          {:ok, String.t()} | {:error, term()}
  def render_get_input_schema(keys) when is_list(keys) do
    case Enum.find(keys, fn
           {n, z} -> not (is_binary(n) and is_binary(z) and identifier?(n))
           _ -> true
         end) do
      nil ->
        {:ok, object(keys |> Enum.sort() |> Enum.map(fn {n, z} -> "#{n}: #{z}" end))}

      bad ->
        {:error, {:get_key_invalid, bad}}
    end
  end

  @doc """
  Renders a get/get_by result: the record schema, `.nullable()` when the
  action may return nothing (`not_found_error?` false).
  """
  @spec render_get_result_schema(String.t(), keyword() | map()) ::
          {:ok, String.t()} | {:error, term()}
  def render_get_result_schema(record_zod, opts \\ []) when is_binary(record_zod) do
    opts = Map.new(opts)

    if Map.get(opts, :nullable?, false) == true,
      do: {:ok, record_zod <> ".nullable()"},
      else: {:ok, record_zod}
  end

  ## Internals
  defp limit_entry(opts) do
    max = Map.get(opts, :max_limit) || @max_limit
    base = "z.number().int().positive().max(#{max})"

    # ash_typescript config_builder.ex: limit is required only when pagination
    # is required AND the action has no default limit.
    if Map.get(opts, :required?, false) == true and Map.get(opts, :default_limit?, false) != true,
      do: "limit: " <> base,
      else: "limit: " <> base <> ".optional()"
  end

  defp object([]), do: "z.object({}).strict()"
  defp object(entries), do: "z.object({" <> Enum.join(entries, ", ") <> "}).strict()"

  defp attr(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
  defp flag(map, key), do: attr(map, key) == true

  defp validate_fields([]), do: {:error, :sort_fields_empty}

  defp validate_fields(fields) do
    bad = Enum.find(fields, &(not is_binary(&1) or &1 == "" or identifier?(&1) == false))

    if bad,
      do: {:error, {:sort_field_not_identifier, bad}},
      else: :ok
  end

  # A sort field must be a plain ASCII identifier: anything else (dots,
  # dashes, regex metacharacters, unicode) is refused, never pattern-escaped.
  defp identifier?(field), do: field =~ ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/
end
