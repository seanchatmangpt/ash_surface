defmodule AshSurface.Projector.IR do
  @moduledoc """
  The IR consumption contract shared by target projectors
  (`AshSurface.Projectors.*`).

  `AshSurface.IR` is a dumb carrier: this module is the only place that
  normalizes carried facts into the flat entry shape a target projector
  renders. Two laws hold here:

  > **Delegated facts are read, never derived.** `authorityBoundary` is read
  > verbatim from the admitted Ash policy map (atom or string keys) and is
  > `nil` when no delegating source stored it. No action type, default, or
  > coupling infers a boundary.

  > **Ordering is law.** Every list this module returns is sorted by the
  > derived action id so target artifacts are byte-deterministic.
  """

  alias AshSurface.IR

  @boundary_fact "authorityBoundary"

  @enforce_keys [
    :id,
    :resource,
    :action,
    :action_type,
    :authority_boundary,
    :receipt_required,
    :capability_iri,
    :label,
    :zod
  ]
  defstruct [
    :id,
    :resource,
    :action,
    :action_type,
    :authority_boundary,
    :receipt_required,
    :capability_iri,
    :label,
    :zod
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          resource: String.t(),
          action: String.t(),
          action_type: String.t() | nil,
          authority_boundary: String.t() | nil,
          receipt_required: boolean(),
          capability_iri: String.t() | nil,
          label: String.t() | nil,
          zod: String.t() | nil
        }

  @doc """
  Normalizes one `AshSurface.IR.t()` or a list of them into the flat,
  id-sorted entry shape target projectors render.
  """
  @spec entries(IR.t() | [IR.t()]) :: [t()]
  def entries(ir_or_irs) do
    ir_or_irs
    |> List.wrap()
    |> Enum.map(&describe/1)
    |> Enum.sort_by(& &1.id)
  end

  @doc """
  Reads one IR into the flat entry shape.

  The entry id is a naming fact (`resource.action`, last module segment of the
  resource), not an authority derivation.
  """
  @spec describe(IR.t()) :: t()
  def describe(%IR{} = ir) do
    ash = ir.ash || %IR.Ash{}
    capability = ir.capability || %IR.Capability{}
    presentation = ir.presentation || %IR.Presentation{}
    schema = ir.schema || %IR.Schema{}

    resource = short_name(ash.resource)
    action = to_string(ash.action || "")

    %__MODULE__{
      id: "#{resource}.#{action}",
      resource: resource,
      action: action,
      action_type: ash.action_type && to_string(ash.action_type),
      authority_boundary: authority_boundary(ir),
      receipt_required: capability.receipt_required == true,
      capability_iri: ir.semantic && ir.semantic.capability_iri,
      label: presentation.label,
      zod: schema.zod
    }
  end

  @doc """
  Reads the delegated `authorityBoundary` fact from the admitted Ash policy
  maps. Atom and string keys are tolerated so in-memory and round-tripped
  manifests feed the same read path. Returns `nil` when no source delegated
  the fact; no value is ever inferred or defaulted.
  """
  @spec authority_boundary(IR.t()) :: String.t() | nil
  def authority_boundary(%IR{} = ir) do
    policies = (ir.ash && ir.ash.policies) || []

    policies
    |> List.wrap()
    |> Enum.find_value(&read_fact(&1, @boundary_fact))
  end

  @doc """
  True when the delegated boundary fact is exactly the DO literal.

  This classifies an admitted fact; it never grants authority. DO-boundary
  actions are the ones whose client projection may carry dispatch-intent
  descriptors only.
  """
  @spec do_boundary?(t()) :: boolean()
  def do_boundary?(%__MODULE__{authority_boundary: boundary}),
    do: boundary != nil and to_string(boundary) == "DO"

  defp read_fact(%{} = policy, fact) do
    Enum.find_value(policy, fn
      {k, v} when is_atom(k) or is_binary(k) ->
        k |> to_string() == fact && normalize_fact(v)

      _ ->
        nil
    end)
  end

  defp read_fact(_, _), do: nil

  defp normalize_fact(nil), do: nil
  defp normalize_fact(value), do: to_string(value)

  defp short_name(resource) when is_binary(resource),
    do: resource |> String.split(".") |> List.last()

  defp short_name(resource) when is_atom(resource),
    do: resource |> to_string() |> short_name()
end
