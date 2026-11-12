defmodule AshSurface.Compiler.ConstraintValidator do
  @moduledoc """
  Elixir oracle for the constraint vocabulary `AshSurface.Compiler.ZodType.fragment/2`
  renders into Zod 4: `validate(definition, value)` returns `:ok` or
  `{:error, issues}` where each issue is `%{code, path, message}` with
  zod-4-compatible codes (`invalid_type`, `too_small`, `too_big`,
  `invalid_format`, `invalid_value`).

  Library oracle for conformance Tier B; it is not called from the runtime
  path. Values are JSON-shaped (string-keyed maps, lists, binaries, numbers,
  booleans, `nil`). The sentinel `:missing` stands for JS `undefined`
  (an omitted key).
  """

  alias AshSurface.Compiler.ZodType

  @numeric ~w(integer float)
  @string_length_kinds ~w(string ci_string binary)
  @length_kinds ~w(string ci_string binary array)
  @string_kinds ~w(string ci_string uuid uuid_v7 date time time_usec utc_datetime utc_datetime_usec datetime
                   naive_datetime duration binary atom decimal)
  @any_kinds ~w(term file function any)
  @record_kinds ~w(map keyword tuple struct)
  @datetime_kinds ~w(utc_datetime utc_datetime_usec datetime naive_datetime)

  @date_src "(?:(?:\\d\\d[2468][048]|\\d\\d[13579][26]|\\d\\d0[48]|[02468][048]00|[13579][26]00)-02-29|" <>
              "\\d{4}-(?:(?:0[13578]|1[02])-(?:0[1-9]|[12]\\d|3[01])|(?:0[469]|11)-(?:0[1-9]|[12]\\d|30)|(?:02)-(?:0[1-9]|1\\d|2[0-8])))"
  @hhmm "(?:[01]\\d|2[0-3]):[0-5]\\d"
  @time_src "#{@hhmm}(?::[0-5]\\d(?:\\.\\d+)?)?"
  # z.guid(): any 8-4-4-4-12 hex (what Ecto/Ash accept), not RFC 9562 version/variant only.
  # zod 4 z.uuid(): RFC 9562 version 1-8, variant 8-b, plus nil/max UUIDs.
  @uuid_v7_re ~r/\A(?:[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}|00000000-0000-0000-0000-000000000000|[fF]{8}-[fF]{4}-[fF]{4}-[fF]{4}-[fF]{12})\z/
  @uuid_re ~r/\A[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\z/
  @duration_re ~r/\AP(?:(\d+W)|(?!.*W)(?=\d|T\d)(\d+Y)?(\d+M)?(\d+D)?(T(?=\d)(\d+H)?(\d+M)?(\d+([.,]\d+)?S)?)?)\z/s

  @spec validate(map(), term()) :: :ok | {:error, [map()]}
  def validate(definition, value) do
    case check(definition, value, []) do
      [] -> :ok
      issues -> {:error, issues}
    end
  end

  @doc "True when `validate/2` returns `:ok`."
  def valid?(definition, value), do: validate(definition, value) == :ok

  # ---- core -------------------------------------------------------------

  defp check(definition, value, path) do
    # atoms JSON-encode to strings (Ash atom values), not nil/booleans/the :missing sentinel
    value =
      if is_atom(value) and value not in [nil, true, false, :missing],
        do: Atom.to_string(value),
        else: value

    cond do
      value == :missing and omittable?(definition) -> []
      value == nil and nullable?(definition) -> []
      true -> check_kind(kind_of(definition), definition, constraints(definition), value, path)
    end
  end

  defp check_kind(nil, _d, _c, _v, _p), do: []
  defp check_kind(kind, _d, _c, _v, _p) when kind in @any_kinds, do: []
  # kinds outside the ZodType table render z.unknown()
  defp check_kind(kind, d, c, v, p) when is_binary(kind) do
    if kind in ZodType.kinds(), do: check_known(kind, d, c, v, p), else: []
  end

  defp check_known(kind, d, c, v, p) do
    case one_of(c) do
      [] -> by_kind(kind, d, c, v, p)
      values -> enum_check(kind, values, v, p)
    end
  end

  defp enum_check(kind, values, v, p) when kind in @numeric do
    cond do
      not is_number(v) -> [issue("invalid_type", p, "Invalid input")]
      Enum.any?(values, &(is_number(&1) and &1 == v)) -> []
      true -> [issue("invalid_value", p, "Invalid input")]
    end
  end

  defp enum_check(_kind, values, v, p) do
    cond do
      not is_binary(v) -> [issue("invalid_type", p, "Invalid input")]
      v in Enum.map(values, &to_string/1) -> []
      true -> [issue("invalid_value", p, "Invalid option")]
    end
  end

  defp by_kind(kind, _d, c, v, p) when kind in @numeric do
    cond do
      not is_number(v) -> [issue("invalid_type", p, "expected number")]
      kind == "integer" and not safe_integer?(v) -> [issue("invalid_type", p, "expected int")]
      true -> numeric_bounds(c, v, p)
    end
  end

  defp by_kind("boolean", _d, _c, v, p), do: if(is_boolean(v), do: [], else: [type(p)])

  defp by_kind("vector", _d, _c, v, p),
    do: array_check(v, p, nil, %{}, fn x, ip -> number_only(x, ip) end)

  defp by_kind("array", d, c, v, p) do
    item = items_of(d)
    array_check(v, p, item, c, fn x, ip -> if item, do: check(item, x, ip), else: [] end)
  end

  defp by_kind(kind, _d, _c, v, p) when kind in @record_kinds,
    do: if(is_map(v) and not is_struct(v), do: [], else: [type(p)])

  defp by_kind(kind, d, c, v, p) do
    cond do
      not is_binary(v) ->
        [type(p)]

      kind == "enum" ->
        case enum_values(d) do
          [_ | _] = vals ->
            if v in Enum.map(vals, &to_string/1),
              do: [],
              else: [issue("invalid_value", p, "Invalid option")]

          _ ->
            []
        end

      true ->
        format(kind, v, p) ++ string_bounds(kind, c, v, p) ++ regex_check(kind, c, v, p)
    end
  end

  defp number_only(x, p), do: if(is_number(x), do: [], else: [type(p)])

  defp array_check(v, p, _item, c, item_fn) do
    if is_list(v) do
      len = length(v)

      length_issues(c, "array", len, p) ++
        (v |> Enum.with_index() |> Enum.flat_map(fn {x, i} -> item_fn.(x, p ++ [i]) end))
    else
      [type(p)]
    end
  end

  # ---- formats ----------------------------------------------------------

  defp format("uuid", v, p), do: fmt(Regex.match?(@uuid_re, v), p, "uuid")
  defp format("uuid_v7", v, p), do: fmt(Regex.match?(@uuid_v7_re, v), p, "uuid")

  defp format("date", v, p), do: fmt(rx("^#{@date_src}$", v), p, "date")

  defp format(kind, v, p) when kind in ["time", "time_usec"],
    do: fmt(rx("^#{@time_src}$", v), p, "time")

  defp format("duration", v, p), do: fmt(Regex.match?(@duration_re, v), p, "duration")

  defp format(kind, v, p) when kind in @datetime_kinds do
    secs = "#{@hhmm}:[0-5]\\d(?:\\.\\d+)?"
    fmt(rx("^#{@date_src}T(?:#{secs}Z)$", v), p, "datetime")
  end

  defp format(_kind, _v, _p), do: []

  defp rx(source, v), do: source |> Regex.compile!() |> Regex.match?(v)
  defp fmt(true, _p, _name), do: []
  defp fmt(false, p, name), do: [issue("invalid_format", p, "Invalid #{name}")]

  # ---- bounds -----------------------------------------------------------

  defp numeric_bounds(c, v, p) do
    [
      bound(num(c, "min"), fn b -> v >= b end, issue("too_small", p, "Too small")),
      bound(num(c, "max"), fn b -> v <= b end, issue("too_big", p, "Too big")),
      bound(num(c, "greater_than"), fn b -> v > b end, issue("too_small", p, "Too small")),
      bound(num(c, "less_than"), fn b -> v < b end, issue("too_big", p, "Too big"))
    ]
    |> List.flatten()
  end

  defp bound(nil, _f, _issue), do: []
  defp bound(b, f, issue), do: if(f.(b), do: [], else: [issue])

  defp num(c, key) do
    v = get(c, key)
    if is_number(v), do: v
  end

  defp string_bounds(kind, c, v, p) when kind in @string_length_kinds,
    do: length_issues(c, kind, codepoint_length(v), p)

  defp string_bounds(_kind, _c, _v, _p), do: []

  defp length_issues(c, kind, len, p) when kind in @length_kinds do
    explicit = int(c, "min_length")

    min =
      if kind in @string_length_kinds and get(c, "allow_empty?") == false,
        do: max(explicit || 1, 1),
        else: explicit

    max = int(c, "max_length")

    List.flatten([
      if(min && len < min, do: [issue("too_small", p, "Too small")], else: []),
      if(max && len > max, do: [issue("too_big", p, "Too big")], else: [])
    ])
  end

  defp int(c, key) do
    v = get(c, key)
    if is_integer(v), do: v
  end

  # Zod 4 (4.6.5) counts string length in code points, not UTF-16 units (measured).
  defp codepoint_length(s), do: for(<<_::utf8 <- s>>, reduce: 0, do: (acc -> acc + 1))

  defp safe_integer?(v) when is_integer(v), do: abs(v) <= 9_007_199_254_740_991

  defp safe_integer?(v) when is_float(v),
    do: v == Float.floor(v) and abs(v) <= 9_007_199_254_740_991.0

  defp regex_check(kind, c, v, p) when kind in @string_kinds do
    case get(c, "match") do
      source when is_binary(source) ->
        if ZodType.regex_safe_for_js?(source) do
          case compile(source, get(c, "match_flags")) do
            {:ok, re} ->
              if Regex.match?(re, v), do: [], else: [issue("invalid_format", p, "Invalid string")]

            :error ->
              []
          end
        else
          []
        end

      _ ->
        []
    end
  end

  defp regex_check(_kind, _c, _v, _p), do: []

  defp compile(source, flags) do
    opts =
      (is_binary(flags) &&
         flags
         |> String.graphemes()
         |> Enum.filter(&(&1 in ~w(i m s)))
         |> Enum.uniq()
         |> Enum.join()) ||
        ""

    case Regex.compile(source, opts) do
      {:ok, re} -> {:ok, re}
      _ -> :error
    end
  end

  # ---- definition accessors (mirror ZodType) ----------------------------

  defp kind_of(%{"type" => %{"kind" => k}}) when is_binary(k), do: k
  defp kind_of(%{"subtype_of" => k}) when is_binary(k), do: k
  defp kind_of(%{type: %{kind: k}}), do: to_string(k)
  defp kind_of(_), do: nil

  defp constraints(%{"type" => %{"kind" => _}} = d), do: map_or_empty(get(d, "constraints"))

  defp constraints(%{"subtype_of" => k} = d) when is_binary(k),
    do: map_or_empty(get(d, "subtype_constraints"))

  defp constraints(d), do: map_or_empty(get(d, "constraints"))

  defp map_or_empty(%{} = m), do: m
  defp map_or_empty(_), do: %{}

  defp one_of(c) do
    case get(c, "one_of") do
      l when is_list(l) -> l
      _ -> []
    end
  end

  defp enum_values(d) do
    type = get(d, "type") || %{}
    get(type, "values") || get(d, "values")
  end

  defp nullable?(d), do: get(d, "allow_nil?") == true or get(d, "allow_nil") == true

  defp omittable?(d),
    do:
      get(d, "optional") == true or get(d, "required?") == false or get(d, "has_default") == true or
        Map.has_key?(d, "default") or Map.has_key?(d, :default)

  defp items_of(d) do
    type = get(d, "type") || %{}

    item =
      get(type, "items") || get(type, "item_type") || get(d, "items") || get(d, "item_type")

    case item do
      %{"kind" => _} = t -> %{"type" => t}
      %{kind: _} = t -> %{"type" => %{"kind" => to_string(t.kind)}}
      %{} = m when map_size(m) > 0 -> m
      _ -> nil
    end
  end

  defp get(map, key) when is_map(map) do
    case Map.get(map, key) do
      nil -> Map.get(map, String.to_atom(key))
      v -> v
    end
  end

  defp get(_, _), do: nil

  defp type(p), do: issue("invalid_type", p, "Invalid input")
  defp issue(code, path, message), do: %{code: code, path: path, message: message}
end
