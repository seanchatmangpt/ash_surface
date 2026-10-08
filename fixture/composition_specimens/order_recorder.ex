# Composition specimen support: transformer execution-order recorder.
#
# Each specimen Persist transformer records its own name at transform time into a
# public named ETS table; the composition court reads the table back and asserts the
# order is deterministic and matches each extension's declared position. The recorder
# must live in the specimens (not the court) because it runs at DRAFT COMPILE time,
# before the court's test process exists.
#
# Chicago discipline: the table is a real ETS table, not a mock; the court asserts on
# the recorded order, never on call counts of a double.
defmodule CompositionSpecimens.Order do
  @table :composition_specimens_order

  def table, do: @table

  @doc "Records `key` as having executed at this instant. Idempotent-safe: creates the table on first use."
  def record(key) when is_atom(key) do
    ensure_table()
    stamp = System.monotonic_time()
    :ets.insert(@table, {{stamp, System.unique_integer([:positive])}, key})
    :ok
  end

  @doc "Keys in execution order (timestamp ASC). Empty list if nothing recorded / no table."
  def recorded do
    case :ets.whereis(@table) do
      :undefined ->
        []

      _table ->
        @table
        |> :ets.tab2list()
        |> Enum.sort()
        |> Enum.map(fn {_k, key} -> key end)
    end
  end

  @doc "Drops and recreates the table so each court section observes a clean ordering trace."
  def reset do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _table -> :ets.delete_all_objects(@table)
    end

    :ok
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :ordered_set, read_concurrency: true])

      _table ->
        :ok
    end
  end
end
