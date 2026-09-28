defmodule AshSurface.EventProjectionCoverageTest do
  @moduledoc """
  Pins the receipt back-projection law of `AshSurface.IR.EventProjection`
  and its sole production route `AshSurface.Event.from_receipt/1,2`:

    * with no IR action (the one-argument form), the subject falls back to
      `ash:<actionId>` from the receipt itself;
    * a receipt whose time is already a `DateTime` is carried verbatim as
      `occurred_at` — no re-parsing, no wall-clock invention — and yields
      the same event (identity, digest, time) as its ISO-8601 spelling;
    * `Event.from_receipt/1` and `EventProjection.from_receipt/1` are the
      same projection.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Event
  alias AshSurface.IR.EventProjection

  @occurred ~U[2026-09-28 09:30:00Z]

  defp receipt(timestamp) do
    %{
      "actionId" => "Helpdesk.Support.Ticket#open",
      "consequence" => %{"ticketId" => "t_1", "status" => "open"},
      "receiptHash" => "rcpt_opaque_1",
      "sequence" => 7,
      "timestamp" => timestamp
    }
  end

  test "a DateTime receipt time is carried verbatim; one-arg form falls back to ash:<actionId>" do
    assert {:ok, event} = EventProjection.from_receipt(receipt(@occurred))

    assert event.occurred_at == @occurred
    assert event.subject_ref == "ash:Helpdesk.Support.Ticket#open"
    assert event.sequence == 7
    assert event.event_type == "state_transition"
    assert event.receipt_ref == "rcpt_opaque_1"
    assert event.payload == %{"ticketId" => "t_1", "status" => "open"}
    assert event.authority_boundary == :OBSERVE
  end

  test "DateTime and ISO-8601 spellings of the same instant project the same event" do
    assert {:ok, from_dt} = EventProjection.from_receipt(receipt(@occurred))

    assert {:ok, from_iso} =
             EventProjection.from_receipt(receipt(DateTime.to_iso8601(@occurred)))

    assert from_dt == from_iso
  end

  test "Event.from_receipt/1 is exactly the projection's one-argument form" do
    assert Event.from_receipt(receipt(@occurred)) ==
             EventProjection.from_receipt(receipt(@occurred))

    assert {:error, refusal} = Event.from_receipt(receipt(:not_a_time))
    assert refusal.standing == :REFUSED_MISSING_TIMESTAMP
    assert refusal.reason == {:no_parseable_receipt_timestamp, :not_a_time}
  end
end
