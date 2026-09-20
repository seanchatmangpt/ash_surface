defmodule AshSurface.ObligationTest do
  use ExUnit.Case, async: true

  alias AshSurface.Obligation

  test "keeps stable identity across state transitions while state digest changes" do
    open =
      Obligation.create(
        "zoe:event:holiday#north_gate",
        "Zoe.Security.request_reinforcement",
        "obs_near_miss_1",
        status: :open,
        evidence_refs: ["obs_near_miss_1"]
      )

    assigned =
      Obligation.create(
        "zoe:event:holiday#north_gate",
        "Zoe.Security.request_reinforcement",
        "obs_near_miss_1",
        status: :assigned,
        assigned_to: "security:second_guard",
        evidence_refs: ["obs_near_miss_1"]
      )

    assert open.obligation_id == assigned.obligation_id
    refute open.state_digest == assigned.state_digest
    assert open.authority_boundary == :OBSERVE
    assert Obligation.to_map(assigned)["authorityBoundary"] == "OBSERVE"
  end

  test "requires independent postcondition proof before projecting resolved" do
    assert_raise ArgumentError, ~r/requires a postcondition_ref/, fn ->
      Obligation.create("subject", "capability", "cause", status: :resolved)
    end

    resolved =
      Obligation.create("subject", "capability", "cause",
        status: :resolved,
        receipt_ref: "receipt_1",
        postcondition_ref: "proof_1"
      )

    assert resolved.status == :resolved
    assert resolved.receipt_ref == "receipt_1"
    assert resolved.postcondition_ref == "proof_1"
  end

  test "refuses unknown statuses instead of inventing workflow semantics" do
    assert_raise ArgumentError, ~r/unknown obligation status/, fn ->
      Obligation.create("subject", "capability", "cause", status: :magically_done)
    end
  end
end
