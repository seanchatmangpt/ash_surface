defmodule AshSurface.Observation do
  @moduledoc """
  Machine-readable Observation Projection: ObservationProjection(W_t).

  Provides the factual, read-only state snapshot of an exact subject at a specific
  time. It explicitly carries `authority_boundary: :OBSERVE` and zero DO authority.
  """

  alias AshSurface.CanonicalJSON

  @enforce_keys [:observation_id, :exact_subject, :observed_at, :state_digest, :facts]
  defstruct [
    :observation_id,
    :exact_subject,
    :observed_at,
    :state_digest,
    :facts,
    evidence_refs: [],
    standing: :ALIVE,
    projection_purpose: "consumer_state_observation",
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{
          observation_id: String.t(),
          exact_subject: String.t(),
          observed_at: DateTime.t(),
          state_digest: String.t(),
          facts: map(),
          evidence_refs: [String.t()],
          standing: AshSurface.Standing.t(),
          projection_purpose: String.t(),
          authority_boundary: :OBSERVE
        }

  @doc """
  Creates and content-addresses a new ObservationProjection.

  The `:standing` option is caller-asserted evidence, so it is runtime-validated
  against the canonical vocabulary (`AshSurface.Standing`) — an unvalidated
  standing claim is refused with `ArgumentError`, never silently carried.
  """
  @spec create(String.t(), map(), keyword()) :: t()
  def create(exact_subject, facts, opts \\ []) do
    observed_at = Keyword.get(opts, :observed_at, DateTime.utc_now())
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    standing = AshSurface.Standing.validate!(Keyword.get(opts, :standing, :ALIVE))
    purpose = Keyword.get(opts, :projection_purpose, "consumer_state_observation")

    # Canonical (key-sorted) JSON: observation identity is invariant under
    # facts map construction history, flatmap or >32-key HAMT alike.
    facts_json = CanonicalJSON.encode(facts)

    state_digest =
      :crypto.hash(:sha256, "#{exact_subject}:#{facts_json}") |> Base.encode16(case: :lower)

    observation_id = "obs_#{binary_part(state_digest, 0, 16)}"

    %__MODULE__{
      observation_id: observation_id,
      exact_subject: exact_subject,
      observed_at: observed_at,
      state_digest: state_digest,
      facts: facts,
      evidence_refs: evidence_refs,
      standing: standing,
      projection_purpose: purpose,
      authority_boundary: :OBSERVE
    }
  end

  @doc "Converts an observation projection to a normalized JSON map."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = obs) do
    %{
      "observationId" => obs.observation_id,
      "exactSubject" => obs.exact_subject,
      "observedAt" => DateTime.to_iso8601(obs.observed_at),
      "stateDigest" => obs.state_digest,
      "facts" => obs.facts,
      "evidenceRefs" => obs.evidence_refs,
      "standing" => to_string(obs.standing),
      "projectionPurpose" => obs.projection_purpose,
      "authorityBoundary" => "OBSERVE"
    }
  end
end
