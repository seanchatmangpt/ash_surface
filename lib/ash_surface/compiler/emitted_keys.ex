defmodule AshSurface.Compiler.EmittedKeys do
  @moduledoc """
  Shared collision law for emitted object keys.

  Two DISTINCT source names that map to one emitted key (e.g. `foo_bar` and `fooBar`, or
  `a_b` and `aB`, under the default `:camel_case` formatter) would silently drop one of
  them from a rendered Zod object. That is refused with
  `{:error, {:emitted_key_collision, container, key, [names]}}`. Exact duplicates (the same
  raw name repeated) are not a collision. Mirrors ash_typescript's unique-field-name
  verifiers and, for resources, `AshSurface.FieldName` `field_name_collision` (KD-09).
  """

  @type result :: :ok | {:error, {:emitted_key_collision, term, String.t(), [String.t()]}}

  @doc """
  `entries` are `{raw_name, emitted_key}`; `container` labels the owner in the refusal.
  """
  @spec check([{atom | String.t(), String.t()}], term) :: result
  def check(entries, container) do
    entries
    |> Enum.map(fn {raw, key} -> {to_string(raw), key} end)
    |> Enum.uniq()
    |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
    |> Enum.sort()
    |> Enum.find(fn {_key, raws} -> length(raws) > 1 end)
    |> case do
      nil -> :ok
      {key, raws} -> {:error, {:emitted_key_collision, container, key, Enum.sort(raws)}}
    end
  end

  @doc """
  Collision law over every resource reachable from `resource` through public relationships
  (the root included), regardless of whether a destination owns a compiled action: one
  wire-name table over attributes/calculations/aggregates/relationships (cross-kind), each
  public calculation's arguments, and identity keys. Reuses `AshSurface.FieldName` so the
  spelling is the single kernel's. Refuses `{:field_name_collision, resource, wire, [atoms]}`
  for field tables and `{:emitted_key_collision, container, key, [names]}` for argument and
  identity-key sets.
  """
  @spec check_resource_graph(module | nil) :: :ok | {:error, term}
  def check_resource_graph(resource), do: walk([resource], MapSet.new())

  defp walk([], _seen), do: :ok

  defp walk([r | rest], seen) do
    if MapSet.member?(seen, r) or not resource?(r) do
      walk(rest, seen)
    else
      with :ok <- check_one(r) do
        dests = Enum.map(Ash.Resource.Info.public_relationships(r), & &1.destination)
        walk(rest ++ dests, MapSet.put(seen, r))
      end
    end
  end

  defp resource?(r),
    do:
      is_atom(r) and not is_nil(r) and Code.ensure_loaded?(r) and
        function_exported?(r, :spark_is, 0) and Ash.Resource.Info.resource?(r)

  defp check_one(r) do
    fields =
      Enum.map(Ash.Resource.Info.public_attributes(r), & &1.name) ++
        Enum.map(Ash.Resource.Info.public_calculations(r), & &1.name) ++
        Enum.map(Ash.Resource.Info.public_aggregates(r), & &1.name) ++
        Enum.map(Ash.Resource.Info.public_relationships(r), & &1.name)

    with {:ok, _} <- AshSurface.FieldName.wire_inverse(r, fields),
         :ok <- check_calc_args(r) do
      check_identities(r)
    end
  end

  defp check_calc_args(r) do
    Enum.reduce_while(Ash.Resource.Info.public_calculations(r), :ok, fn calc, :ok ->
      entries = Enum.map(calc.arguments, &{&1.name, AshSurface.FieldName.wire(r, &1.name)})

      case check(entries, {:calculation_arguments, r, calc.name}) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp check_identities(r) do
    Enum.reduce_while(Ash.Resource.Info.identities(r), :ok, fn identity, :ok ->
      entries = Enum.map(identity.keys, &{&1, AshSurface.FieldName.wire(r, &1)})

      case check(entries, {:identity, r, identity.name}) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
