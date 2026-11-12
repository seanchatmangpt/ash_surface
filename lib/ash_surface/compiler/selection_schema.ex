defmodule AshSurface.Compiler.SelectionSchema do
  @moduledoc """
  Executable field-selection admission (L11): renders the
  `allowed_loads`/`denied_loads` decision as a Zod schema string so a
  consumer's field selection is validated mechanically, not by prose.

  `render_selection_schema/2` subtracts denied fields from the admitted
  set and renders:

      z.object({fields: z.array(z.enum([...]))}).strict()

  An empty admitted set (or a denial that empties it) renders the
  grammar's lawful equivalent of `z.array(z.never())`:

      z.object({fields: z.array(z.never())}).strict()

  Every emitted binary is checked against
  `AshSurface.Projectors.JS.ZodGuard.admit/1` before it is returned;
  a refusal is `{:error, {:zod_guard_refused, reason}}` (fail-closed),
  never a silent pass.

  ## Options

  * `:relationships` - relationship facts (see `RelationshipSchema` facts-shape
    contract) nested as `load`;
  * `:allowed_loads` / `:denied_loads` - lists of relationship paths
    (`"comments"`, `"comments.likes"`). Denial of a path removes it and its
    subtree; allow-listing keeps listed paths, their ancestors and subtrees;
  * `:calculations` - calculation facts nested via
    `CalculationSchema.render_calculation_schema/1` as `calculations`;
  * `:aggregates` - aggregate facts; names render as
    `aggregates: z.array(z.enum(names))` (via `render_aggregate_schemas/1`).

  Field names are embedded as JSON string literals (`Jason.encode!`),
  matching `AshSurface.Compiler.Schema`'s `one_of` enum rendering, so
  non-identifier names are lawful and injection-safe.
  """

  @empty "z.object({fields: z.array(z.never())}).strict()"

  @doc """
  Renders the selection-admission Zod schema for `admitted_fields`
  minus `denied_fields`.

  Returns `{:ok, binary}` (admitted by ZodGuard) or `{:error, reason}`.
  """
  @spec render_selection_schema(list(String.t()), list(String.t()), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def render_selection_schema(admitted_fields, denied_fields, opts \\ []) do
    with :ok <- binary_list?(admitted_fields, :fields_must_be_binaries),
         :ok <- binary_list?(denied_fields, :denied_must_be_binaries) do
      denied = MapSet.new(denied_fields)

      fields =
        admitted_fields
        |> Enum.uniq()
        |> Enum.reject(&MapSet.member?(denied, &1))

      with {:ok, agg_names} <- aggregate_field_names(opts[:aggregates], denied),
           {:ok, load} <- render_load(opts),
           {:ok, extras} <- render_extras(opts) do
        zod = render(Enum.uniq(fields ++ agg_names), load, extras)
        admit(zod)
      end
    end
  end

  # ash_typescript selects aggregates as plain `fields` entries; accept that
  # shape (in addition to the `aggregates` name array).
  defp aggregate_field_names(nil, _denied), do: {:ok, []}

  defp aggregate_field_names(facts, denied) do
    with {:ok, pairs} <- AshSurface.Compiler.CalculationSchema.render_aggregate_schemas(facts) do
      {:ok,
       pairs |> Enum.map(&to_string(elem(&1, 0))) |> Enum.reject(&MapSet.member?(denied, &1))}
    end
  end

  defp render_load(opts) do
    case Keyword.get(opts, :relationships) do
      nil ->
        {:ok, nil}

      rels when is_list(rels) ->
        allowed = Keyword.get(opts, :allowed_loads)
        denied = Keyword.get(opts, :denied_loads, [])

        with :ok <- validate_rels(rels),
             {:ok, kept} <- {:ok, filter_loads(rels, allowed, denied, [])} do
          case kept do
            [] ->
              {:ok, "z.object({}).strict()"}

            kept ->
              AshSurface.Compiler.RelationshipSchema.render_load_object(
                kept,
                Keyword.take(opts, [:max_depth])
              )
          end
        end

      other ->
        {:error, {:relationships_must_be_a_list, other}}
    end
  end

  # Validate before any rel["name"] access; a "." in a name is ambiguous with
  # a nested path in allow/deny matching, so it is refused (typed).
  defp validate_rels(rels) do
    Enum.reduce_while(rels, :ok, fn rel, :ok ->
      case rel do
        %{"name" => name} when is_binary(name) and name != "" ->
          cond do
            String.contains?(name, ".") ->
              {:halt, {:error, {:relationship_name_ambiguous, name}}}

            is_list(rel["relationships"]) ->
              case validate_rels(rel["relationships"]) do
                :ok -> {:cont, :ok}
                err -> {:halt, err}
              end

            true ->
              {:cont, :ok}
          end

        other ->
          {:halt, {:error, {:invalid_relationship, other}}}
      end
    end)
  end

  defp filter_loads(rels, allowed, denied, prefix) do
    rels
    |> Enum.filter(fn rel ->
      path = Enum.join(prefix ++ [rel["name"]], ".")
      not covered?(denied, path) and allowed?(allowed, path)
    end)
    |> Enum.map(fn rel ->
      case rel["relationships"] do
        nested when is_list(nested) ->
          Map.put(
            rel,
            "relationships",
            filter_loads(nested, allowed, denied, prefix ++ [rel["name"]])
          )

        _ ->
          rel
      end
    end)
  end

  defp covered?(paths, path), do: Enum.any?(paths || [], &prefix_of?(&1, path))
  defp allowed?(nil, _path), do: true

  defp allowed?(allowed, path),
    do: Enum.any?(allowed, &(prefix_of?(&1, path) or prefix_of?(path, &1)))

  defp prefix_of?(a, b), do: a == b or String.starts_with?(b, a <> ".")

  defp render_extras(opts) do
    alias AshSurface.Compiler.CalculationSchema

    with {:ok, calc} <-
           extra(
             opts[:calculations],
             fn f -> CalculationSchema.render_calculation_schema(f) end,
             "calculations"
           ),
         {:ok, agg} <- extra(opts[:aggregates], &render_aggs/1, "aggregates") do
      {:ok, Enum.reject([calc, agg], &is_nil/1)}
    end
  end

  defp extra(nil, _fun, _key), do: {:ok, nil}

  defp extra(facts, fun, key) do
    if Code.ensure_loaded?(AshSurface.Compiler.CalculationSchema) do
      with {:ok, zod} <- fun.(facts), do: {:ok, "#{key}: #{zod}.optional()"}
    else
      {:error, {:calculation_schema_unavailable, key}}
    end
  end

  defp render_aggs(facts) do
    with {:ok, pairs} <- AshSurface.Compiler.CalculationSchema.render_aggregate_schemas(facts) do
      case pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() do
        [] -> {:ok, "z.array(z.never())"}
        names -> {:ok, "z.array(z.enum([#{Enum.map_join(names, ", ", &Jason.encode!/1)}]))"}
      end
    end
  end

  defp admit(zod) do
    case AshSurface.Projectors.JS.ZodGuard.admit(zod) do
      {:ok, _, _} -> {:ok, zod}
      {:error, reason} -> {:error, {:zod_guard_refused, reason}}
    end
  end

  defp render([], nil, []), do: @empty

  defp render(fields, load, extras) do
    arr =
      case fields do
        [] -> "z.array(z.never())"
        _ -> "z.array(z.enum([#{Enum.map_join(fields, ", ", &Jason.encode!/1)}]))"
      end

    load_entry = if load, do: ", load: #{load}.optional()", else: ""
    extra_entries = Enum.map_join(extras, "", &(", " <> &1))
    "z.object({fields: #{arr}#{load_entry}#{extra_entries}}).strict()"
  end

  defp binary_list?(fields, reason) when is_list(fields) do
    if Enum.all?(fields, &is_binary/1),
      do: :ok,
      else: {:error, {reason, fields}}
  end

  defp binary_list?(other, reason), do: {:error, {reason, other}}
end
