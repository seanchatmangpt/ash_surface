defmodule AshSurface.Obligation do
  @moduledoc """
  OBSERVE-only projection of an operational obligation manufactured elsewhere.

  AshSurface does not create the obligation, select its provider, grant
  authority, or actuate it. It presents the exact capability need, current
  assignment/escalation state, and evidence/receipt links to consumers.

  Identity is stable across state transitions: `obligation_id` is derived from
  the exact subject, capability, and cause reference. `state_digest` changes
  when the projected state changes.
  """

  @statuses [:open, :assigned, :acknowledged, :executing, :resolved, :blocked, :unknown]

  @enforce_keys [
    :obligation_id,
    :exact_subject,
    :capability_id,
    :cause_ref,
    :status,
    :state_digest
  ]

  defstruct [
    :obligation_id,
    :exact_subject,
    :capability_id,
    :cause_ref,
    :status,
    :state_digest,
    :assigned_to,
    :receipt_ref,
    :postcondition_ref,
    escalation_path: [],
    evidence_refs: [],
    authority_boundary: :OBSERVE
  ]

  @type status :: :open | :assigned | :acknowledged | :executing | :resolved | :blocked | :unknown

  @type t :: %__MODULE__{
          obligation_id: String.t(),
          exact_subject: String.t(),
          capability_id: String.t(),
          cause_ref: String.t(),
          status: status(),
          state_digest: String.t(),
          assigned_to: String.t() | nil,
          receipt_ref: String.t() | nil,
          postcondition_ref: String.t() | nil,
          escalation_path: [String.t()],
          evidence_refs: [String.t()],
          authority_boundary: :OBSERVE
        }

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(exact_subject, capability_id, cause_ref, opts \\ [])
      when is_binary(exact_subject) and is_binary(capability_id) and is_binary(cause_ref) do
    status = Keyword.get(opts, :status, :open)

    unless status in @statuses do
      raise ArgumentError, "unknown obligation status: #{inspect(status)}"
    end

    assigned_to = Keyword.get(opts, :assigned_to)
    escalation_path = Keyword.get(opts, :escalation_path, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    receipt_ref = Keyword.get(opts, :receipt_ref)
    postcondition_ref = Keyword.get(opts, :postcondition_ref)

    if status == :resolved and not (is_binary(postcondition_ref) and byte_size(postcondition_ref) > 0) do
      raise ArgumentError, "resolved obligation requires a postcondition_ref"
    end

    identity_digest =
      digest({"ash_surface_obligation/1", exact_subject, capability_id, cause_ref})

    state_digest =
      digest({
        "ash_surface_obligation_state/1",
        identity_digest,
        status,
        assigned_to,
        escalation_path,
        Enum.sort(evidence_refs),
        receipt_ref,
        postcondition_ref
      })

    %__MODULE__{
      obligation_id: "obl_" <> binary_part(identity_digest, 0, 16),
      exact_subject: exact_subject,
      capability_id: capability_id,
      cause_ref: cause_ref,
      status: status,
      state_digest: state_digest,
      assigned_to: assigned_to,
      escalation_path: escalation_path,
      evidence_refs: evidence_refs,
      receipt_ref: receipt_ref,
      postcondition_ref: postcondition_ref
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = obligation) do
    %{
      "obligationId" => obligation.obligation_id,
      "exactSubject" => obligation.exact_subject,
      "capabilityId" => obligation.capability_id,
      "causeRef" => obligation.cause_ref,
      "status" => Atom.to_string(obligation.status),
      "stateDigest" => obligation.state_digest,
      "assignedTo" => obligation.assigned_to,
      "escalationPath" => obligation.escalation_path,
      "evidenceRefs" => obligation.evidence_refs,
      "receiptRef" => obligation.receipt_ref,
      "postconditionRef" => obligation.postcondition_ref,
      "authorityBoundary" => "OBSERVE"
    }
  end

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
