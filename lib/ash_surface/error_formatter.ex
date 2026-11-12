defmodule AshSurface.ErrorFormatter do
  @moduledoc """
  Formats an error map for client consumption.

  Error maps are templates: `message`, `short_message` and the strings under `details`
  carry `%{name}` placeholders while `vars` (and `details`) carry the values. Key
  formatting and placeholder rewriting are inseparable: renaming `action_name` to
  `actionName` in `vars` without rewriting `%{action_name}` breaks client interpolation.
  Values inside `vars` are data and are left alone.

  `formatter` is `:camel_case | :pascal_case | :snake_case | (String.t() -> String.t())`.
  """

  @dictionaries [:vars, "vars", :details, "details"]
  @placeholder ~r/%\{([^}]+)\}/

  @spec format(term(), atom() | (String.t() -> String.t())) :: term()
  def format(error, formatter) when is_map(error) and not is_struct(error) do
    error
    |> rewrite_error(placeholder_renames(error, formatter))
    |> format_error_keys(formatter)
  end

  def format(error, _formatter), do: error

  @doc "Formats a single name with `formatter`."
  @spec format_name(atom() | String.t(), atom() | (String.t() -> String.t())) :: String.t()
  def format_name(name, formatter) do
    s = to_string(name)

    case formatter do
      :snake_case -> s
      :camel_case -> camel(s)
      :pascal_case -> s |> camel() |> upcase_first()
      fun when is_function(fun, 1) -> fun.(s)
      {_, _} = custom -> AshSurface.FieldName.compute(s, custom)
      {_, _, _} = custom -> AshSurface.FieldName.compute(s, custom)
    end
  end

  defp camel(s) do
    if String.contains?(s, "_") do
      [first | rest] = String.split(s, "_")
      first <> Enum.map_join(rest, &upcase_first/1)
    else
      s
    end
  end

  defp upcase_first(""), do: ""
  defp upcase_first(<<c::utf8, rest::binary>>), do: String.upcase(<<c::utf8>>) <> rest

  # Structural keys are formatted; user data under vars/details is left alone below one level.
  defp format_error_keys(map, formatter) do
    Map.new(map, fn {k, v} ->
      {fmt_key(k, formatter), format_value(k, v, formatter)}
    end)
  end

  defp format_value(k, v, formatter) when k in @dictionaries and is_map(v) and not is_struct(v),
    do: Map.new(v, fn {dk, dv} -> {fmt_key(dk, formatter), dv} end)

  defp format_value(_k, v, _formatter), do: v

  defp fmt_key(k, formatter) when is_atom(k) or is_binary(k), do: format_name(k, formatter)
  defp fmt_key(k, _formatter), do: k

  defp placeholder_renames(error, formatter) do
    @dictionaries
    |> Enum.flat_map(fn key ->
      case Map.get(error, key) do
        d when is_map(d) and not is_struct(d) -> Map.keys(d)
        _ -> []
      end
    end)
    |> Enum.flat_map(fn key ->
      original = to_string(key)
      formatted = format_name(original, formatter)
      if formatted == original, do: [], else: [{original, formatted}]
    end)
    |> Map.new()
  end

  defp rewrite_error(error, renames) when map_size(renames) == 0, do: error

  defp rewrite_error(error, renames) do
    Map.new(error, fn
      {key, value} when key in [:vars, "vars"] -> {key, value}
      {key, value} -> {key, rewrite(value, renames)}
    end)
  end

  # Single pass: a rewritten name is never rewritten again.
  defp rewrite(value, renames) when is_binary(value) do
    Regex.replace(@placeholder, value, fn full, name ->
      case Map.fetch(renames, name) do
        {:ok, formatted} -> "%{#{formatted}}"
        :error -> full
      end
    end)
  end

  defp rewrite(value, renames) when is_map(value) and not is_struct(value),
    do: Map.new(value, fn {k, v} -> {k, rewrite(v, renames)} end)

  defp rewrite(value, renames) when is_list(value), do: Enum.map(value, &rewrite(&1, renames))
  defp rewrite(value, _renames), do: value

  @doc """
  Pure field-name mapping for an error map (ref ash_typescript rpc/errors.ex format_error_field_names).

  `mapping` is a resource-level `field_names` map (atom or string keys to client names).
  A mapped name is used verbatim; unmapped names go through `format_name/2`. Applies to
  `fields`, `path` segments and `vars.field` (ash_surface extension over the reference, which maps
  `fields`/`vars.field` only and formats `path` segments without the mapping).
  Works on atom- or string-keyed error maps; the input is not otherwise changed.
  """
  @spec apply_field_names(term(), map() | keyword() | nil, atom() | (String.t() -> String.t())) ::
          term()
  def apply_field_names(error, mapping, formatter) when is_map(error) and not is_struct(error) do
    lookup = Map.new(mapping || %{}, fn {k, v} -> {to_string(k), to_string(v)} end)

    error
    |> map_key(:fields, fn fields -> Enum.map(fields, &name_for(&1, lookup, formatter)) end)
    |> map_key(:path, fn path -> Enum.map(path, &name_for(&1, lookup, formatter)) end)
    |> map_key(:vars, fn vars ->
      Enum.into(vars, %{}, fn
        {k, v} when k in [:field, "field"] -> {k, name_for(v, lookup, formatter)}
        other -> other
      end)
    end)
  end

  def apply_field_names(error, _mapping, _formatter), do: error

  @doc """
  Like `apply_field_names/3` but every field name (`fields`, `path` segments, `vars.field`) is
  produced by `namer` (`name -> String.t()`): the resource-bound `AshSurface.FieldName` wire name,
  so error spellings equal the schema keys exactly.
  """
  @spec apply_namer(term(), (atom() | String.t() -> String.t())) :: term()
  def apply_namer(error, namer) when is_map(error) and not is_struct(error) do
    nm = fn
      n when is_atom(n) or is_binary(n) -> namer.(n)
      other -> other
    end

    error
    |> map_key(:fields, fn fields -> Enum.map(fields, nm) end)
    |> map_key(:path, fn path -> Enum.map(path, nm) end)
    |> map_key(:vars, fn vars ->
      Enum.into(vars, %{}, fn
        {k, v} when k in [:field, "field"] -> {k, nm.(v)}
        other -> other
      end)
    end)
  end

  def apply_namer(error, _namer), do: error

  defp map_key(error, key, fun) do
    Enum.reduce([key, to_string(key)], error, fn k, acc ->
      case acc do
        %{^k => v}
        when (k in [:fields, "fields", :path, "path"] and is_list(v)) or
               (k in [:vars, "vars"] and is_map(v) and not is_struct(v)) ->
          Map.put(acc, k, fun.(v))

        _ ->
          acc
      end
    end)
  end

  defp name_for(name, lookup, formatter) when is_atom(name) or is_binary(name) do
    case Map.fetch(lookup, to_string(name)) do
      {:ok, client} -> client
      :error -> format_name(name, formatter)
    end
  end

  defp name_for(other, _lookup, _formatter), do: other
end
