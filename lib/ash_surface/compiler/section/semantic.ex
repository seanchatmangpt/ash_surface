defmodule AshSurface.Compiler.Section.Semantic do
  @moduledoc """
  Default `:semantic` section adapter: bridges the compiler's normalized
  per-action entry to `AshSurface.Compiler.Semantic`, the R2RML-delegated
  meaning section (gapfix-adapters-001).

  The real builder keeps its own `(resource, action)` signature and its own
  frozen laws (delegation not derivation; nil preservation; resource-scoped
  mappings). This adapter only carries its `AshSurface.Compiler.IR.Semantic`
  projection into the canonical `AshSurface.IR.Semantic` slice the assembled
  IR mounts, field-for-field verbatim — and preserves the builder's `nil`
  for an unmapped resource as an honest nil section.
  """

  @behaviour AshSurface.Compiler.Section

  alias AshSurface.Compiler.IR
  alias AshSurface.Compiler.Semantic

  @impl true
  @spec build(map(), map()) :: {:ok, AshSurface.IR.Semantic.t() | nil} | {:error, term()}
  def build(action, _context) when is_map(action) do
    case Semantic.build(Map.get(action, :resource), Map.get(action, :action)) do
      nil -> {:ok, nil}
      %IR.Semantic{} = section -> {:ok, project(section)}
    end
  end

  def build(action, _context), do: {:error, {:invalid_action_entry, action}}

  # Verbatim field carry: both structs declare the same five fields; the
  # adapter adds no fact and drops none.
  defp project(%IR.Semantic{} = section) do
    struct!(AshSurface.IR.Semantic, Map.from_struct(section))
  end
end
