defmodule AshSurface.CommitmentBoundary do
  @moduledoc """
  Human-visible boundary between choosing an option and consequence-bearing DO.

  Confirmation is projected as intent only. Even CONFIRMED values have
  do_authority false; execution remains an explicit BRCE handoff.
  """

  @reversibility [:REVERSIBLE, :CONDITIONAL, :IRREVERSIBLE]
  @states [:UNCONFIRMED, :CONFIRMED, :DECLINED, :EXPIRED]

  @enforce_keys [
    :boundary_id,
    :subject_ref,
    :action_ref,
    :consequence_summary,
    :reversibility,
    :confirmation_state,
    :state_digest
  ]

  defstruct [
    :boundary_id,
    :subject_ref,
    :action_ref,
    :consequence_summary,
    :reversibility,
    :confirmation_state,
    :construct_ref,
    :why_this_ref,
    :expires_at,
    :state_digest,
    external_effects: [],
    evidence_refs: [],
    confirmation_required: true,
    next_handoff: :BRCE,
    authority_ceiling: :CONSTRUCT,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(subject_ref, action_ref, consequence_summary, opts \\ [])
      when is_binary(subject_ref) and is_binary(action_ref) and is_binary(consequence_summary) do
    reversibility = Keyword.get(opts, :reversibility, :CONDITIONAL)
    confirmation_state = Keyword.get(opts, :confirmation_state, :UNCONFIRMED)

    unless reversibility in @reversibility,
      do: raise(ArgumentError, "unknown reversibility: #{inspect(reversibility)}")

    unless confirmation_state in @states,
      do: raise(ArgumentError, "unknown confirmation_state: #{inspect(confirmation_state)}")

    effects = Keyword.get(opts, :external_effects, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    validate_string_list!(effects, :external_effects)
    validate_string_list!(evidence_refs, :evidence_refs)

    identity_digest = digest({"ash_surface_commitment_boundary/1", subject_ref, action_ref})

    canonical = %{
      consequence_summary: consequence_summary,
      reversibility: reversibility,
      confirmation_state: confirmation_state,
      construct_ref: Keyword.get(opts, :construct_ref),
      why_this_ref: Keyword.get(opts, :why_this_ref),
      expires_at: normalize_datetime(Keyword.get(opts, :expires_at)),
      external_effects: Enum.sort(effects),
      evidence_refs: Enum.sort(evidence_refs),
      confirmation_required: true,
      next_handoff: :BRCE,
      authority_ceiling: :CONSTRUCT,
      do_authority: false
    }

    state_digest = digest({"ash_surface_commitment_boundary_state/1", identity_digest, canonical})

    %__MODULE__{
      boundary_id: "cb_" <> binary_part(identity_digest, 0, 16),
      subject_ref: subject_ref,
      action_ref: action_ref,
      consequence_summary: consequence_summary,
      reversibility: reversibility,
      confirmation_state: confirmation_state,
      construct_ref: canonical.construct_ref,
      why_this_ref: canonical.why_this_ref,
      expires_at: Keyword.get(opts, :expires_at),
      external_effects: effects,
      evidence_refs: evidence_refs,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "boundaryId" => value.boundary_id,
      "subjectRef" => value.subject_ref,
      "actionRef" => value.action_ref,
      "consequenceSummary" => value.consequence_summary,
      "reversibility" => Atom.to_string(value.reversibility),
      "confirmationState" => Atom.to_string(value.confirmation_state),
      "constructRef" => value.construct_ref,
      "whyThisRef" => value.why_this_ref,
      "expiresAt" => normalize_datetime(value.expires_at),
      "externalEffects" => value.external_effects,
      "evidenceRefs" => value.evidence_refs,
      "stateDigest" => value.state_digest,
      "confirmationRequired" => true,
      "nextHandoff" => "BRCE",
      "authorityCeiling" => "CONSTRUCT",
      "doAuthority" => false
    }
  end

  defp validate_string_list!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1),
      do: raise(ArgumentError, "#{field} must contain only strings")
  end

  defp validate_string_list!(_, field), do: raise(ArgumentError, "#{field} must be a list")

  defp normalize_datetime(nil), do: nil
  defp normalize_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_datetime(value) when is_binary(value), do: value

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
