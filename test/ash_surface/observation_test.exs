defmodule AshSurface.ObservationTest do
  use ExUnit.Case, async: true
  alias AshSurface.Observation

  test "creates a verified observation projection with content-addressed stateDigest" do
    facts = %{
      "need_status" => "active",
      "open_opportunities" => 3,
      "unassigned_roles" => ["care_driver", "intercessor"]
    }

    obs = Observation.create("zoe:KingdomNeed#need_42", facts, standing: :ALIVE)

    assert obs.authority_boundary == :OBSERVE
    assert String.starts_with?(obs.observation_id, "obs_")
    assert byte_size(obs.state_digest) == 64
    assert obs.standing == :ALIVE

    map = Observation.to_map(obs)
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["exactSubject"] == "zoe:KingdomNeed#need_42"
    assert map["facts"]["open_opportunities"] == 3
  end
end
