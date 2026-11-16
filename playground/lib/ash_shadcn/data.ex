defmodule AshShadcn.Data do
  @moduledoc """
  Generic data operations for the admin: read (filter/sort/page/load), get, and
  AshPhoenix.Form-backed create/update/destroy plus generic actions. Every call
  carries `actor`, `tenant` and `authorize?` exactly as ash_admin does.
  """
  alias Ash.Resource.Info

  @type ctx :: [actor: term(), tenant: term(), authorize?: boolean()]

  def read(resource, params, ctx) do
    action = action(resource, params["action"], :read)
    limit = clamp(params["limit"], 1, 200, 25)
    offset = clamp(params["offset"], 0, 1_000_000, 0)

    with {:ok, query} <- build_query(resource, action, params, ctx) do
      paginate(query, action, ctx, params, limit, offset)
    end
  end

  @doc """
  Builds the validated read query: action arguments, server-validated `filter` (a map or a JSON
  string, passed through `Ash.Query.filter_input/2`), multi-field `sort` ("a,-b"), `load`
  (fields + relationships) and `calc_args` (arguments for loaded calculations).
  """
  def build_query(resource, action, params, ctx) do
    query = Ash.Query.for_read(resource, action.name, params["args"] || %{}, ctx(ctx))

    with true <- query.valid? or {:error, Ash.Error.to_error_class(query.errors)},
         {:ok, filter} <- parse_filter(params["filter"]),
         :ok <- validate_filter_values(resource, filter),
         {:ok, query} <- apply_filter(query, filter) do
      query = query |> sort(params["sort"]) |> load(resource, params["load"], params["calc_args"])

      if query.valid?,
        do: {:ok, query},
        else: {:error, {:invalid_query, Enum.map(query.errors, &error_entry/1)}}
    end
  end

  defp parse_filter(nil), do: {:ok, nil}
  defp parse_filter(""), do: {:ok, nil}
  defp parse_filter(f) when f == %{}, do: {:ok, nil}
  defp parse_filter(%{} = f), do: {:ok, f}

  defp parse_filter(bin) when is_binary(bin) do
    case Jason.decode(bin) do
      {:ok, %{} = m} -> {:ok, m}
      {:ok, []} -> {:ok, nil}
      _ -> {:error, {:invalid_filter, [%{field: nil, message: "filter is not valid JSON object"}]}}
    end
  end

  defp parse_filter(_), do: {:error, {:invalid_filter, [%{field: nil, message: "filter must be an object"}]}}

  @cast_ops ~w(eq not_eq in less_than less_than_or_equal greater_than greater_than_or_equal lt lte gt gte)

  # filter_input accepts uncastable scalars and fails (or silently matches nothing) later in the
  # data layer; cast every comparison value against its field type so the user gets a field error.
  defp validate_filter_values(_resource, nil), do: :ok

  defp validate_filter_values(resource, filter) do
    case filter_value_errors(resource, filter) do
      [] -> :ok
      errors -> {:error, {:invalid_filter, errors}}
    end
  end

  defp filter_value_errors(resource, %{} = f) do
    Enum.flat_map(f, fn
      {k, list} when k in ["and", "or"] and is_list(list) -> Enum.flat_map(list, &filter_value_errors(resource, &1))
      {"not", %{} = inner} -> filter_value_errors(resource, inner)
      {name, %{} = ops} -> field_errors(resource, to_string(name), ops)
      {name, value} -> field_errors(resource, to_string(name), %{"eq" => value})
    end)
  end

  defp filter_value_errors(_, _), do: []

  defp field_errors(resource, name, ops) do
    attr = Enum.find(Info.public_attributes(resource) ++ Info.public_calculations(resource), &(to_string(&1.name) == name))
    rel = Enum.find(Info.public_relationships(resource), &(to_string(&1.name) == name))

    cond do
      attr -> Enum.flat_map(ops, fn {op, v} -> op_error(attr, name, to_string(op), v) end)
      rel -> filter_value_errors(rel.destination, ops)
      true -> []
    end
  end

  defp op_error(attr, name, op, v) when op in @cast_ops do
    {type, constraints} = if op == "in", do: {{:array, attr.type}, [items: attr.constraints]}, else: {attr.type, attr.constraints}

    case Ash.Type.cast_input(type, v, constraints) do
      {:ok, _} -> []
      {:error, e} -> [%{field: name, message: "#{name} #{op}: " <> cast_message(e)}]
      :error -> [%{field: name, message: "#{name} #{op}: invalid value #{inspect(v)}"}]
    end
  end

  defp op_error(_, _, _, _), do: []

  defp cast_message(e) when is_binary(e), do: e
  defp cast_message(e) when is_list(e), do: e |> Enum.map(&cast_message/1) |> Enum.join(", ")
  defp cast_message(e) when is_exception(e), do: Exception.message(e)
  defp cast_message(e), do: inspect(e)

  defp apply_filter(query, nil), do: {:ok, query}

  defp apply_filter(query, filter) do
    filtered = Ash.Query.filter_input(query, filter)

    if filtered.valid?,
      do: {:ok, filtered},
      else: {:error, {:invalid_filter, Enum.map(filtered.errors, &error_entry/1)}}
  rescue
    e -> {:error, {:invalid_filter, [%{field: nil, message: Exception.message(e)}]}}
  end

  defp error_entry(e) do
    field = e |> Map.get(:field) |> then(&if(is_nil(&1), do: nil, else: to_string(&1)))
    %{field: field, message: e |> Exception.message() |> String.trim()}
  end

  defp paginate(query, action, ctx, params, limit, offset) do
    pag = action.pagination

    cond do
      pag && pag.keyset? && (not pag.offset? or params["after"] || params["before"] || params["mode"] == "keyset") ->
        cursor =
          cond do
            params["after"] not in [nil, ""] -> [after: params["after"]]
            params["before"] not in [nil, ""] -> [before: params["before"]]
            true -> []
          end

        case Ash.read(query, ctx(ctx) ++ [page: [limit: limit, count: pag.countable != false] ++ cursor]) do
          # With both styles enabled Ash answers a cursor-less first page as Offset; its
          # records still carry keyset metadata, so both shapes feed the same reply.
          {:ok, %{results: _, more?: _} = page} -> {:ok, keyset_reply(page, limit, params)}
          {:ok, records} when is_list(records) -> {:ok, list_reply(records, limit, 0)}
          {:error, e} -> {:error, e}
        end

      pag ->
        case Ash.read(query, ctx(ctx) ++ [page: [limit: limit, offset: offset, count: true]]) do
          {:ok, %Ash.Page.Offset{} = page} ->
            {:ok, %{records: Enum.map(page.results, &record(&1, params)), count: page.count, limit: limit, offset: offset, pagination: "offset"}}

          {:ok, records} when is_list(records) -> {:ok, list_reply(records, limit, offset, params)}
          {:error, e} -> {:error, e}
        end

      true ->
        case Ash.read(query, ctx(ctx)) do
          {:ok, records} -> {:ok, list_reply(records, limit, offset, params)}
          {:error, e} -> {:error, e}
        end
    end
  end

  defp keyset_reply(page, limit, params) do
    first = List.first(page.results)
    last = List.last(page.results)

    %{
      records: Enum.map(page.results, &record(&1, params)),
      count: page.count,
      limit: limit,
      offset: 0,
      pagination: "keyset",
      more: page.more? || false,
      next_cursor: last && last.__metadata__[:keyset],
      prev_cursor: first && first.__metadata__[:keyset]
    }
  end

  # Non-paginated action: slice in memory so the UI pager is still correct.
  defp list_reply(records, limit, offset, params \\ %{}) do
    page = records |> Enum.drop(offset) |> Enum.take(limit)
    %{records: Enum.map(page, &record(&1, params)), count: length(records), limit: limit, offset: offset, pagination: "offset"}
  end

  def get(resource, id, params, ctx) do
    action = action(resource, params["action"], :read)

    resource
    |> Ash.Query.for_read(action.name, %{}, ctx(ctx))
    |> Ash.Query.do_filter([{hd(Info.primary_key(resource)), id}])
    |> load(resource, params["load"], params["calc_args"])
    |> Ash.read_one(ctx(ctx))
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, rec} -> {:ok, record(rec, params)}
      {:error, e} -> {:error, e}
    end
  end

  @doc """
  Bulk destroy / update of `ids` through `Ash.bulk_destroy/4` / `Ash.bulk_update/4`.
  Policies are enforced per record (stream strategy); returns counts and error messages.
  """
  def bulk(resource, params, ctx) do
    ids = params["ids"] |> List.wrap() |> Enum.map(&to_string/1) |> Enum.take(1000)
    op = params["op"]

    with {:ok, type} <- bulk_type(op),
         true <- ids != [] or {:error, {:invalid_query, [%{field: "ids", message: "no records selected"}]}} do
      act = action(resource, params["action"], type)
      query = Ash.Query.do_filter(resource, [{hd(Info.primary_key(resource)), [in: ids]}])

      opts =
        ctx(ctx) ++
          [strategy: [:atomic, :stream], return_errors?: true, return_records?: true, notify?: true, stop_on_error?: false]

      result =
        case type do
          :destroy -> Ash.bulk_destroy(query, act.name, %{}, opts)
          :update -> Ash.bulk_update(query, act.name, params["params"] || %{}, opts)
        end

      {:ok,
       %{
         op: op,
         status: to_string(result.status),
         affected: length(result.records || []),
         requested: length(ids),
         errors: Enum.map(result.errors || [], &(&1 |> Exception.message() |> String.trim()))
       }}
    end
  end

  defp bulk_type("destroy"), do: {:ok, :destroy}
  defp bulk_type("update"), do: {:ok, :update}
  defp bulk_type(_), do: {:error, {:invalid_query, [%{field: "op", message: "op must be destroy or update"}]}}

  @max_export 10_000

  @doc "Export the current query (filter/sort/load) as `csv` or `json`; returns `{:ok, {mime, filename, body}}`."
  def export(resource, params, ctx) do
    action = action(resource, params["action"], :read)

    with {:ok, query} <- build_query(resource, action, params, ctx),
         {:ok, format} <- export_format(params["format"]) do
      records =
        query
        |> Ash.stream!(ctx(ctx) ++ [batch_size: 500])
        |> Enum.take(@max_export)
        |> Enum.map(&record(&1, params))

      cols = export_columns(resource, records, params["columns"])
      rows = Enum.map(records, &Map.take(&1, cols))
      name = AshShadcn.Introspect.short(resource)

      case format do
        :json -> {:ok, {"application/json", "#{name}.json", Jason.encode!(rows)}}
        :csv -> {:ok, {"text/csv", "#{name}.csv", csv(cols, rows)}}
      end
    end
  rescue
    e in [Ash.Error.Forbidden, Ash.Error.Invalid, Ash.Error.Unknown] -> {:error, e}
  end

  defp export_format(f) when f in [nil, "", "csv"], do: {:ok, :csv}
  defp export_format("json"), do: {:ok, :json}
  defp export_format(_), do: {:error, {:invalid_query, [%{field: "format", message: "format must be csv or json"}]}}

  defp export_columns(resource, records, spec) do
    available =
      (Info.public_attributes(resource) |> Enum.reject(& &1.sensitive?)) ++
        Info.public_calculations(resource) ++ Info.public_aggregates(resource)

    names = Enum.map(available, &to_string(&1.name))
    present = records |> Enum.flat_map(&Map.keys/1) |> MapSet.new()

    case spec do
      s when is_binary(s) and s != "" ->
        for c <- String.split(s, ",", trim: true), c in names, do: c

      _ ->
        Enum.filter(names, &MapSet.member?(present, &1))
    end
  end

  defp csv(cols, rows) do
    lines = [Enum.map_join(cols, ",", &csv_cell/1) | Enum.map(rows, fn r -> Enum.map_join(cols, ",", &csv_cell(Map.get(r, &1))) end)]
    Enum.join(lines, "\r\n") <> "\r\n"
  end

  defp csv_cell(nil), do: ""
  defp csv_cell(v) when is_binary(v), do: v |> neutralize() |> quote_cell()
  defp csv_cell(v) when is_number(v) or is_boolean(v), do: to_string(v)
  defp csv_cell(v), do: v |> Jason.encode!() |> quote_cell()

  # CSV formula-injection guard: cells starting with = + - @ are prefixed with a quote.
  defp neutralize(<<c, _::binary>> = v) when c in [?=, ?+, ?-, ?@], do: "'" <> v
  defp neutralize(v), do: v

  defp quote_cell(v) do
    if String.contains?(v, [",", "\"", "\n", "\r"]), do: "\"" <> String.replace(v, "\"", "\"\"") <> "\"", else: v
  end

  @doc "Validate (no write) a create/update/destroy form; returns `%{valid, errors}`."
  def validate(resource, params, ctx), do: run_form(resource, params, ctx, :validate)

  @doc "Submit a create/update/destroy form."
  def submit(resource, params, ctx), do: run_form(resource, params, ctx, :submit)

  defp run_form(resource, params, ctx, mode) do
    act = action(resource, params["action"], nil)
    form_params = params["params"] || %{}
    opts = ctx(ctx) ++ [forms: [auto?: true]]

    with {:ok, form} <- build_form(resource, act, params["id"], opts, ctx) do
      form = AshPhoenix.Form.validate(form, form_params)

      case mode do
        :validate ->
          {:ok, %{valid: form.valid?, errors: errors(form)}}

        :submit ->
          case AshPhoenix.Form.submit(form, params: form_params) do
            {:ok, rec} when is_struct(rec) -> {:ok, %{record: record(rec, params), errors: []}}
            {:ok, _} -> {:ok, %{record: nil, errors: []}}
            {:error, form} -> {:ok, %{errors: errors(form), record: nil}}
          end
      end
    end
  end

  defp build_form(resource, %{type: :create} = a, _id, opts, _ctx),
    do: {:ok, AshPhoenix.Form.for_create(resource, a.name, opts)}

  defp build_form(resource, %{type: type} = a, id, opts, ctx) when type in [:update, :destroy] do
    with {:ok, rec} <- fetch(resource, id, ctx, managed_loads(resource, a)) do
      {:ok, apply(AshPhoenix.Form, :"for_#{type}", [rec, a.name, opts])}
    end
  end

  defp build_form(_, _, _, _, _), do: {:error, :unsupported_action_type}

  # Relationships managed by the action must be loaded so nested forms show existing children.
  defp managed_loads(resource, action) do
    for %{change: {Ash.Resource.Change.ManageRelationship, o}} <- Map.get(action, :changes, []),
        Info.relationship(resource, o[:relationship]),
        do: o[:relationship]
  end

  defp fetch(resource, id, ctx, loads) do
    resource
    |> Ash.Query.do_filter([{hd(Info.primary_key(resource)), id}])
    |> Ash.Query.load(loads)
    |> Ash.read_one(ctx(ctx))
    |> case do
      {:ok, nil} -> {:error, :not_found}
      other -> other
    end
  end

  def run_generic(resource, params, ctx) do
    act = action(resource, params["action"], :action)

    resource
    |> Ash.ActionInput.for_action(act.name, params["params"] || %{}, ctx(ctx))
    |> Ash.run_action(ctx(ctx))
    |> case do
      {:ok, result} -> {:ok, %{result: serialize(result)}}
      {:error, e} -> {:error, e}
    end
  end

  # -- helpers -----------------------------------------------------------------

  defp ctx(ctx), do: Keyword.take(ctx, [:actor, :tenant, :authorize?])

  defp action(resource, nil, type), do: Info.primary_action!(resource, type || :read)

  defp action(resource, name, _type) do
    Info.actions(resource) |> Enum.find(&(to_string(&1.name) == name)) ||
      raise ArgumentError, "unknown action #{inspect(name)}"
  end

  defp clamp(v, lo, hi, default) do
    case Integer.parse(to_string(v || "")) do
      {n, _} -> n |> max(lo) |> min(hi)
      :error -> default
    end
  end

  defp sort(query, nil), do: query
  defp sort(query, ""), do: query

  defp sort(query, spec) when is_binary(spec) do
    sorts =
      spec
      |> String.split(",", trim: true)
      |> Enum.flat_map(fn
        "-" <> f -> [{safe_atom(query.resource, f), :desc}]
        f -> [{safe_atom(query.resource, f), :asc}]
      end)
      |> Enum.reject(fn {a, _} -> is_nil(a) end)

    Ash.Query.sort(query, sorts)
  end

  defp load(query, _resource, nil, _), do: query
  defp load(query, _resource, "", _), do: query

  defp load(query, resource, spec, calc_args) when is_binary(spec) do
    calc_args = if is_map(calc_args), do: calc_args, else: %{}

    loads =
      for n <- String.split(spec, ",", trim: true), a = safe_atom(resource, n) do
        case calculation_args(resource, a, calc_args[n]) do
          nil -> a
          args -> {a, args}
        end
      end

    Ash.Query.load(query, loads)
  end

  # Only declared calculation arguments become atoms; blank values are dropped.
  defp calculation_args(resource, name, %{} = given) do
    with %{arguments: [_ | _] = declared} <- Info.calculation(resource, name) do
      for arg <- declared, v = given[to_string(arg.name)], v not in [nil, ""], into: %{}, do: {arg.name, v}
    else
      _ -> nil
    end
  end

  defp calculation_args(_, _, _), do: nil

  # Only names the resource really declares are turned into atoms.
  defp safe_atom(resource, name) do
    names =
      Info.fields(resource) |> Enum.map(& &1.name)
      |> Kernel.++(Enum.map(Info.relationships(resource), & &1.name))

    Enum.find(names, &(to_string(&1) == name))
  end

  def record(rec) when is_struct(rec), do: serialize(rec)

  @doc """
  Serializes for the admin API: sensitive attributes are omitted unless `params["reveal"]` is
  true (the "show sensitive" toggle).
  """
  def record(rec, params) when is_struct(rec) do
    base = serialize(rec)

    if params["reveal"] in ["true", true] do
      base
    else
      Enum.reduce(Info.public_attributes(rec.__struct__), base, fn a, acc ->
        if a.sensitive?, do: Map.delete(acc, to_string(a.name)), else: acc
      end)
    end
  end

  def serialize(%{__struct__: mod} = rec) do
    if Ash.Resource.Info.resource?(mod) do
      fields = Info.public_attributes(mod) ++ Info.public_calculations(mod) ++ Info.public_aggregates(mod)

      base =
        for f <- fields, into: %{} do
          {to_string(f.name), rec |> Map.get(f.name) |> serialize()}
        end

      Enum.reduce(Info.public_relationships(mod), base, fn r, acc ->
        case Map.get(rec, r.name) do
          %Ash.NotLoaded{} -> acc
          value -> Map.put(acc, to_string(r.name), serialize(value))
        end
      end)
    else
      to_plain(rec)
    end
  end

  def serialize(list) when is_list(list), do: Enum.map(list, &serialize/1)
  def serialize(%Ash.NotLoaded{}), do: nil
  def serialize(other), do: to_plain(other)

  defp to_plain(%Decimal{} = d), do: Decimal.to_string(d)
  defp to_plain(%DateTime{} = d), do: DateTime.to_iso8601(d)
  defp to_plain(%NaiveDateTime{} = d), do: NaiveDateTime.to_iso8601(d)
  defp to_plain(%Date{} = d), do: Date.to_iso8601(d)
  defp to_plain(%Ash.CiString{} = s), do: to_string(s)
  defp to_plain(%{__struct__: _} = s), do: s |> Map.from_struct() |> to_plain()
  defp to_plain(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), to_plain(v)} end)
  defp to_plain(l) when is_list(l), do: Enum.map(l, &to_plain/1)
  defp to_plain(t) when is_tuple(t), do: t |> Tuple.to_list() |> to_plain()
  defp to_plain(a) when is_atom(a) and a not in [nil, true, false], do: Atom.to_string(a)
  defp to_plain(other), do: other

  def errors(form) do
    simple =
      form
      |> AshPhoenix.Form.errors(format: :simple)
      |> Enum.map(fn {field, msg} -> %{field: to_string(field), message: msg} end)

    # Errors AshPhoenix cannot map to a field (e.g. policy Forbidden) still must surface.
    if simple == [] and not form.valid?, do: unmapped(form), else: simple
  end

  defp unmapped(form) do
    source_errors =
      case form.source do
        %{errors: errs} when is_list(errs) and errs != [] -> errs
        _ -> List.wrap(form.submit_errors)
      end

    case source_errors do
      [] -> [%{field: "", message: "action failed"}]
      errs -> Enum.map(errs, &%{field: "", message: Exception.message(&1) |> String.trim()})
    end
  end

  @doc "JSON error body for any Ash/other error."
  def error_body(:not_found), do: %{error: "not_found", message: "record not found"}

  def error_body({kind, errors}) when kind in [:invalid_filter, :invalid_query],
    do: %{error: to_string(kind), message: errors |> Enum.map(& &1.message) |> Enum.join("; "), errors: errors}

  def error_body({:unknown_field, f}), do: %{error: "unknown_field", message: "unknown field #{f}"}

  def error_body(e) do
    class = if is_exception(e) and Map.has_key?(e, :class), do: e.class, else: :unknown
    %{error: to_string(class), message: Exception.message(e)}
  rescue
    _ -> %{error: "unknown", message: inspect(e)}
  end
end
