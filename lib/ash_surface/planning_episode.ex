defmodule AshSurface.PlanningEpisode do
  @moduledoc """
  Machine-readable Planning Episode Projection: PlanningEpisode(pi_t).

  Projects the outcome of a planner solve (e.g. FOND / HDDL from ash_pplan / beam4pm)
  to the consumer interface.

  Crucially:
  - `AshSurface != Planner`
  - `AshSurface = pi_consumer(PlannerResult)`
  - `authority_ceiling` is strictly SELECT or CONSTRUCT, NEVER DO.

  Episode identity is the canonical digest law (chicago-episode-digest-036):
  `digest/1` is the SHA-256 (lowercase hex) of the sorted-key JSON encoding
  (`AshSurface.CanonicalJSON`) of the episode wire record minus the derived
  `episodeId` — exactly `Map.delete(to_map(ep), "episodeId")`. `create/2`
  content-addresses `episode_id` as the `"ep_"` prefix of that digest, mirroring
  Event/Observation, so episode identity is invariant under candidate-map
  construction history (flatmap or >32-key HAMT iteration order can never leak
  into the id) and the JS runtime twin re-derives the same digest from the wire
  record alone (`canonicalStringify` twin in `test/js/planning_episode.test.mjs`).
  """

  alias AshSurface.CanonicalJSON

  @enforce_keys [
    :episode_id,
    :world_state_ref,
    :planner_identity,
    :policy_identity,
    :candidate_actions
  ]
  defstruct [
    :episode_id,
    :world_state_ref,
    :task_network_ref,
    :planner_identity,
    :policy_identity,
    policy_standing: :VALID_STRONG,
    candidate_actions: [],
    authority_ceiling: :SELECT
  ]

  @type standing :: :VALID_STRONG | :VALID_STRONG_CYCLIC | :REFUSED

  @policy_standings [:VALID_STRONG, :VALID_STRONG_CYCLIC, :REFUSED]
  @authority_ceilings [:SELECT, :CONSTRUCT]

  @type t :: %__MODULE__{
          episode_id: String.t(),
          world_state_ref: String.t(),
          task_network_ref: String.t() | nil,
          planner_identity: String.t(),
          policy_identity: String.t(),
          policy_standing: standing(),
          candidate_actions: [map()],
          authority_ceiling: :SELECT | :CONSTRUCT
        }

  @doc """
  Creates a new verified planning episode projection.

  Both standing and ceiling are runtime-validated (F3): `policy_standing` must
  be an admitted lifecycle standing and `authority_ceiling` must be exactly
  `:SELECT` or `:CONSTRUCT` — every other atom (not just `:DO`) is refused
  with `ArgumentError`. Planning is never DO.
  """
  @spec create(String.t(), keyword()) :: t()
  def create(world_state_ref, opts) do
    planner = Keyword.fetch!(opts, :planner_identity)
    policy = Keyword.fetch!(opts, :policy_identity)
    standing = Keyword.get(opts, :policy_standing, :VALID_STRONG)
    candidates = Keyword.get(opts, :candidate_actions, [])
    task_network = Keyword.get(opts, :task_network_ref)
    ceiling = Keyword.get(opts, :authority_ceiling, :SELECT)

    # Authority ceiling is exactly {:SELECT, :CONSTRUCT}: planning != DO, and
    # no unvalidated atom may smuggle a wider ceiling past this constructor.
    unless ceiling in @authority_ceilings do
      raise ArgumentError,
            "PlanningEpisode authority_ceiling can never be :DO or any value outside " <>
              "#{inspect(@authority_ceilings)}, got: #{inspect(ceiling)} (Planner != DO)"
    end

    unless standing in @policy_standings do
      raise ArgumentError,
            "invalid PlanningEpisode policy_standing #{inspect(standing)}; " <>
              "admitted standings are #{inspect(@policy_standings)}"
    end

    # Canonical (key-sorted) JSON over the episode record minus the derived
    # episodeId: episode identity is invariant under candidate-map construction
    # history, flatmap or >32-key HAMT alike. Previously a raw `inspect/1`
    # pipeline hashed the candidates — an Elixir-term encoding no JS twin can
    # re-derive, never a cross-language digest law.
    #
    # The pre-mint struct carries `""` (a valid String.t()) as the episodeId
    # placeholder — record_map/1 drops episodeId, so the digest is invariant
    # over it. Building with `nil` produced a struct outside @type t, making
    # the digest(episode) call out-of-contract: dialyzer collapsed create/2's
    # success typing to none() (invalid_contract + no_return; PR #7 lane AS,
    # 2026-09-24, bisected against CI run 35841301667).
    episode = %__MODULE__{
      episode_id: "",
      world_state_ref: world_state_ref,
      task_network_ref: task_network,
      planner_identity: planner,
      policy_identity: policy,
      policy_standing: standing,
      candidate_actions: candidates,
      authority_ceiling: ceiling
    }

    digest = digest(episode)

    %__MODULE__{episode | episode_id: "ep_" <> binary_part(digest, 0, 16)}
  end

  @doc """
  The canonical digest of the episode record: SHA-256 (lowercase hex) over the
  sorted-key JSON encoding (`AshSurface.CanonicalJSON`) of the episode wire
  record minus the derived `episodeId` — the one digest law episodes share with
  Event and Observation, and the content address `create/2` mints `episode_id`
  from (its `"ep_"` 16-hex prefix).
  """
  @spec digest(t()) :: String.t()
  def digest(%__MODULE__{} = ep), do: CanonicalJSON.sha256_hex(record_map(ep))

  # The digest subject: exactly the wire record of to_map/1 minus episodeId.
  defp record_map(ep) do
    %{
      "worldStateRef" => ep.world_state_ref,
      "taskNetworkRef" => ep.task_network_ref,
      "plannerIdentity" => ep.planner_identity,
      "policyIdentity" => ep.policy_identity,
      "policyStanding" => to_string(ep.policy_standing),
      "candidateActions" => ep.candidate_actions,
      "authorityCeiling" => to_string(ep.authority_ceiling)
    }
  end

  @doc "Converts a planning episode projection to a normalized JSON map."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = ep) do
    %{
      "episodeId" => ep.episode_id,
      "worldStateRef" => ep.world_state_ref,
      "taskNetworkRef" => ep.task_network_ref,
      "plannerIdentity" => ep.planner_identity,
      "policyIdentity" => ep.policy_identity,
      "policyStanding" => to_string(ep.policy_standing),
      "candidateActions" => ep.candidate_actions,
      "authorityCeiling" => to_string(ep.authority_ceiling)
    }
  end
end
