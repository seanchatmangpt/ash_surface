defmodule AshSurface.PlanningEpisodeTest do
  use ExUnit.Case, async: true
  alias AshSurface.PlanningEpisode

  test "projects a FOND/HDDL planning episode with strict non-DO authority ceiling" do
    candidates = [
      %{"action" => "select_intercessor", "candidate" => "person_01"},
      %{"action" => "select_driver", "candidate" => "person_02"}
    ]

    ep =
      PlanningEpisode.create("obs_9f83a0bc8192a012",
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:policy:strong_cyclic",
        policy_standing: :VALID_STRONG_CYCLIC,
        candidate_actions: candidates,
        authority_ceiling: :SELECT
      )

    assert ep.authority_ceiling == :SELECT
    assert ep.policy_standing == :VALID_STRONG_CYCLIC
    assert String.starts_with?(ep.episode_id, "ep_")

    map = PlanningEpisode.to_map(ep)
    assert map["authorityCeiling"] == "SELECT"
    assert map["policyStanding"] == "VALID_STRONG_CYCLIC"
    assert length(map["candidateActions"]) == 2

    assert_raise ArgumentError, ~r/can never be :DO/, fn ->
      PlanningEpisode.create("obs_123",
        planner_identity: "evil_planner",
        policy_identity: "bad",
        authority_ceiling: :DO
      )
    end
  end
end
