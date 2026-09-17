defmodule AshSurface.Compiler.Section.Schema do
  @moduledoc """
  Default `:schema` section adapter: bridges the compiler's normalized
  per-action entry to `AshSurface.Compiler.Schema`, the shared-manufacture
  boundary-schema builder (gapfix-adapters-001).

  The real builder keeps its own discovery-map contract
  (`%{"actions" => [...]}` -> one `AshSurface.Compiler.IR.Boundary` per
  action id, with the zod projection and aria data it manufactures itself).
  This adapter re-states exactly the one action it was handed in that
  builder's own discovery shape — id, argument names, `allow_nil?`, the
  discovered type kind, no declared returns — and extracts that action's
  boundary slice into the canonical `AshSurface.IR.Schema` the assembled IR
  mounts. No Ash introspection happens here: the no-second-discovery
  contract holds because every fact the entry carries was in the normalized
  argument.

  Types outside the discovered kind vocabulary arrive as `nil` and flow
  into the builder's own `z.unknown()` fallback — the builder's published
  law for unknown kinds, never a locally guessed kind.
  """

  @behaviour AshSurface.Compiler.Section

  alias AshSurface.Compiler.IR.Boundary
  alias AshSurface.Compiler.Schema

  @impl true
  @spec build(map(), map()) :: {:ok, AshSurface.IR.Schema.t()} | {:error, term()}
  def build(action, _context) when is_map(action) do
    id = Map.get(action, :id)
    entry = discovery_entry(action)

    with true <- is_binary(id) and entry != nil,
         {:ok, ir, _meta} <- Schema.build(%{"actions" => [entry]}),
         %Boundary{} = boundary <- Map.get(ir, id) do
      {:ok, project(boundary)}
    else
      false -> {:error, {:invalid_action_entry, action}}
      {:error, reason} -> {:error, reason}
      nil -> {:error, {:action_missing_from_schema_section, id}}
    end
  end

  def build(action, _context), do: {:error, {:invalid_action_entry, action}}

  # The builder's discovery shape, re-stated from the normalized entry.
  # `returns` is nil: the normalized map carries output metadata names, not
  # a declared return type, so the boundary honestly carries no output
  # schema instead of an invented one.
  defp discovery_entry(action) do
    inputs = Map.get(action, :inputs) || []

    if Enum.all?(inputs, &valid_input?/1) do
      %{
        "id" => Map.get(action, :id),
        "arguments" => Enum.map(inputs, &argument_entry/1),
        "returns" => nil
      }
    else
      nil
    end
  end

  defp valid_input?(input) when is_map(input), do: is_binary(Map.get(input, :name))
  defp valid_input?(_), do: false

  defp argument_entry(input) do
    entry = %{"name" => Map.fetch!(input, :name), "allow_nil?" => !!Map.get(input, :allow_nil)}

    case Map.get(input, :type) do
      nil -> entry
      kind when is_binary(kind) -> Map.put(entry, "type", %{"kind" => kind})
    end
  end

  # Verbatim field carry: both structs declare the same four fields.
  defp project(%Boundary{} = boundary) do
    struct!(AshSurface.IR.Schema, Map.from_struct(boundary))
  end
end
