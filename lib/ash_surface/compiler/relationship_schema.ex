defmodule AshSurface.Compiler.RelationshipSchema do
  @moduledoc """
  The relationship/load section: Zod-executable load envelopes from
  relationship facts (ash_typescript nested-field-selection + relationship-load
  parity, lane L20).

  A PURE RENDERER under the no-second-discovery law
  (`AshSurface.Compiler.Schema`): this module performs no
  `Ash.Resource.Info` introspection of its own. Relationship facts arrive as
  arguments in the established serialized shape
  (`AshSurface.Projectors.LiveView` / `semantic.predicates["relationships"]`):

      %{"name" => binary, "destination" => binary, "cardinality" => "one" | "many"}

  ## Facts-shape contract (frozen; string keys)

  `name` (required), `destination`, `cardinality` ("one" | "many"),
  `primitive_fields` (names or `%{"name" => _}`), `relationships` (nested,
  same shape), `pagination` ("offset" | "keyset" | "mixed" | "none"; absent
  keeps the legacy limit/offset + combined `page` arms), `filterable` /
  `sortable` (default true; false omits `filter` / `sort` from the many
  envelope), `exposed` (default true; false omits the relationship from the
  load keys at every depth).

  Divergence note: the `z.literal(true)` shorthand (load everything default)
  is kept alongside the object form; `fields` objects require `.min(1)`.

  WIRING NEED (not this lane's file): a discovery-side producer should feed
  `Ash.Resource.Info.relationships/1` facts (name / destination /
  cardinality) into `render_load_schema/1` where the manifest is assembled.

  ## Denied loads, executable

  The emitted envelope keys on `z.enum([relationship names])`, not
  `z.string()` — a load naming an undeclared relationship fails Zod parse at
  the boundary instead of reaching the query layer.
  """

  alias AshSurface.Compiler.ObjectMode
  alias AshSurface.Projectors.JS.ZodGuard

  @default_max_depth 2

  @int_min1 "z.number().int().min(1)"
  @int_min0 "z.number().int().min(0)"

  @doc """
  Renders the load-envelope zod expression for `relationships`.

  Each relationship fact is
  `%{"name", "destination", "cardinality"}` plus optional
  `"primitive_fields"` (destination primitive field names, strings or
  `%{"name" => _}` maps) and optional nested `"relationships"` (same shape).

  * inner `fields` is `z.array(z.enum(primitive_fields))` when the fact is
    present, `z.array(z.string())` otherwise;
  * cardinality `"one"` -> `{fields, load?}`; `"many"` additionally carries the
    query envelope `filter`/`sort` and pagination, where `limit`/`offset` and
    `page` are mutually exclusive (a strict two-arm `z.union`);
  * nested `load` is expanded statically to `opts[:max_depth]` (default
    #{@default_max_depth}); no `z.lazy`, deeper levels are simply not admitted.

  Returns `{:ok, zod, descriptors}`; `zod` passes `ZodGuard.admit/1`.
  """
  @spec render_load_schema(list(), keyword()) ::
          {:ok, String.t(), %{optional(String.t()) => map()}} | {:error, term()}
  def render_load_schema(relationships, opts \\ [])

  def render_load_schema(relationships, opts) when is_list(relationships) do
    with {:ok, zod} <- render_load_object(relationships, opts) do
      zod = zod <> ".optional()"

      case ZodGuard.admit(zod) do
        {:ok, _, _} -> {:ok, zod, descriptors(relationships)}
        {:error, reason} -> {:error, {:zod_guard_refused, reason}}
      end
    end
  end

  def render_load_schema(_, _), do: {:error, :relationships_must_be_a_list}

  @doc """
  The bare (non-optional) `z.object({<rel>: <envelope>.optional(), ...}).strict()`
  load object; used by `SelectionSchema` for the nested `load` key.
  """
  @spec render_load_object(list(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def render_load_object(relationships, opts \\ [])

  def render_load_object(relationships, opts) when is_list(relationships) do
    max_depth = Keyword.get(opts, :max_depth, @default_max_depth)

    with :ok <- validate_max_depth(max_depth),
         :ok <- validate(relationships) do
      {:ok, load_object(relationships, max_depth, ObjectMode.explicit_suffix(opts[:object_mode]))}
    end
  end

  def render_load_object(_, _), do: {:error, :relationships_must_be_a_list}

  defp validate_max_depth(d) when is_integer(d) and d >= 0, do: :ok
  defp validate_max_depth(d), do: {:error, {:invalid_max_depth, d}}

  defp load_object(relationships, depth, sfx) do
    entries =
      relationships
      |> Enum.reject(&(&1["exposed"] == false))
      |> Enum.map_join(", ", fn rel ->
        "#{Jason.encode!(rel["name"])}: #{envelope(rel, depth, sfx)}.optional()"
      end)

    "z.object({#{entries}})" <> sfx
  end

  defp envelope(rel, depth, sfx) do
    fields = "fields: #{fields_schema(rel["primitive_fields"])}"
    load = nested_load(rel, depth, sfx)

    inner =
      case rel["cardinality"] do
        "one" ->
          obj([fields | load], sfx)

        _many ->
          base =
            [fields | load] ++
              if(rel["filterable"] == false,
                do: [],
                else: ["filter: #{filter_schema(rel["primitive_fields"])}.optional()"]
              ) ++
              if(rel["sortable"] == false, do: [], else: ["sort: #{sort_schema()}.optional()"]) ++
              ["count: z.boolean().optional()"]

          many_arms(rel["pagination"], base, sfx)
      end

    "z.union([z.literal(true), #{inner}])"
  end

  defp filter_schema([_ | _] = fields) do
    names = fields |> Enum.map(&field_name/1) |> Enum.uniq() |> Enum.sort()
    "z.partialRecord(z.enum([#{enum_literals(names)}]), z.unknown())"
  end

  defp filter_schema(_), do: "z.record(z.string(), z.unknown())"

  defp sort_schema, do: "z.union([z.string(), z.array(z.string())])"

  # limit/offset and page are mutually exclusive. The base (which carries
  # the nested load) is rendered ONCE in a strict object declaring every key;
  # exclusivity is an intersection with passthrough guards, so nesting does
  # not duplicate the base per arm (no 2^d blowup).
  defp many_arms("none", base, sfx), do: obj(base, sfx)

  defp many_arms("keyset", base, sfx),
    do: obj(base ++ ["page: #{keyset_page(sfx)}.optional()"], sfx)

  defp many_arms(pagination, base, sfx) do
    page =
      case pagination do
        "offset" -> offset_page(sfx)
        "mixed" -> "z.union([#{offset_page(sfx)}, #{keyset_page(sfx)}])"
        _legacy -> page_schema(sfx)
      end

    all =
      obj(
        base ++
          [
            "limit: #{@int_min1}.optional()",
            "offset: #{@int_min0}.optional()",
            "page: #{page}.optional()"
          ],
        sfx
      )

    # Guards are strict too (zod 4 intersection reports an unknown key only
    # when BOTH sides reject it); they name the base keys with z.unknown() so
    # they constrain only the limit/offset-vs-page exclusivity.
    shared = Enum.map(base, fn entry -> entry |> String.split(":", parts: 2) |> hd() end)
    unknowns = Enum.map(shared, &"#{&1}: z.unknown().optional()")

    exclusive =
      "z.union([" <>
        obj(
          unknowns ++
            [
              "limit: z.unknown().optional()",
              "offset: z.unknown().optional()",
              "page: z.never().optional()"
            ],
          sfx
        ) <>
        ", " <>
        obj(
          unknowns ++
            [
              "limit: z.never().optional()",
              "offset: z.never().optional()",
              "page: z.unknown().optional()"
            ],
          sfx
        ) <>
        "])"

    "z.intersection(#{all}, #{exclusive})"
  end

  defp obj(entries, sfx), do: "z.object({#{Enum.join(entries, ", ")}})" <> sfx

  defp nested_load(rel, depth, sfx) do
    case rel["relationships"] do
      [_ | _] = nested when depth > 0 ->
        ["load: #{load_object(nested, depth - 1, sfx)}.optional()"]

      _ ->
        []
    end
  end

  defp offset_page(sfx),
    do:
      "z.object({limit: #{@int_min1}.optional(), offset: #{@int_min0}.optional(), count: z.boolean().optional()})" <>
        sfx

  defp keyset_page(sfx),
    do:
      "z.object({limit: #{@int_min1}.optional(), after: z.string().optional(), before: z.string().optional(), count: z.boolean().optional()})" <>
        sfx

  defp page_schema(sfx) do
    "z.object({limit: #{@int_min1}.optional(), offset: #{@int_min0}.optional(), " <>
      "after: z.string().optional(), before: z.string().optional()})" <> sfx
  end

  defp fields_schema(nil), do: "z.array(z.string()).min(1)"

  defp fields_schema(list) when is_list(list) do
    case list |> Enum.map(&field_name/1) |> Enum.uniq() |> Enum.sort() do
      [] -> "z.array(z.never()).min(1)"
      names -> "z.array(z.enum([#{enum_literals(names)}])).min(1)"
    end
  end

  defp field_name(%{"name" => name}), do: name
  defp field_name(name), do: name

  @doc """
  Descriptor map: relationship name => `%{cardinality: "one"|"many",
  destination: binary}`. The shape a JS projector consumes as a typed lookup.
  """
  @spec descriptors(list()) :: %{
          optional(String.t()) => %{cardinality: String.t(), destination: String.t()}
        }
  def descriptors(relationships) when is_list(relationships) do
    relationships
    |> Enum.reject(&(&1["exposed"] == false))
    |> Map.new(fn rel ->
      {rel["name"],
       %{
         cardinality: rel["cardinality"] || "many",
         destination: rel["destination"]
       }}
    end)
  end

  @doc """
  JSDoc-typed rendering of the descriptor map (plain comment lines; not Zod,
  never routed through ZodGuard).
  """
  @spec jsdoc(list()) :: String.t()
  def jsdoc(relationships) when is_list(relationships) do
    relationships
    |> Enum.reject(&(&1["exposed"] == false))
    |> Enum.map_join("\n", fn rel ->
      "// @typedef {#{cardinality_type(rel)}Load} #{comment_safe(rel["name"])}Load — destination #{comment_safe(rel["destination"])}"
    end)
  end

  # Names land in a line comment: strip comment terminators and line breaks.
  defp comment_safe(text) do
    text
    |> to_string()
    |> String.replace("*/", "*\\/")
    |> String.replace(~r/[\r\n\x{2028}\x{2029}]/u, " ")
  end

  defp cardinality_type(%{"cardinality" => "one"}), do: "Single"
  defp cardinality_type(_), do: "Many"

  defp validate([]), do: {:error, :no_relationships}

  defp validate(relationships) do
    Enum.reduce_while(relationships, {:ok, MapSet.new()}, fn rel, {:ok, seen} ->
      cond do
        not is_map(rel) or not is_binary(rel["name"]) or rel["name"] == "" ->
          {:halt, {:error, {:relationship_without_name, rel}}}

        MapSet.member?(seen, rel["name"]) ->
          {:halt, {:error, {:duplicate_relationship, rel["name"]}}}

        not valid_primitive_fields?(rel["primitive_fields"]) ->
          {:halt, {:error, {:invalid_primitive_fields, rel["name"]}}}

        rel["pagination"] not in [nil, "offset", "keyset", "mixed", "none"] ->
          {:halt, {:error, {:invalid_pagination, rel["name"]}}}

        Enum.any?(~w(filterable sortable exposed), &(Map.get(rel, &1) not in [nil, true, false])) ->
          {:halt, {:error, {:invalid_flag, rel["name"]}}}

        not valid_nested?(rel["relationships"]) ->
          {:halt, {:error, {:invalid_nested_relationships, rel["name"]}}}

        true ->
          {:cont, {:ok, MapSet.put(seen, rel["name"])}}
      end
    end)
    |> case do
      {:ok, _seen} -> :ok
      error -> error
    end
  end

  defp valid_primitive_fields?(nil), do: true

  defp valid_primitive_fields?(list) when is_list(list),
    do: Enum.all?(list, &(is_binary(field_name(&1)) and field_name(&1) != ""))

  defp valid_primitive_fields?(_), do: false

  defp valid_nested?(nil), do: true
  defp valid_nested?([]), do: true
  defp valid_nested?(list) when is_list(list), do: validate(list) == :ok
  defp valid_nested?(_), do: false

  # JSON-escaped enum literals — Jason escaping is the same grammar ZodGuard
  # tokenizes (double-quoted JSON strings).
  defp enum_literal(name), do: Jason.encode!(name)

  defp enum_literals(names), do: Enum.map_join(names, ", ", &enum_literal/1)
end
