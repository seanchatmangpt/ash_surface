defmodule AshSurface.IR.EventProjectionTest do
  @moduledoc """
  Chicago zero-config coverage of `AshSurface.IR.EventProjection.from_receipt/2`,
  the consequence -> observation back-projection:

  * full-sections projection: every receipt section lands verbatim in the
    `AshSurface.Event` law (subject, payload, receipt_ref, occurred_at, sequence)
  * nil-semantic fallback: a missing/blank `semantic.subject_iri` falls back to
    `ash:<resource>#<action>` (and, minimally, to the receipt's own actionId)
  * OBSERVE-only law: DO-consequence receipts never widen authority; the
    projection stays `:OBSERVE` structurally because it is manufactured
    through `AshSurface.Event.create/4`
  * typed refusal law (finish-replay-020): a receipt with no parseable
    timestamp or no resolvable subject refuses typed (`REFUSED_*` map) — the
    projection never invents wall clock or identity, so replay is equality
    by construction
  * canonical digest law (finish-replay-020): payload identity is canonical
    (key-sorted) JSON, invariant under map construction history
  """

  use ExUnit.Case, async: true
  alias AshSurface.Event
  alias AshSurface.IR.EventProjection

  # The brokered DO-consequence receipt shape emitted by the consumer runtime
  # (test/js/consumer_e2e_runner.mjs step 5): actionId, input, consequence,
  # dispatchState, selectedTransport, timestamp, receiptHash.
  @full_receipt %{
    "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
    "input" => %{
      "member_id" => "member_zoela_01",
      "milestone_id" => "milestone_serve_42",
      "cost_physical" => 10,
      "reward_spiritual" => 100
    },
    "consequence" => %{
      "member_id" => "member_zoela_01",
      "milestone_id" => "milestone_serve_42",
      "status" => "completed"
    },
    "dispatchState" => "completed",
    "selectedTransport" => "http",
    "timestamp" => "2026-09-15T10:00:00Z",
    "receiptHash" => "b3f9c0a1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9",
    "authorityBoundary" => "DO",
    "doAuthority" => true
  }

  @full_ir_action %{
    "resource" => "AshSurface.Fixtures.VolunteerMilestone",
    "action" => "record",
    "semantic" => %{"subject_iri" => "zoe:KingdomNeed#need_42"},
    "doAuthority" => true
  }

  describe "full-sections projection" do
    test "every receipt section back-projects verbatim into the Event law" do
      assert {:ok, event} = EventProjection.from_receipt(@full_receipt, @full_ir_action)

      # Subject binding: IR semantic subject_iri wins over every other name.
      assert event.subject_ref == "zoe:KingdomNeed#need_42"
      # Consequence is the payload, receiptHash is the receipt_ref.
      assert event.payload == @full_receipt["consequence"]
      assert event.receipt_ref == @full_receipt["receiptHash"]
      # Timestamp is parsed, not invented.
      assert event.occurred_at == ~U[2026-09-15 10:00:00Z]
      # Event identity is content-addressed by the reused Event law.
      assert String.starts_with?(event.event_id, "ev_")
      assert event.event_type == "state_transition"
      assert is_binary(event.state_digest)

      assert event ==
               Event.create(
                 "zoe:KingdomNeed#need_42",
                 0,
                 "state_transition",
                 payload: @full_receipt["consequence"],
                 receipt_ref: @full_receipt["receiptHash"],
                 occurred_at: ~U[2026-09-15 10:00:00Z]
               )
    end

    test "wire form pins the observation boundary and carries the receipt sections" do
      assert {:ok, event} = EventProjection.from_receipt(@full_receipt, @full_ir_action)
      map = Event.to_map(event)

      assert map["subjectRef"] == "zoe:KingdomNeed#need_42"
      assert map["receiptRef"] == @full_receipt["receiptHash"]
      assert map["payload"]["status"] == "completed"
      assert map["occurredAt"] == "2026-09-15T10:00:00Z"
      assert map["authorityBoundary"] == "OBSERVE"
    end

    test "back-projection is idempotent: replaying the identical receipt yields the identical event" do
      assert EventProjection.from_receipt(@full_receipt, @full_ir_action) ==
               EventProjection.from_receipt(@full_receipt, @full_ir_action)
    end

    test "replay equality holds even when the consequence map is rebuilt in a different construction order" do
      # >32 keys forces the HAMT iteration boundary where a raw (non-canonical)
      # payload encoding could once leak map construction history into the
      # digest. Both maps below carry the same content built through opposite
      # insertion paths; the projection must not be able to tell them apart.
      forward = Map.new(1..40, fn i -> {"field_#{i}", "value_#{i}"} end)
      backward = forward |> Map.to_list() |> Enum.reverse() |> Map.new()

      original = %{@full_receipt | "consequence" => Map.put(backward, "status", "completed")}
      permuted = %{@full_receipt | "consequence" => Map.put(forward, "status", "completed")}

      assert original["consequence"] == permuted["consequence"]

      assert EventProjection.from_receipt(original, @full_ir_action) ==
               EventProjection.from_receipt(permuted, @full_ir_action)
    end

    test "a receipt-carried sequence is carried verbatim instead of being invented" do
      assert {:ok, event} =
               EventProjection.from_receipt(
                 Map.put(@full_receipt, "sequence", 7),
                 @full_ir_action
               )

      assert event.sequence == 7
    end
  end

  describe "nil-semantic fallback" do
    test "missing semantic section falls back to ash:<resource>#<action>" do
      ir = Map.delete(@full_ir_action, "semantic")

      assert {:ok, event} = EventProjection.from_receipt(@full_receipt, ir)

      assert event.subject_ref == "ash:AshSurface.Fixtures.VolunteerMilestone#record"
    end

    test "nil semantic and blank subject_iri fall back the same way" do
      assert {:ok, first} =
               EventProjection.from_receipt(@full_receipt, %{
                 "resource" => "AshSurface.Fixtures.VolunteerMilestone",
                 "action" => "record",
                 "semantic" => nil
               })

      assert {:ok, second} =
               EventProjection.from_receipt(@full_receipt, %{
                 "resource" => "AshSurface.Fixtures.VolunteerMilestone",
                 "action" => "record",
                 "semantic" => %{"subject_iri" => ""}
               })

      assert first.subject_ref == "ash:AshSurface.Fixtures.VolunteerMilestone#record"
      assert second.subject_ref == first.subject_ref
    end

    test "minimal IR action with only the receipt's actionId still resolves a subject" do
      assert {:ok, event} = EventProjection.from_receipt(@full_receipt, %{})

      assert event.subject_ref == "ash:AshSurface.Fixtures.VolunteerMilestone#record"
      assert event.authority_boundary == :OBSERVE
    end

    test "atom-keyed IR actions and receipts project identically to string-keyed ones" do
      atom_receipt = %{
        action_id: "AshSurface.Fixtures.VolunteerMilestone#record",
        consequence: %{"status" => "completed"},
        receipt_hash: "abc123",
        timestamp: "2026-09-15T10:00:00Z"
      }

      atom_ir = %{
        resource: "AshSurface.Fixtures.VolunteerMilestone",
        action: "record",
        semantic: %{subject_iri: "zoe:KingdomNeed#need_42"}
      }

      assert {:ok, event} = EventProjection.from_receipt(atom_receipt, atom_ir)

      assert event.subject_ref == "zoe:KingdomNeed#need_42"
      assert event.receipt_ref == "abc123"
    end
  end

  describe "OBSERVE-only law" do
    test "a DO-consequence receipt with DO authority on both inputs still projects :OBSERVE" do
      assert {:ok, event} = EventProjection.from_receipt(@full_receipt, @full_ir_action)

      # @full_receipt carries authorityBoundary DO / doAuthority true and the
      # IR action claims doAuthority: back-projection must not widen.
      assert event.authority_boundary == :OBSERVE
      assert Event.to_map(event)["authorityBoundary"] == "OBSERVE"
    end

    test "an unknown-after-dispatch receipt still back-projects as a lawful observation" do
      unknown = %{@full_receipt | "dispatchState" => "unknown_after_dispatch"}

      assert {:ok, event} = EventProjection.from_receipt(unknown, @full_ir_action)

      assert event.authority_boundary == :OBSERVE
      assert event.subject_ref == "zoe:KingdomNeed#need_42"
      assert event.receipt_ref == @full_receipt["receiptHash"]
    end

    test "no receipt or IR section can smuggle a non-OBSERVE boundary through the wire form" do
      smuggle_attempts = [
        %{@full_receipt | "authorityBoundary" => "DO", "doAuthority" => true},
        Map.merge(@full_receipt, %{"authority_boundary" => :DO, "boundary" => "ACTUATE"})
      ]

      for receipt <- smuggle_attempts do
        assert {:ok, event} = EventProjection.from_receipt(receipt, @full_ir_action)
        assert event.authority_boundary == :OBSERVE
        assert Event.to_map(event)["authorityBoundary"] == "OBSERVE"
      end
    end
  end

  describe "typed refusal law (never invent receipt content)" do
    test "a receipt with no timestamp refuses instead of falling back to wall clock" do
      timestampless = Map.delete(@full_receipt, "timestamp")

      assert {:error, refusal} = EventProjection.from_receipt(timestampless, @full_ir_action)

      assert refusal == %{
               standing: :REFUSED_MISSING_TIMESTAMP,
               reason: {:no_parseable_receipt_timestamp, nil},
               authority_boundary: :OBSERVE
             }
    end

    test "a receipt with an unparseable timestamp refuses typed, naming the raw value" do
      garbage = %{@full_receipt | "timestamp" => "not-a-timestamp"}

      assert {:error, refusal} = EventProjection.from_receipt(garbage, @full_ir_action)

      assert refusal.standing == :REFUSED_MISSING_TIMESTAMP
      assert refusal.reason == {:no_parseable_receipt_timestamp, "not-a-timestamp"}
      assert refusal.authority_boundary == :OBSERVE
    end

    test "a nil atom-key timestamp refuses identically (key spelling does not weaken the law)" do
      assert {:error, refusal} =
               EventProjection.from_receipt(
                 %{action_id: "R#record", consequence: %{}, timestamp: nil},
                 nil
               )

      assert refusal.standing == :REFUSED_MISSING_TIMESTAMP
    end

    test "the timestamp refusal preserves replay equality by construction: two refusals are identical" do
      timestampless = Map.delete(@full_receipt, "timestamp")

      assert EventProjection.from_receipt(timestampless, @full_ir_action) ==
               EventProjection.from_receipt(timestampless, @full_ir_action)
    end

    test "a receipt resolving no subject refuses :REFUSED_INVALID_SUBJECT instead of raising" do
      subjectless_receipt = Map.delete(@full_receipt, "actionId")

      assert {:error, refusal} = EventProjection.from_receipt(subjectless_receipt, %{})

      assert refusal == %{
               standing: :REFUSED_INVALID_SUBJECT,
               reason: :unresolvable_subject_ref,
               authority_boundary: :OBSERVE
             }
    end

    test "the projection production route Event.from_receipt/2 returns the identical result" do
      assert Event.from_receipt(@full_receipt, @full_ir_action) ==
               EventProjection.from_receipt(@full_receipt, @full_ir_action)

      assert {:ok, event} = Event.from_receipt(@full_receipt, @full_ir_action)
      assert event.authority_boundary == :OBSERVE
    end
  end
end
