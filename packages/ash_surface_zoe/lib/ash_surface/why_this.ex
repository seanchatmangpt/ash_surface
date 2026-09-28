defmodule AshSurface.WhyThis do
  @moduledoc """
  Evidence-bounded human explanation projection.

  "Why this?" is explanatory metadata over an already-admitted candidate. It
  never upgrades a hypothesis into fact and never grants action authority.
  """

  @claim_kinds [:HYPOTHESIS, :OBSERVATION, :USER_STATED, :DOCTRINAL]
  @evidence_states [:UNKNOWN, :PARTIAL_ALIVE, :ALIVE, :BLOCKED, :REFUSED]

  @enforce_keys [
    :explanation_id,
    :subject_ref,
    :title,
    :summary,
    :claim_kind,
    :evidence_state,
    :state_digest
  ]

  defstruct [
    :explanation_id,
    :subject_ref,
    :title,
    :summary,
    :claim_kind,
    :evidence_state,
    :falsifier,
    :state_digest,
    basis: [],
    caveats: [],
    profile_refs: [],
    evidence_refs: [],
    hypothesis_refs: [],
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{}

  @spec create(String.t(), String.t(), String.t(), keyword()) :: t()
  def create(subject_ref, title, summary, opts \\ [])
      when is_binary(subject_ref) and is_binary(title) and is_binary(summary) do
    claim_kind = Keyword.get(opts, :claim_kind, :HYPOTHESIS)
    evidence_state = Keyword.get(opts, :evidence_state, :UNKNOWN)
    falsifier = Keyword.get(opts, :falsifier)

    unless claim_kind in @claim_kinds,
      do: raise(ArgumentError, "unknown claim_kind: #{inspect(claim_kind)}")

    unless evidence_state in @evidence_states,
      do: raise(ArgumentError, "unknown evidence_state: #{inspect(evidence_state)}")

    if claim_kind == :HYPOTHESIS and not (is_binary(falsifier) and byte_size(falsifier) > 0),
      do: raise(ArgumentError, "HYPOTHESIS explanation requires a falsifier")

    basis = Keyword.get(opts, :basis, [])
    caveats = Keyword.get(opts, :caveats, [])
    profile_refs = Keyword.get(opts, :profile_refs, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    hypothesis_refs = Keyword.get(opts, :hypothesis_refs, [])

    Enum.each(
      [
        basis: basis,
        caveats: caveats,
        profile_refs: profile_refs,
        evidence_refs: evidence_refs,
        hypothesis_refs: hypothesis_refs
      ],
      fn {field, values} -> validate_string_list!(values, field) end
    )

    canonical = %{
      subject_ref: subject_ref,
      title: title,
      summary: summary,
      claim_kind: claim_kind,
      evidence_state: evidence_state,
      falsifier: falsifier,
      basis: Enum.sort(basis),
      caveats: Enum.sort(caveats),
      profile_refs: Enum.sort(profile_refs),
      evidence_refs: Enum.sort(evidence_refs),
      hypothesis_refs: Enum.sort(hypothesis_refs)
    }

    state_digest = digest({"ash_surface_why_this/1", canonical})

    %__MODULE__{
      explanation_id: "why_" <> binary_part(state_digest, 0, 16),
      subject_ref: subject_ref,
      title: title,
      summary: summary,
      claim_kind: claim_kind,
      evidence_state: evidence_state,
      falsifier: falsifier,
      basis: basis,
      caveats: caveats,
      profile_refs: profile_refs,
      evidence_refs: evidence_refs,
      hypothesis_refs: hypothesis_refs,
      state_digest: state_digest
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = value) do
    %{
      "explanationId" => value.explanation_id,
      "subjectRef" => value.subject_ref,
      "title" => value.title,
      "summary" => value.summary,
      "claimKind" => Atom.to_string(value.claim_kind),
      "evidenceState" => Atom.to_string(value.evidence_state),
      "falsifier" => value.falsifier,
      "basis" => value.basis,
      "caveats" => value.caveats,
      "profileRefs" => value.profile_refs,
      "evidenceRefs" => value.evidence_refs,
      "hypothesisRefs" => value.hypothesis_refs,
      "stateDigest" => value.state_digest,
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
