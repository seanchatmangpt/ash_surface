defmodule AshSurface.Compiler.Section.Capability do
  @moduledoc """
  Default `:capability` section adapter: `AshSurface.Compiler.Capability` is
  itself conformed to the canonical build/2 behaviour (gapfix-adapters-001
  retired its resource-enumerating build/1), so this adapter is a direct
  bridge plus one verbatim field carry of the builder's
  `AshSurface.Compiler.IR.Capability` projection into the canonical
  `AshSurface.IR.Capability` slice the assembled IR mounts.

  The builder's nil-preservation law flows through untouched: an
  unregistered resource (no `AshA2A` extension) and an `expose?: false`
  override both yield an honest nil section.
  """

  @behaviour AshSurface.Compiler.Section

  alias AshSurface.Compiler.Capability
  alias AshSurface.Compiler.IR.Capability, as: CapabilitySection

  @impl true
  @spec build(map(), map()) :: {:ok, AshSurface.IR.Capability.t() | nil} | {:error, term()}
  def build(action, context) when is_map(action) do
    case Capability.build(action, context) do
      {:ok, nil} -> {:ok, nil}
      {:ok, %CapabilitySection{} = section} -> {:ok, project(section)}
      {:error, reason} -> {:error, reason}
    end
  end

  def build(action, _context), do: {:error, {:invalid_action_entry, action}}

  # Verbatim field carry: both structs declare the same four fields. The
  # `:unknown` consequence fence passes through as explicit nils — the
  # fail-closed absence, never a fabricated boolean.
  defp project(%CapabilitySection{} = section) do
    struct!(AshSurface.IR.Capability, Map.from_struct(section))
  end
end
