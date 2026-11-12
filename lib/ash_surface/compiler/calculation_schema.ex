# Lane L22 (v26.11.11). Calculation + aggregate capability parity with
# ash_typescript: their typed-argument calculations and loadable aggregates
# project to a Zod-executable load envelope plus nullability metadata.
#
# SHARED CONTRACT: this module's argument fragments reuse the frozen
# schema.ex/union_schema.ex ordering (base -> enum/min/max/length -> regex ->
# optional/nullable) with the same disclosed divergence as L21: `match`
# renders as `.regex("<json string>")` (string call argument) rather than a
# regex literal, because `AshSurface.Projectors.JS.ZodGuard` admits string
# literals and refuses regex literals — "must pass ZodGuard" wins over
# byte-parity.

defmodule AshSurface.Compiler.CalculationSchema do
  @moduledoc """
  Renders the calculation-load envelope and aggregate nullability metadata
  from calculation/aggregate facts (ash_typescript parity).

  ## Calculation facts

  Each calculation is

      %{
        name: String.t(),
        arguments: [%{name: String.t(), kind: base kind atom,
                      constraints: map()}],
        return_kind: base kind atom
      }

  (atom- or string-keyed; `arguments` defaults to `[]`.)

  `render_calculation_schema/1` emits

      z.object({"<name>": z.object({args: z.object({<arg>: <fragment>, ...})
                                .strict().optional()}).strict().optional(), ...}).strict()

  so any subset of calculations loads, an unknown calculation fails at
  `.strict()`, each calculation is bound to its own args schema, and a bad
  or extra argument fails via `.strict()` — a calculation with zero
  arguments still validates with `args` omitted.

  ## Aggregate facts

  Each aggregate is `%{name: String.t(), kind: aggregate kind atom,
  field: String.t() | nil}`. `render_aggregate_metadata/1` is NOT zod: it
  emits JSDoc lines for the output descriptor surfacing `T | null`
  semantics (nullability lives in JSDoc, not types):

  - `:count` → `{number}` (never null)
  - `:exists` → `{boolean}` (never null)
  - `:avg | :max | :min | :sum | :first` → `{T | null}` (empty relationship)
  - `:list` → `{T[]}` (possibly empty, never null)

  Every zod binary returned is checked against
  `AshSurface.Projectors.JS.ZodGuard.admit/1` (fail-closed); names are
  embedded as JSON string literals, so untrusted name lists are
  injection-safe and non-identifier names are lawful keys.
  """

  alias AshSurface.Compiler.ObjectMode
  alias AshSurface.Compiler.ZodType
  alias AshSurface.Projectors.JS.ZodGuard

  @aggregate_kinds ~w(count avg max min sum first last exists list custom)a
  @field_kinds [:first, :last, :min, :max]

  @doc """
  Renders the calculation-load envelope for `calc_facts`.

  Returns `{:ok, binary}` (admitted by ZodGuard) or `{:error, reason}`.
  """
  @spec render_calculation_schema(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_calculation_schema(calc_facts, opts \\ [])

  def render_calculation_schema(calc_facts, opts) when is_list(calc_facts) do
    with :ok <- validate_calcs(calc_facts) do
      zod = do_render_calcs(calc_facts, ObjectMode.explicit_suffix(opts[:object_mode]))

      case ZodGuard.admit(zod) do
        {:ok, _, _} -> {:ok, zod}
        {:error, reason} -> {:error, {:zod_guard_refused, reason}}
      end
    end
  end

  def render_calculation_schema(other, _opts), do: {:error, {:calc_facts_not_a_list, other}}

  @doc """
  Renders JSDoc nullability lines for `agg_facts` (output descriptor
  metadata; not a zod expression).

  Returns `{:ok, [line]}` or `{:error, reason}`.
  """
  @spec render_aggregate_metadata(list()) :: {:ok, [String.t()]} | {:error, term()}
  def render_aggregate_metadata(agg_facts) when is_list(agg_facts) do
    with :ok <- validate_aggs(agg_facts) do
      {:ok, Enum.map(agg_facts, &agg_line/1)}
    end
  end

  def render_aggregate_metadata(other), do: {:error, {:agg_facts_not_a_list, other}}

  ## Calculation rendering

  defp validate_calcs([]), do: {:error, :calc_facts_empty}

  defp validate_calcs(facts) do
    names = Enum.map(facts, &calc_field(&1, :name))

    cond do
      bad = Enum.find(names, &(not is_binary(&1) or &1 == "")) ->
        {:error, {:calc_name_invalid, bad}}

      names != Enum.uniq(names) ->
        {:error, {:calc_name_duplicate, duplicate(names)}}

      true ->
        validate_args(facts)
    end
  end

  defp validate_args(facts) do
    facts
    |> Enum.find_value(fn fact ->
      args = calc_field(fact, :arguments) || []
      name = calc_field(fact, :name)
      arg_names = if is_list(args), do: Enum.map(args, &arg_field(&1, :name))

      cond do
        not is_list(args) ->
          {:error, {:calc_arguments_not_a_list, name, args}}

        arg = Enum.find(args, &(not is_binary(arg_field(&1, :name)))) ->
          {:error, {:arg_name_invalid, name, arg}}

        arg_names != Enum.uniq(arg_names) ->
          {:error, {:arg_name_duplicate, name, duplicate(arg_names)}}

        true ->
          nil
      end
    end)
    |> case do
      nil -> :ok
      error -> error
    end
  end

  # Per-calculation keyed object: every calculation key is optional (loading
  # a subset is lawful), each bound to its OWN args envelope, and `.strict()`
  # rejects unknown calculation names. No cross-calc arg leakage (M5) and no
  # exhaustive-key requirement (H1: zod 4 enum-keyed z.record is exhaustive).
  defp do_render_calcs(raw_facts, sfx) do
    entries =
      Enum.map_join(raw_facts, ", ", fn fact ->
        args = calc_field(fact, :arguments) || []

        args_obj =
          case args do
            [] ->
              "z.object({})" <> sfx

            _ ->
              fragments =
                Enum.map_join(args, ", ", fn arg ->
                  "#{Jason.encode!(arg_field(arg, :name))}: #{arg_fragment(arg)}"
                end)

              "z.object({#{fragments}})" <> sfx
          end

        optional = if Enum.any?(args, &arg_required?/1), do: "", else: ".optional()"

        obj = "z.object({args: #{args_obj}#{optional}#{fields_member(fact)}})" <> sfx

        # Bare-array shorthand (`calc: ["id", ...]`, ash_typescript parity):
        # only for calculations with declared result fields and no required
        # args; required-arg calculations keep the strict object form only.
        body =
          case {optional, shorthand_fields(fact)} do
            {".optional()", names} when is_binary(names) ->
              "z.union([z.array(z.enum([#{names}])), #{obj}])"

            _ ->
              obj
          end

        "#{Jason.encode!(calc_field(fact, :name))}: " <> body <> ".optional()"
      end)

    "z.object({#{entries}})" <> sfx
  end

  # Argument fragment: delegated wholesale to ZodType.fragment/1 (no private
  # kind table here). allow_nil? may ride the arg or its constraints map.
  defp arg_fragment(arg) do
    constraints = arg_field(arg, :constraints) || %{}

    allow_nil? =
      arg_field(arg, :allow_nil?) == true or
        Map.get(constraints, "allow_nil?") == true or
        Map.get(constraints, :allow_nil?) == true

    ZodType.fragment(%{
      "type" => %{"kind" => kind_string(arg_field(arg, :kind))},
      "constraints" => stringify(constraints),
      "allow_nil?" => allow_nil?,
      "optional" => not arg_required?(arg)
    })
  end

  # An argument is required when it has no default and does not allow nil.
  # An explicit `required` fact wins; otherwise derived from allow_nil?/
  # has_default/default.
  defp arg_required?(arg) do
    constraints = arg_field(arg, :constraints) || %{}

    case Map.get(arg, :required, Map.get(arg, "required")) do
      bool when is_boolean(bool) ->
        bool

      _ ->
        not (arg_allow_nil?(arg, constraints) or has_default?(arg))
    end
  end

  defp arg_allow_nil?(arg, constraints) do
    arg_field(arg, :allow_nil?) == true or Map.get(constraints, "allow_nil?") == true or
      Map.get(constraints, :allow_nil?) == true
  end

  defp has_default?(arg) do
    arg_field(arg, :has_default) == true or arg_field(arg, :has_default?) == true or
      Map.has_key?(arg, :default) or Map.has_key?(arg, "default")
  end

  defp kind_string(kind) when is_atom(kind) and not is_nil(kind), do: Atom.to_string(kind)
  defp kind_string(kind) when is_binary(kind), do: kind
  defp kind_string(_), do: "unknown"

  defp stringify(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)

  defp shorthand_fields(fact) do
    case calc_field(fact, :fields) do
      [_ | _] = fields ->
        fields |> Enum.map(&to_string/1) |> Enum.sort() |> Enum.map_join(", ", &Jason.encode!/1)

      _ ->
        nil
    end
  end

  # `fields` envelope member: optional array of the calculation's selectable
  # result field names (composite returns), omitted when none declared.
  defp fields_member(fact) do
    case calc_field(fact, :fields) do
      [_ | _] = fields ->
        names =
          fields |> Enum.map(&to_string/1) |> Enum.sort() |> Enum.map_join(", ", &Jason.encode!/1)

        ", fields: z.array(z.enum([#{names}])).optional()"

      _ ->
        ""
    end
  end

  @doc """
  Aggregate result-kind table: `kind => zod result kind`, with `nil` where the
  result kind is the aggregated field's own kind (first/min/max/list).
  """
  @spec result_kinds() :: %{atom() => String.t() | nil}
  def result_kinds do
    %{
      count: "integer",
      sum: "float",
      avg: "float",
      exists: "boolean",
      first: nil,
      last: nil,
      min: nil,
      max: nil,
      list: nil,
      custom: "any"
    }
  end

  @doc """
  Renders each aggregate's result schema from `ZodType` fragments:
  count int, sum/avg number, exists boolean, first/min/max field kind
  nullable, list array of field kind. Facts carry `field_kind` (default
  `"unknown"`). Returns `{:ok, [{name, zod}]}` (ZodGuard-admitted).
  """
  @spec render_aggregate_schemas(list()) :: {:ok, [{String.t(), String.t()}]} | {:error, term()}
  def render_aggregate_schemas(agg_facts) when is_list(agg_facts) do
    with :ok <- validate_aggs(agg_facts) do
      agg_facts
      |> Enum.reduce_while({:ok, []}, fn fact, {:ok, acc} ->
        zod = agg_zod(fact)

        case ZodGuard.admit(zod) do
          {:ok, _, _} -> {:cont, {:ok, [{agg_field(fact, :name), zod} | acc]}}
          {:error, reason} -> {:halt, {:error, {:zod_guard_refused, reason}}}
        end
      end)
      |> case do
        {:ok, acc} -> {:ok, Enum.reverse(acc)}
        error -> error
      end
    end
  end

  def render_aggregate_schemas(other), do: {:error, {:agg_facts_not_a_list, other}}

  defp agg_zod(fact) do
    kind = agg_field(fact, :kind)
    field_kind = kind_string(agg_field(fact, :field_kind))
    nil? = agg_field(fact, :allow_nil?) == true

    case kind do
      :list ->
        "z.array(#{complex(fact) || ZodType.fragment(frag(field_kind, false))})"

      k when k in @field_kinds ->
        case complex(fact) do
          nil -> ZodType.fragment(frag(field_kind, true))
          zod -> if k in [:first, :last], do: zod <> ".nullable()", else: zod
        end

      :custom ->
        "z.any()" <> if(nil?, do: ".nullable()", else: "")

      k when k in [:sum, :avg] ->
        ZodType.fragment(frag(Map.fetch!(result_kinds(), k), true))

      k ->
        ZodType.fragment(frag(Map.fetch!(result_kinds(), k), false))
    end
  end

  # Complex (embedded/union/resource) field definitions delegate to sibling
  # renderers when they are present.
  defp complex(fact) do
    defn = agg_field(fact, :field_definition)

    cond do
      not is_map(defn) ->
        nil

      is_list(union = agg_field(fact, :union_facts)) ->
        case AshSurface.Compiler.UnionSchema.render_union_schema_admitted(union) do
          {:ok, zod} -> zod
          _ -> nil
        end

      true ->
        case AshSurface.Compiler.EmbeddedSchema.render(stringify_deep(defn), []) do
          {:ok, zod} -> zod
          _ -> nil
        end
    end
  end

  defp stringify_deep(%{} = m),
    do: Map.new(m, fn {k, v} -> {to_string(k), stringify_deep(v)} end)

  defp stringify_deep(l) when is_list(l), do: Enum.map(l, &stringify_deep/1)

  defp stringify_deep(a) when is_atom(a) and not is_nil(a) and not is_boolean(a),
    do: Atom.to_string(a)

  defp stringify_deep(v), do: v

  @doc """
  Renders each calculation's RESULT schema: `return_kind` through
  `ZodType.fragment/1`, nullable when `allow_nil?`; `return_ref` (a
  resource module name) renders the generic resource record
  `z.record(z.string(), z.unknown())` (sibling-schema references are not
  expressible in the ZodGuard grammar), nullable per `allow_nil?`.
  Returns `{:ok, [{name, zod}]}` (ZodGuard-admitted) or `{:error, reason}`.
  """
  @spec render_calculation_result_schemas(list()) ::
          {:ok, [{String.t(), String.t()}]} | {:error, term()}
  def render_calculation_result_schemas(calc_facts) when is_list(calc_facts) do
    with :ok <- validate_calcs(calc_facts) do
      Enum.reduce_while(calc_facts, {:ok, []}, fn fact, {:ok, acc} ->
        zod = calc_result_zod(fact)

        case ZodGuard.admit(zod) do
          {:ok, _, _} -> {:cont, {:ok, [{calc_field(fact, :name), zod} | acc]}}
          {:error, reason} -> {:halt, {:error, {:zod_guard_refused, reason}}}
        end
      end)
      |> case do
        {:ok, acc} -> {:ok, Enum.reverse(acc)}
        error -> error
      end
    end
  end

  def render_calculation_result_schemas(other), do: {:error, {:calc_facts_not_a_list, other}}

  defp calc_result_zod(fact) do
    nil? = calc_field(fact, :allow_nil?) == true

    case calc_field(fact, :return_ref) do
      ref when is_binary(ref) and ref != "" ->
        # Resource-returning calculation: shape is the generic resource record
        # (references to sibling schemas are not expressible in the guard
        # grammar), nullable per allow_nil?.
        "z.record(z.string(), z.unknown())" <> if(nil?, do: ".nullable()", else: "")

      _ ->
        ZodType.fragment(frag(kind_string(calc_field(fact, :return_kind)), nil?))
    end
  end

  defp frag(kind, nullable?),
    do: %{"type" => %{"kind" => kind}, "constraints" => %{}, "allow_nil?" => nullable?}

  ## Aggregate metadata

  defp validate_aggs([]), do: {:error, :agg_facts_empty}

  defp validate_aggs(facts) do
    names = Enum.map(facts, &agg_field(&1, :name))
    kinds = Enum.map(facts, &agg_field(&1, :kind))

    cond do
      bad = Enum.find(names, &(not is_binary(&1) or &1 == "")) ->
        {:error, {:agg_name_invalid, bad}}

      names != Enum.uniq(names) ->
        {:error, {:agg_name_duplicate, duplicate(names)}}

      kind = Enum.find(kinds, &(&1 not in @aggregate_kinds)) ->
        {:error, {:aggregate_kind_unknown, kind}}

      true ->
        :ok
    end
  end

  defp agg_line(fact) do
    name = agg_field(fact, :name)
    kind = agg_field(fact, :kind)
    field = agg_field(fact, :field)
    over = if is_binary(field), do: field, else: "relationship"

    {type, note} =
      case kind do
        :count -> {"number", "never null"}
        :exists -> {"boolean", "never null"}
        :list -> {"T[]", "possibly empty, never null"}
        :custom -> {"any", "custom aggregate; null per allow_nil?"}
        _ -> {"T | null", "null when the relationship is empty"}
      end

    " * @property {#{type}} #{comment_safe(name)} aggregate #{kind} over #{comment_safe(over)} — #{note}"
  end

  ## Shared helpers

  # Names are interpolated into comments: neutralize comment terminators and
  # line breaks so a hostile name cannot break out of the JSDoc block.
  defp comment_safe(text) do
    text
    |> String.replace("*/", "*\\/")
    |> String.replace(~r/[\r\n\x{2028}\x{2029}]/u, " ")
  end

  # Atom- or string-keyed facts (serialized discovery arrives string-keyed).
  defp calc_field(map, key) when is_map(map), do: fetch(map, key)
  defp arg_field(map, key) when is_map(map), do: fetch(map, key)
  defp agg_field(map, key) when is_map(map), do: fetch(map, key)

  defp fetch(map, key), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp duplicate(names) do
    names |> Enum.frequencies() |> Enum.find(fn {_n, c} -> c > 1 end) |> elem(0)
  end
end
