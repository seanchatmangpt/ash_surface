defmodule AshSurface.Compiler.ErrorSchema do
  @moduledoc """
  Renders the Zod error contract (ash_typescript `validation_error_schemas`
  parity): a base error object, one variant per `IR.ErrorShape` type, a
  `z.discriminatedUnion("type", ...)` over all variants (the `unknown_error`
  variant is the catch-all member), and per-action FieldErrors schemas.

  Wire keys: field-error schemas are `.strict()` (keys formatted with the formatter, as on the
  wire); error objects are `.passthrough()` so handler-added keys survive. Keys equal what
  `AshSurface.Errors.to_errors/2` emits under the configured formatter. The
  default is `:camel_case` (`shortMessage`); pass `formatter: :snake_case |
  :pascal_case | fun` to every renderer to match a non-default formatter.

  Every emitted expression is admitted by `AshSurface.Projectors.JS.ZodGuard`.
  Output is byte-deterministic.
  """

  alias AshSurface.Compiler.ObjectMode
  alias AshSurface.ErrorFormatter
  alias AshSurface.IR.ErrorShape
  alias AshSurface.Projectors.JS.ZodGuard

  @base_fields [
    {"message", "z.string()"},
    {"short_message", "z.string()"},
    {"vars", "z.record(z.string(), z.unknown())"},
    {"fields", "z.array(z.string())"},
    {"path", "z.array(z.union([z.string(), z.number()]))"},
    {"details", "z.record(z.string(), z.unknown()).optional()"}
  ]

  defp base_fields(opts) do
    formatter = Keyword.get(opts, :formatter, :camel_case)

    Enum.map(@base_fields, fn {name, expr} ->
      {ErrorFormatter.format_name(name, formatter), expr}
    end)
  end

  defp type_key(opts),
    do: ErrorFormatter.format_name("type", Keyword.get(opts, :formatter, :camel_case))

  @doc "Base error object (no discriminator)."
  @spec base(keyword()) :: String.t()
  def base(opts \\ []),
    do: "z.object({#{object_body(base_fields(opts))}})#{mode(opts, ".passthrough()")}"

  @doc "Variant object for one error type; unknown types normalise to `unknown_error`."
  @spec variant(term(), keyword()) :: String.t()
  def variant(type, opts \\ []) do
    type = ErrorShape.normalize_type(type)

    "z.object({#{type_key(opts)}: z.literal(#{Jason.encode!(type)}), #{object_body(base_fields(opts))}})#{mode(opts, ".passthrough()")}"
  end

  @doc "`[{type, expression}]` for every type in the closed enum."
  @spec variants(keyword()) :: [{String.t(), String.t()}]
  def variants(opts \\ []), do: Enum.map(ErrorShape.types(), &{&1, variant(&1, opts)})

  @doc """
  The error union. `unknown_error` is emitted last as the catch-all member.
  """
  @spec union(keyword()) :: String.t()
  def union(opts \\ []) do
    {catch_all, rest} =
      Enum.split_with(variants(opts), fn {t, _} -> t == ErrorShape.catch_all() end)

    members = Enum.map_join(rest ++ catch_all, ", ", fn {_t, expr} -> expr end)
    "z.discriminatedUnion(#{Jason.encode!(type_key(opts))}, [#{members}])"
  end

  @doc """
  Per-action FieldErrors schema: each field maps to an optional array of
  messages. Field names are sorted and de-duplicated.
  """
  @spec field_errors([String.t() | atom()], keyword()) :: String.t()
  def field_errors(fields, opts \\ []) when is_list(fields) do
    formatter = Keyword.get(opts, :formatter, :camel_case)

    body =
      fields
      |> Enum.map(&ErrorFormatter.format_name(&1, formatter))
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(&{&1, "z.array(z.string()).optional()"})
      |> object_body()

    "z.object({#{body}})#{mode(opts, ".strict()")}"
  end

  @doc """
  Per-action error carry (render only; IR wiring is a later lane): the response
  error body for one action, `{errors: [<union>], fieldErrors: <FieldErrors>?}`.
  """
  @spec carry([String.t() | atom()], keyword()) :: String.t()
  def carry(fields, opts \\ []) do
    key = ErrorFormatter.format_name("field_errors", Keyword.get(opts, :formatter, :camel_case))

    "z.object({errors: z.array(#{union(opts)}), #{key}: #{field_errors(fields, opts)}.optional()})#{mode(opts, ".strict()")}"
  end

  @doc "Per-action schemas: `%{action => field_errors_expression}` from `%{action => fields}`."
  @spec action_field_errors(%{optional(String.t() | atom()) => [String.t() | atom()]}, keyword()) ::
          %{String.t() => String.t()}
  def action_field_errors(actions, opts \\ []) when is_map(actions) do
    Map.new(actions, fn {action, fields} -> {to_string(action), field_errors(fields, opts)} end)
  end

  @doc """
  Full contract: `{:ok, %{base:, variants:, union:, field_errors:}}` with
  every expression proven by ZodGuard, else `{:error, {:zod_guard_refused, expr, reason}}`.
  """
  @spec render(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def render(actions \\ %{}, opts \\ []) do
    result = %{
      base: base(opts),
      variants: Map.new(variants(opts)),
      union: union(opts),
      field_errors: action_field_errors(actions, opts),
      carry: Map.new(actions, fn {a, f} -> {to_string(a), carry(f, opts)} end)
    }

    exprs =
      [result.base, result.union] ++
        Map.values(result.variants) ++ Map.values(result.field_errors) ++ Map.values(result.carry)

    Enum.find_value(exprs, {:ok, result}, fn expr ->
      case ZodGuard.expression(expr) do
        :ok -> nil
        {:error, reason} -> {:error, {:zod_guard_refused, expr, reason}}
      end
    end)
  end

  # Explicit `:object_mode` opt (:strip | :strict | :passthrough) wins; unset keeps the
  # contract defaults documented above (error objects passthrough, field errors strict).
  defp mode(opts, default) do
    case Keyword.fetch(opts, :object_mode) do
      {:ok, m} -> ObjectMode.suffix(m)
      :error -> default
    end
  end

  defp object_body(fields) do
    Enum.map_join(fields, ", ", fn {name, expr} -> "#{key(name)}: #{expr}" end)
  end

  defp key(name) do
    if Regex.match?(~r/\A[A-Za-z_$][A-Za-z0-9_$]*\z/, name), do: name, else: Jason.encode!(name)
  end
end
