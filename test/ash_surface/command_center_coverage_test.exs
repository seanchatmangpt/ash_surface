defmodule AshSurface.CommandCenterCoverageTest do
  @moduledoc """
  Pins the admission laws of `AshSurface.CommandCenter.create/2`: the empty
  default projection is deterministic and OBSERVE-only, and every malformed
  input (unknown standing, non-list collections, wrongly typed members) is
  refused with a precise `ArgumentError` before any digest is computed.
  """
  use ExUnit.Case, async: true

  alias AshSurface.{CommandCenter, Observation}

  test "create/1 defaults to an empty PARTIAL_ALIVE projection identical to create/2 with []" do
    center = CommandCenter.create("zoe:event:empty")

    assert center == CommandCenter.create("zoe:event:empty", [])
    assert center.standing == :PARTIAL_ALIVE
    assert center.authority_boundary == :OBSERVE
    assert center.observations == []
    assert center.capabilities == []
    assert center.projection_id == "cc_" <> binary_part(center.state_digest, 0, 16)
    refute center.state_digest == CommandCenter.create("zoe:event:other").state_digest
  end

  test "unknown standing is refused" do
    assert_raise ArgumentError, "unknown command-center standing: :DONE", fn ->
      CommandCenter.create("s", standing: :DONE)
    end
  end

  test "struct collections must be lists of the exact struct type" do
    assert_raise ArgumentError,
                 "observations must contain only AshSurface.Observation values",
                 fn -> CommandCenter.create("s", observations: [%{"gate" => "open"}]) end

    observation = Observation.create("s", %{"gate" => "open"})

    assert_raise ArgumentError,
                 "obligations must contain only AshSurface.Obligation values",
                 fn -> CommandCenter.create("s", obligations: [observation]) end

    assert_raise ArgumentError, "planning_episodes must be a list", fn ->
      CommandCenter.create("s", planning_episodes: :none)
    end
  end

  test "capabilities must be a list of maps" do
    assert_raise ArgumentError, "capabilities must contain only maps", fn ->
      CommandCenter.create("s", capabilities: ["Zoe.Security.request_reinforcement"])
    end

    assert_raise ArgumentError, "capabilities must be a list", fn ->
      CommandCenter.create("s", capabilities: %{"capabilityId" => "x"})
    end
  end

  test "receipt and evidence refs must be lists of strings" do
    assert_raise ArgumentError, "receipt_refs must contain only strings", fn ->
      CommandCenter.create("s", receipt_refs: [:receipt_1])
    end

    assert_raise ArgumentError, "evidence_refs must be a list", fn ->
      CommandCenter.create("s", evidence_refs: "field_report_1")
    end
  end
end
