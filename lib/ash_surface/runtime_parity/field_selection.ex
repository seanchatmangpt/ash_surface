defmodule AshSurface.RuntimeParity.FieldSelection do
  @moduledoc """
  Projection-side counterpart of AshTypescript's `Rpc.FieldProcessing.Atomizer`,
  `FieldSelector.Validation` and the selection-validation half of `FieldSelector`.

  Pure and total: refusals are returned as `{:error, reason}` tuples (never thrown),
  and client names resolve only against the admitted set, so the atom table is never
  touched (see `AshSurface.FieldName.parse_input/4`).
  """

  alias AshSurface.FieldName

  @type field :: atom | String.t() | map | {atom, term}

  @doc "Resolve every client field name against `admitted`; unresolved strings are preserved."
  @spec atomize_requested_fields([field], FieldName.formatter(), [atom], map) :: [term]
  def atomize_requested_fields(fields, formatter, admitted, overrides \\ %{})
      when is_list(fields) do
    Enum.map(fields, &atomize(&1, formatter, admitted, overrides))
  end

  defp atomize(field, _f, _a, _o) when is_atom(field), do: field

  defp atomize(field, f, a, o) when is_binary(field) do
    case FieldName.parse_input(field, f, a, o) do
      {:ok, atom} -> atom
      :error -> field
    end
  end

  defp atomize(%{} = map, f, a, o) do
    Map.new(map, fn {k, v} -> {atomize(k, f, a, o), atomize_value(v, f, a, o)} end)
  end

  defp atomize(other, _f, _a, _o), do: other

  defp atomize_value(list, f, a, o) when is_list(list),
    do: atomize_requested_fields(list, f, a, o)

  defp atomize_value(%{} = map, f, a, o), do: atomize(map, f, a, o)
  defp atomize_value(other, _f, _a, _o), do: other

  @doc "Refuse duplicate field names after normalising through the formatter."
  @spec check_for_duplicates([field], list, FieldName.formatter(), [atom], map) ::
          :ok | {:error, tuple}
  def check_for_duplicates(fields, path, formatter, admitted, overrides \\ %{}) do
    with {:ok, names} <- names(fields, path, formatter, admitted, overrides) do
      case names |> Enum.frequencies() |> Enum.filter(fn {_, n} -> n > 1 end) do
        [] ->
          :ok

        dups ->
          {:error,
           {:duplicate_field, dups |> Enum.map(&elem(&1, 0)) |> Enum.sort() |> hd(), path}}
      end
    end
  end

  defp names(fields, path, f, a, o) do
    Enum.reduce_while(fields, {:ok, []}, fn field, {:ok, acc} ->
      case field_names(field, f, a, o) do
        {:ok, ns} -> {:cont, {:ok, acc ++ ns}}
        :error -> {:halt, {:error, {:invalid_field_type, field, path}}}
      end
    end)
  end

  defp field_names(field, _f, _a, _o) when is_atom(field), do: {:ok, [field]}
  defp field_names(field, f, a, o) when is_binary(field), do: {:ok, [atomize(field, f, a, o)]}
  defp field_names({name, _spec}, _f, _a, _o) when is_atom(name), do: {:ok, [name]}
  defp field_names(%{} = map, f, a, o), do: {:ok, Enum.map(Map.keys(map), &atomize(&1, f, a, o))}
  defp field_names(_other, _f, _a, _o), do: :error

  @doc "A relationship/embedded selection must be a non-empty list."
  @spec validate_non_empty(term, term, list) :: :ok | {:error, tuple}
  def validate_non_empty(nested, name, path) do
    cond do
      not is_list(nested) -> {:error, {:unsupported_field_combination, name, nested, path}}
      nested == [] -> {:error, {:requires_field_selection, name, path}}
      true -> :ok
    end
  end

  @doc """
  Validate a flat selection: every entry must resolve to an admitted, non-denied field.
  Returns the resolved atoms, or the first typed refusal.
  """
  @spec select([field], [atom], [atom], FieldName.formatter(), map) ::
          {:ok, [atom]} | {:error, tuple}
  def select(fields, admitted, denied, formatter, overrides \\ %{}) do
    with :ok <- check_for_duplicates(fields, [], formatter, admitted, overrides) do
      fields
      |> atomize_requested_fields(formatter, admitted, overrides)
      |> Enum.reduce_while({:ok, []}, fn
        name, {:ok, acc} when is_atom(name) ->
          cond do
            name in denied -> {:halt, {:error, {:denied_field, name, []}}}
            name in admitted -> {:cont, {:ok, acc ++ [name]}}
            true -> {:halt, {:error, {:unknown_field, name, []}}}
          end

        other, _ ->
          {:halt, {:error, {:unknown_field, other, []}}}
      end)
    end
  end

  @doc """
  Counterpart of `Rpc.FieldExtractor`: read one field from a map, struct or keyword
  list by atom or string key. Returns `{:ok, value}` or `:error`.
  """
  @spec extract(term, atom | String.t()) :: {:ok, term} | :error
  def extract(%{} = data, key) when is_atom(key) do
    case Map.fetch(data, key) do
      {:ok, _} = ok -> ok
      :error -> Map.fetch(data, Atom.to_string(key))
    end
  end

  def extract(%{} = data, key) when is_binary(key) do
    case Map.fetch(data, key) do
      {:ok, _} = ok ->
        ok

      :error ->
        Enum.find_value(data, :error, fn
          {k, v} when is_atom(k) -> if Atom.to_string(k) == key, do: {:ok, v}
          _ -> nil
        end)
    end
  end

  def extract(list, key) when is_list(list) and is_atom(key) do
    if Keyword.keyword?(list), do: Keyword.fetch(list, key), else: :error
  end

  def extract(_other, _key), do: :error

  @doc """
  Counterpart of `Rpc.ValueFormatter` / `Rpc.OutputFormatter` / `Rpc.InputFormatter`
  on composite values: recursively rename map keys. `:output` maps internal atoms to
  client strings (`AshSurface.FieldName.format/3`); `:input` maps client strings to
  internal atoms resolved against `admitted` (unknown keys preserved verbatim).
  Structs and non-map scalars pass through unchanged.
  """
  @spec format_value(term, :input | :output, FieldName.formatter(), [atom], map) :: term
  def format_value(value, direction, formatter, admitted \\ [], overrides \\ %{})

  def format_value(%_{} = struct, _d, _f, _a, _o), do: struct

  def format_value(%{} = map, direction, f, a, o) do
    Map.new(map, fn {k, v} ->
      {format_key(k, direction, f, a, o), format_value(v, direction, f, a, o)}
    end)
  end

  def format_value(list, direction, f, a, o) when is_list(list),
    do: Enum.map(list, &format_value(&1, direction, f, a, o))

  def format_value(other, _d, _f, _a, _o), do: other

  defp format_key(k, :output, f, _a, o) when is_atom(k), do: FieldName.format(k, f, o)
  defp format_key(k, :input, f, a, o) when is_binary(k), do: atomize(k, f, a, o)
  defp format_key(k, _d, _f, _a, _o), do: k
end
