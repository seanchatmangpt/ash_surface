defmodule AshSurface.CommandCenter do
  @moduledoc """
  DfCM consumer projection for a live operational command center.

  The command center composes already-admitted observations, obligations,
  planning episodes, capability descriptions, and receipt identities into one
  deterministic read model.

  It owns no business semantics and has an absolute OBSERVE authority boundary:
  it cannot promote a candidate, grant authority, dispatch a command, or infer
  that a consequence occurred. SELECT/CONSTRUCT/DO remain owned by their
  upstream systems.
  """

  alias AshSurface.{Observation, Obligation, PlanningEpisode}

  @enforce_keys [
    :projection_id,
    :exact_subject,
    :state_digest,
    :observations,
    :obligations,
    :planning_episodes,
    :capabilities,
    :receipt_refs
  ]

  defstruct [
    :projection_id,
    :exact_subject,
    :state_digest,
    :observations,
    :obligations,
    :planning_episodes,
    :capabilities,
    :receipt_refs,
    evidence_refs: [],
    standing: :ALIVE,
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{
          projection_id: String.t(),
          exact_subject: String.t(),
          state_digest: String.t(),
          observations: [Observation.t()],
          obligations: [Obligation.t()],
          planning_episodes: [PlanningEpisode.t()],
          capabilities: [map()],
          receipt_refs: [String.t()],
          evidence_refs: [String.t()],
          standing: :ALIVE | :PARTIAL_ALIVE | :REFUSED | :BLOCKED,
          authority_boundary: :OBSERVE
        }

  @spec create(String.t(), keyword()) :: t()
  def create(exact_subject, opts \\ []) when is_binary(exact_subject) do
    observations = Keyword.get(opts, :observations, [])
    obligations = Keyword.get(opts, :obligations, [])
    planning_episodes = Keyword.get(opts, :planning_episodes, [])
    capabilities = Keyword.get(opts, :capabilities, [])
    receipt_refs = Keyword.get(opts, :receipt_refs, [])
    evidence_refs = Keyword.get(opts, :evidence_refs, [])
    standing = Keyword.get(opts, :standing, :ALIVE)

    validate_struct_list!(observations, Observation, :observations)
    validate_struct_list!(obligations, Obligation, :obligations)
    validate_struct_list!(planning_episodes, PlanningEpisode, :planning_episodes)
    validate_maps!(capabilities)
    validate_strings!(receipt_refs, :receipt_refs)
    validate_strings!(evidence_refs, :evidence_refs)

    canonical = %{
      exact_subject: exact_subject,
      observations:
        observations
        |> Enum.map(&Observation.to_map/1)
        |> Enum.sort_by(& &1["observationId"]),
      obligations:
        obligations
        |> Enum.map(&Obligation.to_map/1)
        |> Enum.sort_by(& &1["obligationId"]),
      planning_episodes:
        planning_episodes
        |> Enum.map(&PlanningEpisode.to_map/1)
        |> Enum.sort_by(& &1["episodeId"]),
      capabilities: Enum.sort_by(capabilities, &canonical_key/1),
      receipt_refs: Enum.sort(receipt_refs),
      evidence_refs: Enum.sort(evidence_refs),
      standing: standing
    }

    state_digest = digest({"ash_surface_command_center/1", canonical})

    %__MODULE__{
      projection_id: "cc_" <> binary_part(state_digest, 0, 16),
      exact_subject: exact_subject,
      state_digest: state_digest,
      observations: observations,
      obligations: obligations,
      planning_episodes: planning_episodes,
      capabilities: capabilities,
      receipt_refs: receipt_refs,
      evidence_refs: evidence_refs,
      standing: standing
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = center) do
    %{
      "projectionId" => center.projection_id,
      "exactSubject" => center.exact_subject,
      "stateDigest" => center.state_digest,
      "observations" => Enum.map(center.observations, &Observation.to_map/1),
      "obligations" => Enum.map(center.obligations, &Obligation.to_map/1),
      "planningEpisodes" => Enum.map(center.planning_episodes, &PlanningEpisode.to_map/1),
      "capabilities" => center.capabilities,
      "receiptRefs" => center.receipt_refs,
      "evidenceRefs" => center.evidence_refs,
      "standing" => Atom.to_string(center.standing),
      "authorityBoundary" => "OBSERVE"
    }
  end

  defp validate_struct_list!(values, module, field) when is_list(values) do
    unless Enum.all?(values, &match?(%{__struct__: ^module}, &1)) do
      raise ArgumentError, "#{field} must contain only #{inspect(module)} values"
    end
  end

  defp validate_struct_list!(_values, _module, field),
    do: raise(ArgumentError, "#{field} must be a list")

  defp validate_maps!(values) when is_list(values) do
    unless Enum.all?(values, &is_map/1) do
      raise ArgumentError, "capabilities must contain only maps"
    end
  end

  defp validate_maps!(_), do: raise(ArgumentError, "capabilities must be a list")

  defp validate_strings!(values, field) when is_list(values) do
    unless Enum.all?(values, &is_binary/1) do
      raise ArgumentError, "#{field} must contain only strings"
    end
  end

  defp validate_strings!(_values, field), do: raise(ArgumentError, "#{field} must be a list")

  defp canonical_key(map) do
    map
    |> :erlang.term_to_binary([:deterministic])
    |> Base.encode16(case: :lower)
  end

  defp digest(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
