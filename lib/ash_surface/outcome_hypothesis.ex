defmodule AshSurface.OutcomeHypothesis do
  @moduledoc """
  Falsifiable candidate relationship between a practice and a user-selected outcome.

  This is deliberately not a causal assertion. Evidence may promote the
  relationship's standing, but AshSurface only projects that standing.
  """

  @relationships [:MAY_SUPPORT, :MAY_HINDER, :ASSOCIATED, :UNKNOWN]
  @evidence_states [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]

  @enforce_keys [
    :hypothesis_id,
    :subject_ref,
    :practice_ref,
    :outcome_ref,
    :relationship,
    :falsifier,
    :state_digest
  ]

  defstruct [
    :hypothesis_id,
    :subject_ref,
    :practice_ref,
    :outcome_ref,
    :relationship,
    :falsifier,
    :horizon,
    :state_digest,
    evidence_state: :UNKNOWN,
    evidence_refs: [],
    observation_refs: [],
    causal_claim: false,
    authority_boundary: :OBSERVE,
    do_authority: false
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(subject_ref, practice_ref, outcome_ref, opts \\ [])
      when is_binary(subject_ref) and is_binary(practice_ref) and is_binary(outcome_ref) do
    relationship = Keyword.get(opts, :relationship, :UNKNOWN)
    evidence_state = Keyword.get(opts, :evidence_state, :UNKNOWN)
    falsifier = Keyword.fetch!(opts, :falsifier)

    unless relationship in @relationships,
      do: raise(ArgumentError, "unknown relationship: #{inspect(relationship)}")

    unless evidence_state in @evidence_states,
      do: raise(ArgumentError, "unknown evidence_state: #{inspect(evidence_state)}")

    unless is_binary(falsifier) and byte_size(falsifier) > 0,
      do: raise(ArgumentError, "falsifier must be a non-empty string")

    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    observation_refs = Keyword.get(opts, :observation_refs, [])
    validate_string_list!(evidence_refs, :evidence_refs)
    validate_string_list!(observation_refs, :observation_refs)

    identity_digest =
      digest({"ash_surface_outcome_hypothesis/1", subject_ref, practice_ref, outcome_ref})

    canonical = %{
      relationship: relationship,
      evidence_state: evidence_state,
      falsifier: falsifier,
      horizon: Keyword.get(opts, :horizon),
      evidence_refs: Enum.sort(evidence_refs),
      observation_refs: Enum.sort(observation_refs),
      causal_claim: false
    }

    state_digest = digest({"ash_surface_outcome_hypothesis_state/1", identity_digest, canonical})

    %__MODULE__{
      hypothesis_id: "hyp_" <> binary_part(identity_digest, 0, 16),
      subject_ref: subject_ref,
      practice_ref: practice_ref,
      outcome_ref: outcome_ref,
      relationship: relationship,
      evidence_state: evidence_state,
      falsifier: falsifier,
      horizon: canonical.horizon,
      evidence_refs: evidence_refs,
      observation_refs: observation_refs,
      state_digest: state_digest,
      causal_claim: false
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "hypothesisId" => value.hypothesis_id,
      "subjectRef" => value.subject_ref,
      "practiceRef" => value.practice_ref,
      "outcomeRef" => value.outcome_ref,
      "relationship" => Atom.to_string(value.relationship),
      "evidenceState" => Atom.to_string(value.evidence_state),
      "falsifier" => value.falsifier,
      "horizon" => value.horizon,
      "evidenceRefs" => value.evidence_refs,
      "observationRefs" => value.observation_refs,
      "stateDigest" => value.state_digest,
      "causalClaim" => false,
      "authorityBoundary" => "OBSERVE",
      "doAuthority" => false
    }
  end

  defp validate_string_list!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1),
      do: raise(ArgumentError, "#{field} must contain only strings")
  end

  defp validate_string_list!(_, field), do: raise(ArgumentError, "#{field} must be a list")

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
