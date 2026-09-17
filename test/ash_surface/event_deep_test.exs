defmodule AshSurface.EventDeepTest do
  @moduledoc """
  Deep state-based coverage of `AshSurface.Event` projection invariants:

  * sequence monotonicity semantics per subject (identity namespacing, distinctness, verbatim carry)
  * OBSERVE-only authority boundary carried structurally (default, no widening switch, pinned wire form)
  * receipt/evidence reference shapes (optional, verbatim, excluded from identity)
  * minimal-field validation (`@enforce_keys` rejects missing event_id/sequence)
  * serialization shape stability (golden key set, JSON round-trip, digest formula)
  """

  use ExUnit.Case, async: true
  alias AshSurface.Event

  describe "sequence monotonicity semantics per subject" do
    test "sequence is part of event identity: advancing it per subject yields distinct events" do
      base = fn seq -> Event.create("zoe:KingdomNeed#need_7", seq, "need_selected") end
      events = Enum.map(0..4, base)

      assert events |> Enum.map(& &1.sequence) == [0, 1, 2, 3, 4]
      ids = Enum.map(events, & &1.event_id)
      digests = Enum.map(events, & &1.state_digest)
      assert length(Enum.uniq(ids)) == 5
      assert length(Enum.uniq(digests)) == 5
    end

    test "sequences are namespaced per subject: same sequence under two subjects never collides" do
      a = Event.create("zoe:KingdomNeed#need_7", 3, "need_selected")
      b = Event.create("zoe:KingdomNeed#need_9", 3, "need_selected")

      refute a.event_id == b.event_id
      refute a.state_digest == b.state_digest
    end

    test "sequence and payload are carried verbatim (no bumping, no reordering, no coercion)" do
      large = 4_294_967_296

      ev =
        Event.create("zoe:KingdomNeed#need_7", large, "obligation_shifted",
          payload: %{"k" => "v"}
        )

      assert ev.sequence == large
      assert Event.to_map(ev)["sequence"] == large
      assert Event.create("s", 0, "t").sequence == 0
    end

    test "projection is idempotent: identical subject/sequence/type/payload replays to the identical event" do
      opts = [
        payload: %{"selected_candidate" => "person_01"},
        occurred_at: ~U[2026-09-15 10:00:00Z]
      ]

      first = Event.create("zoe:KingdomNeed#need_42", 1, "need_selected", opts)
      replay = Event.create("zoe:KingdomNeed#need_42", 1, "need_selected", opts)

      assert first.event_id == replay.event_id
      assert first.state_digest == replay.state_digest
      assert first == replay
    end
  end

  describe "OBSERVE-only authority boundary carried structurally" do
    test "defaults to :OBSERVE on the struct with no options supplied" do
      assert %Event{authority_boundary: :OBSERVE} = Event.create("s", 1, "t")
    end

    test "create/4 exposes no authority switch: a widening option is ignored, not honored" do
      ev = Event.create("s", 1, "t", authority_boundary: :ACTUATE, payload: %{})

      assert ev.authority_boundary == :OBSERVE
      assert Event.to_map(ev)["authorityBoundary"] == "OBSERVE"
    end

    test "the wire form pins OBSERVE: even a forged struct field cannot widen the serialized boundary" do
      ev = Event.create("s", 1, "t")
      forged = %Event{ev | authority_boundary: :ACTUATE}

      assert Event.to_map(forged)["authorityBoundary"] == "OBSERVE"
    end
  end

  describe "receipt and evidence reference shapes" do
    test "both references are optional and default to nil on the struct" do
      ev = Event.create("s", 1, "t")

      assert ev.evidence_ref == nil
      assert ev.receipt_ref == nil
    end

    test "to_map/1 always carries both reference keys, nil when absent, verbatim when present" do
      bare = Event.to_map(Event.create("s", 1, "t"))
      assert bare["evidenceRef"] == nil
      assert bare["receiptRef"] == nil

      annotated =
        Event.to_map(
          Event.create("s", 1, "t", evidence_ref: "evd_b3_1a2b3c", receipt_ref: "rcpt_b3_8f910a2")
        )

      assert annotated["evidenceRef"] == "evd_b3_1a2b3c"
      assert annotated["receiptRef"] == "rcpt_b3_8f910a2"
    end

    test "references are annotations, not identity: they never perturb event_id or state_digest" do
      plain = Event.create("s", 1, "t")
      annotated = Event.create("s", 1, "t", evidence_ref: "evd_x", receipt_ref: "rcpt_y")

      assert annotated.event_id == plain.event_id
      assert annotated.state_digest == plain.state_digest
    end
  end

  describe "subject/type admission boundary (F3 constructor validation)" do
    test "subject_ref must be a non-empty binary (it is a digest-bound identity input)" do
      for bad <- ["", :subject, 42, nil, %{}] do
        assert_raise ArgumentError, ~r/non-empty binary subject_ref/, fn ->
          Event.create(bad, 1, "need_selected")
        end
      end
    end

    test "event_type must be a non-empty binary (mirrors the zod eventType min(1) row)" do
      for bad <- ["", :need_selected, 42, nil] do
        assert_raise ArgumentError, ~r/non-empty binary event_type/, fn ->
          Event.create("zoe:KingdomNeed#need_7", 1, bad)
        end
      end
    end
  end

  describe "minimal-field validation (enforced keys)" do
    test "constructing the struct without event_id is rejected" do
      assert_raise ArgumentError, ~r/:event_id/, fn ->
        struct!(Event, sequence: 1, subject_ref: "s", event_type: "t", state_digest: "d")
      end
    end

    test "constructing the struct without sequence is rejected even when event_id is present" do
      assert_raise ArgumentError, ~r/:sequence/, fn ->
        struct!(Event,
          event_id: "ev_0123456789abcdef",
          subject_ref: "s",
          event_type: "t",
          state_digest: "d"
        )
      end
    end

    test "the remaining projection identity fields are equally enforced" do
      assert_raise ArgumentError, ~r/:subject_ref/, fn ->
        struct!(Event, event_id: "ev_x", sequence: 1, event_type: "t", state_digest: "d")
      end

      assert_raise ArgumentError, ~r/:state_digest/, fn ->
        struct!(Event, event_id: "ev_x", sequence: 1, subject_ref: "s", event_type: "t")
      end
    end
  end

  describe "serialization shape stability (golden map/JSON)" do
    test "to_map/1 projects exactly the golden camelCase key set" do
      ev = Event.create("zoe:KingdomNeed#need_42", 1, "need_selected", payload: %{"k" => "v"})

      assert Map.keys(Event.to_map(ev)) |> Enum.sort() == [
               "authorityBoundary",
               "eventId",
               "eventType",
               "evidenceRef",
               "occurredAt",
               "payload",
               "receiptRef",
               "sequence",
               "stateDigest",
               "subjectRef"
             ]
    end

    test "golden map for fully fixed inputs is byte-stable" do
      ev =
        Event.create("s:1", 2, "t", payload: %{}, occurred_at: ~U[2026-09-15 10:00:00Z])

      assert Event.to_map(ev) == %{
               "eventId" => ev.event_id,
               "sequence" => 2,
               "subjectRef" => "s:1",
               "eventType" => "t",
               "stateDigest" => ev.state_digest,
               "evidenceRef" => nil,
               "receiptRef" => nil,
               "payload" => %{},
               "occurredAt" => "2026-09-15T10:00:00Z",
               "authorityBoundary" => "OBSERVE"
             }
    end

    test "JSON encoding round-trips to the identical projection map with every golden key present" do
      ev =
        Event.create("s:1", 2, "t", payload: %{"k" => "v"}, occurred_at: ~U[2026-09-15 10:00:00Z])

      map = Event.to_map(ev)
      json = Jason.encode!(map)

      assert Jason.decode!(json) == map

      for key <- Map.keys(map) do
        assert String.contains?(json, "\"#{key}\"")
      end
    end

    test "identity formula is stable: state_digest is sha256 of subject:sequence:type:payload, event_id its 16-char prefix" do
      payload = %{"selected_candidate" => "person_01"}
      ev = Event.create("zoe:KingdomNeed#need_42", 1, "need_selected", payload: payload)

      expected_digest =
        :crypto.hash(:sha256, "zoe:KingdomNeed#need_42:1:need_selected:#{Jason.encode!(payload)}")
        |> Base.encode16(case: :lower)

      assert ev.state_digest == expected_digest
      assert ev.event_id == "ev_" <> binary_part(expected_digest, 0, 16)
      assert String.length(ev.event_id) == 19
    end

    test "payload participates in identity: same sequence, different payload, distinct event" do
      a = Event.create("s", 1, "t", payload: %{"choice" => "a"})
      b = Event.create("s", 1, "t", payload: %{"choice" => "b"})

      refute a.event_id == b.event_id
      refute a.state_digest == b.state_digest
    end
  end
end
