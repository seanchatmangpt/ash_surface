defmodule AshSurface.CommitmentBoundaryCoverageTest do
  @moduledoc """
  Pins the admission and projection laws of `AshSurface.CommitmentBoundary`:
  the 3-arity default is a CONDITIONAL/UNCONFIRMED boundary that hands off to
  BRCE with no DO authority, unknown enum values and malformed ref lists are
  refused, and `expires_at` projects identically whether supplied as a
  `DateTime` or as its ISO-8601 string.
  """
  use ExUnit.Case, async: true

  alias AshSurface.CommitmentBoundary

  test "create/3 defaults to an unconfirmed conditional boundary with a BRCE handoff" do
    boundary = CommitmentBoundary.create("person:1", "Zoe.Plan.commit", "books the venue")

    assert boundary ==
             CommitmentBoundary.create("person:1", "Zoe.Plan.commit", "books the venue", [])

    assert boundary.reversibility == :CONDITIONAL
    assert boundary.confirmation_state == :UNCONFIRMED
    assert boundary.next_handoff == :BRCE
    assert boundary.authority_ceiling == :CONSTRUCT
    assert CommitmentBoundary.to_map(boundary)["doAuthority"] == false
    assert CommitmentBoundary.to_map(boundary)["expiresAt"] == nil
  end

  test "unknown reversibility and confirmation_state are refused" do
    assert_raise ArgumentError, "unknown reversibility: :MAYBE", fn ->
      CommitmentBoundary.create("s", "a", "c", reversibility: :MAYBE)
    end

    assert_raise ArgumentError, "unknown confirmation_state: :EXECUTED", fn ->
      CommitmentBoundary.create("s", "a", "c", confirmation_state: :EXECUTED)
    end
  end

  test "external effects and evidence refs must be lists of strings" do
    assert_raise ArgumentError, "external_effects must contain only strings", fn ->
      CommitmentBoundary.create("s", "a", "c", external_effects: [:email])
    end

    assert_raise ArgumentError, "evidence_refs must be a list", fn ->
      CommitmentBoundary.create("s", "a", "c", evidence_refs: "ev_1")
    end
  end

  test "expires_at as DateTime or ISO-8601 string yields the same digest and projection" do
    at = ~U[2026-10-01 12:00:00Z]
    iso = DateTime.to_iso8601(at)

    from_datetime = CommitmentBoundary.create("s", "a", "c", expires_at: at)
    from_string = CommitmentBoundary.create("s", "a", "c", expires_at: iso)

    assert from_datetime.expires_at == at
    assert from_string.expires_at == iso
    assert from_datetime.state_digest == from_string.state_digest
    assert from_datetime.boundary_id == from_string.boundary_id
    assert CommitmentBoundary.to_map(from_datetime)["expiresAt"] == "2026-10-01T12:00:00Z"
    assert CommitmentBoundary.to_map(from_string)["expiresAt"] == "2026-10-01T12:00:00Z"

    refute from_datetime.state_digest == CommitmentBoundary.create("s", "a", "c").state_digest
  end

  test "an expires_at that is neither nil, DateTime nor string is a named refusal" do
    assert_raise ArgumentError,
                 "expires_at must be a DateTime, ISO-8601 string or nil, got: ~D[2026-09-28]",
                 fn -> CommitmentBoundary.create("s", "a", "c", expires_at: ~D[2026-09-28]) end
  end
end
