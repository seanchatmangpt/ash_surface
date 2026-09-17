defmodule AshSurface.Compiler.Section.Presentation do
  @moduledoc """
  Default `:presentation` section adapter: bridges the compiler's normalized
  per-action entry to `AshSurface.Compiler.Presentation`, the admin-pattern
  metadata reader (gapfix-adapters-001).

  The reader keeps its own `(action, custom)` signature and its admitted
  widget vocabulary. The normalized entry carries the discovered
  `custom.ash_surface` envelope (one discovery, no re-read), which this
  adapter hands over untouched; the reader's defaults (humanized label,
  order 0, widget "default") flow through for an empty envelope. The
  reader's `AshSurface.Compiler.IR.Presentation` projection is carried into
  the canonical `AshSurface.IR.Presentation` slice verbatim; its typed
  rejections (an unadmitted widget) propagate as the section's error.
  """

  @behaviour AshSurface.Compiler.Section

  alias AshSurface.Compiler.IR.Presentation

  @impl true
  @spec build(map(), map()) :: {:ok, AshSurface.IR.Presentation.t()} | {:error, term()}
  def build(action, _context) when is_map(action) do
    custom = Map.get(action, :custom) || %{}

    case AshSurface.Compiler.Presentation.build(Map.get(action, :action), custom) do
      {:ok, section} -> {:ok, project(section)}
      {:error, reason} -> {:error, reason}
    end
  end

  def build(action, _context), do: {:error, {:invalid_action_entry, action}}

  # Verbatim field carry: both structs declare the same five fields.
  defp project(%Presentation{} = section) do
    struct!(AshSurface.IR.Presentation, Map.from_struct(section))
  end
end
