defmodule AshSurface.FieldName.Mapping do
  @moduledoc """
  Pure field-name mapping resolution. Port of ash_typescript
  `VerifyFieldNames` / `VerifyMappedFieldNames` / `VerifyMapFieldNames` and the
  precedence in `FieldFormatter.compute_field_for_client/3`.

  Precedence for a field's client name (first hit wins, mapped names verbatim):

    1. type-level `typescript_field_names` map (`type_names`)
    2. resource-level `field_names` map (`field_names`)
    3. the formatter (`AshSurface.FieldName.compute/2`)

  `argument_names` and map-constraint names use the same shape. All functions
  return typed errors; none raise on bad config.
  """

  alias AshSurface.{FieldName, Naming}

  @type names :: %{optional(atom) => String.t()}
  @type opts :: [
          type_names: names,
          field_names: names,
          formatter: FieldName.formatter(),
          fields: [atom]
        ]

  @doc "Client name for `field` under the documented precedence."
  @spec resolve(atom, opts) :: String.t()
  def resolve(field, opts) do
    type_names = Keyword.get(opts, :type_names, %{})
    field_names = Keyword.get(opts, :field_names, %{})
    formatter = Keyword.get(opts, :formatter, :camel_case)

    case {Map.get(type_names, field), Map.get(field_names, field)} do
      {m, _} when is_binary(m) -> m
      {_, m} when is_binary(m) -> m
      _ -> FieldName.compute(field, formatter)
    end
  end

  @doc """
  Build `{:ok, %{mapped: %{atom => client}, reverse: %{client => atom}}}` for
  `opts[:fields]`, or the first typed error (see `verify/1`).
  """
  @spec build(opts) :: {:ok, %{mapped: names, reverse: %{String.t() => atom}}} | {:error, term}
  def build(opts) do
    with :ok <- verify(opts) do
      fields = Keyword.get(opts, :fields, [])
      mapped = Map.new(fields, &{&1, resolve(&1, opts)})
      {:ok, %{mapped: mapped, reverse: Map.new(mapped, fn {a, c} -> {c, a} end)}}
    end
  end

  @doc """
  Pure verifier. Errors (first found, deterministic order):

    * `{:error, {:invalid_formatter, ...}}`
    * `{:error, {:field_not_found, field}}` - mapped key not in `fields`
    * `{:error, {:field_not_invalid, field}}` - key needs no mapping (`field_names` only)
    * `{:error, {:replacement_not_string, field, value}}`
    * `{:error, {:replacement_invalid_identifier, field, value}}`
    * `{:error, {:collision, client, [atoms]}}`
  """
  @spec verify(opts) :: :ok | {:error, term}
  def verify(opts) do
    fields = Keyword.get(opts, :fields, [])
    field_names = Keyword.get(opts, :field_names, %{})
    type_names = Keyword.get(opts, :type_names, %{})

    with :ok <- FieldName.validate_formatter(Keyword.get(opts, :formatter, :camel_case)),
         :ok <- verify_mapped(field_names, fields, true),
         :ok <- verify_mapped(type_names, fields, false) do
      verify_collisions(fields, opts)
    end
  end

  @doc "Verify an `argument_names` / map-constraint names map against `keys`."
  @spec verify_names(names, [atom]) :: :ok | {:error, term}
  def verify_names(names, keys), do: verify_mapped(names, keys, true)

  defp verify_mapped(names, fields, require_invalid?) do
    names
    |> Enum.sort()
    |> Enum.find_value(:ok, fn {k, v} ->
      cond do
        k not in fields -> {:error, {:field_not_found, k}}
        require_invalid? and not Naming.invalid_name?(k) -> {:error, {:field_not_invalid, k}}
        not is_binary(v) -> {:error, {:replacement_not_string, k, v}}
        not Naming.identifier?(v) -> {:error, {:replacement_invalid_identifier, k, v}}
        true -> nil
      end
    end)
  end

  defp verify_collisions(fields, opts) do
    groups = fields |> Enum.uniq() |> Enum.group_by(&resolve(&1, opts))

    case groups |> Enum.sort() |> Enum.find(fn {_, v} -> length(v) > 1 end) do
      {client, atoms} -> {:error, {:collision, client, atoms}}
      nil -> :ok
    end
  end
end
