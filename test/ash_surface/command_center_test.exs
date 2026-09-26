defmodule AshSurface.CommandCenterTest do
  use ExUnit.Case, async: true

  alias AshSurface.{CommandCenter, Observation, Obligation, PlanningEpisode}

  test "composes admitted projections into a deterministic OBSERVE-only command center" do
    observation =
      Observation.create(
        "zoe:event:holiday#north_gate",
        %{"gate_flow" => "degraded", "near_miss" => true},
        evidence_refs: ["field_report_1"]
      )

    obligation =
      Obligation.create(
        "zoe:event:holiday#north_gate",
        "Zoe.Security.request_reinforcement",
        observation.observation_id,
        status: :assigned,
        assigned_to: "security:second_guard",
        evidence_refs: [observation.observation_id]
      )

    episode =
      PlanningEpisode.create(observation.observation_id,
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:event_safety:v1",
        candidate_actions: [
          %{
            "capabilityId" => "Zoe.Security.request_reinforcement",
            "provider" => "security:second_guard"
          }
        ],
        authority_ceiling: :SELECT
      )

    capability = %{
      "capabilityId" => "Zoe.Security.request_reinforcement",
      "authorityBoundary" => "NONE",
      "standing" => "CANDIDATE"
    }

    center =
      CommandCenter.create("zoe:event:holiday",
        observations: [observation],
        obligations: [obligation],
        planning_episodes: [episode],
        capabilities: [capability],
        receipt_refs: ["receipt_pending_1"],
        evidence_refs: ["field_report_1"]
      )

    assert center.authority_boundary == :OBSERVE
    assert center.standing == :PARTIAL_ALIVE
    assert String.starts_with?(center.projection_id, "cc_")
    assert byte_size(center.state_digest) == 64

    projected = CommandCenter.to_map(center)
    assert projected["authorityBoundary"] == "OBSERVE"
    assert hd(projected["obligations"])["capabilityId"] == "Zoe.Security.request_reinforcement"
    assert hd(projected["planningEpisodes"])["authorityCeiling"] == "SELECT"
  end

  test "digest is invariant to capability and receipt list order" do
    cap_a = %{"capabilityId" => "a"}
    cap_b = %{"capabilityId" => "b"}

    a =
      CommandCenter.create("event",
        capabilities: [cap_a, cap_b],
        receipt_refs: ["r2", "r1"],
        evidence_refs: ["e2", "e1"]
      )

    b =
      CommandCenter.create("event",
        capabilities: [cap_b, cap_a],
        receipt_refs: ["r1", "r2"],
        evidence_refs: ["e1", "e2"]
      )

    assert a.state_digest == b.state_digest
    assert a.projection_id == b.projection_id
  end
end
