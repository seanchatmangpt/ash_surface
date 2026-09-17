defmodule AshSurface.Compiler.Section.Ash do
  @moduledoc """
  Default `:ash` section adapter: bridges the compiler's normalized per-action
  entry to `AshSurface.Compiler.AshTruth` — the ONE canon for the ash section
  (gapfix-adapters-001 reconciliation).

  The rival resource-enumerating builder `AshSurface.Compiler.Ash` is retired:
  it wrote raw inputs/outputs (an accepted-key atom list, a raw `returns`
  type atom) into `AshSurface.IR.Ash` fields whose @type carries typed
  sub-shapes. `AshTruth` conforms — `%IR.Input{}`, `%IR.Output{}`,
  `%IR.Policy{}` — so the default pipeline compiles per action through it and
  the assembled IR carries conforming truth.

  Like every section adapter, this module re-derives nothing: discovery
  happened exactly once before any section runs, and `AshTruth.build/2`
  witnesses the action on the compiled resource it is handed.
  """

  @behaviour AshSurface.Compiler.Section

  alias AshSurface.Compiler.AshTruth

  @impl true
  @spec build(map(), map()) :: {:ok, AshSurface.IR.Ash.t()} | {:error, term()}
  def build(action, _context) when is_map(action) do
    AshTruth.build(Map.get(action, :resource), Map.get(action, :action))
  end

  def build(action, _context), do: {:error, {:invalid_action_entry, action}}
end
