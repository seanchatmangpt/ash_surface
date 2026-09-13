defmodule AshSurface.EventTest do
  use ExUnit.Case, async: true
  alias AshSurface.Event

  test "projects a realtime server observation event" do
    event =
      Event.create("zoe:KingdomNeed#need_42", 1, "need_selected",
        payload: %{"selected_candidate" => "person_01"},
        receipt_ref: "rcpt_b3_8f910a2"
      )

    assert event.authority_boundary == :OBSERVE
    assert event.sequence == 1
    assert String.starts_with?(event.event_id, "ev_")
    assert event.receipt_ref == "rcpt_b3_8f910a2"

    map = Event.to_map(event)
    assert map["authorityBoundary"] == "OBSERVE"
    assert map["sequence"] == 1
    assert map["receiptRef"] == "rcpt_b3_8f910a2"
    assert map["payload"]["selected_candidate"] == "person_01"
  end
end
