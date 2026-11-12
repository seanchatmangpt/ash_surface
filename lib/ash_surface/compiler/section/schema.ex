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
  alias AshSurface.Compiler.TypeFacts

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
  # `returns` is the generic action's declared return type facts (`:returns_facts`,
  # built once by `TypeFacts`); nil for CRUD actions and generic actions that declare
  # none, so the boundary never carries an invented output schema.
  defp discovery_entry(action) do
    inputs = Map.get(action, :inputs) || []

    if Enum.all?(inputs, &valid_input?/1) do
      %{
        "id" => Map.get(action, :id),
        "arguments" => Enum.map(inputs, &argument_entry(&1, action)),
        "embedded_resources" => Map.get(action, :embedded_resources) || %{},
        "returns" => Map.get(action, :returns_facts)
      }
    else
      nil
    end
  end

  defp valid_input?(input) when is_map(input), do: is_binary(Map.get(input, :name))
  defp valid_input?(_), do: false

  # The argument's whole declared type fact set: the compiler's single
  # definition (`type_facts`, built by `TypeFacts`) carries kind, constraints,
  # subtype facts, array items, enum values, union members, struct fields and
  # instance_of. Hand-built entries without `type_facts` fall back to the bare
  # kind plus whatever constraints they carry. A defaulted argument is
  # omittable: `"optional" => true` (ZodType renders `.optional()`).
  defp argument_entry(input, action) do
    base =
      case Map.get(input, :type_facts) do
        %{} = facts -> facts
        nil -> fallback_facts(input)
      end

    base
    |> Map.put("name", wire_input_name(action, Map.fetch!(input, :name)))
    |> Map.put("allow_nil?", !!Map.get(input, :allow_nil))
    |> then(&if(omittable?(input), do: Map.put(&1, "optional", true), else: &1))
  end

  # Client spelling of an input key (`argument_names`, `field_names`, else the output formatter).
  defp wire_input_name(action, name) do
    AshSurface.FieldName.wire_argument(Map.get(action, :resource), Map.get(action, :action), name)
  end

  # Ash accepts an omitted argument when it is defaulted or nil-able, so the
  # input schema key is omittable in both cases (ZodType: `.optional()`).
  defp omittable?(input),
    do:
      Map.get(input, :has_default) == true or Map.get(input, :allow_nil) == true or
        Map.get(input, :required) == false

  defp fallback_facts(input) do
    constraints = input |> Map.get(:constraints) |> TypeFacts.constraints()

    facts =
      case Map.get(input, :type) do
        kind when is_binary(kind) -> %{"type" => %{"kind" => kind}}
        _ -> %{}
      end

    if constraints == %{},
      do: facts,
      else: Map.put(facts, "constraints", TypeFacts.stringify_constraints(constraints))
  end

  # Verbatim field carry: both structs declare the same four fields.
  defp project(%Boundary{} = boundary) do
    struct!(AshSurface.IR.Schema, Map.from_struct(boundary))
  end
end
