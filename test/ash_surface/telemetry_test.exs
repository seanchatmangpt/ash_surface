defmodule AshSurface.TelemetryTest do
  @moduledoc """
  Observability law: transport selection, receipt refusals and intent dispatch
  emit `:telemetry` events carrying only metadata (never payload values); with
  no handler attached callers are unaffected; a raising handler is detached by
  `:telemetry` and never breaks a caller. Real handlers, real emitted state.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Intent.Dispatch
  alias AshSurface.IR.EventProjection
  alias AshSurface.Transport

  defmodule Bus do
    @moduledoc false
    @behaviour AshSurface.Intent.CommandBus
    @impl true
    def submit(%{payload: %{refuse: true}}, _ctx), do: {:error, :REFUSED_NO_AUTHORITY}
    def submit(_intent, _ctx), do: {:ok, "receipt:1"}
  end

  # Handlers append {event, measurements, metadata} to an Agent; state is read back.
  def record(event, measurements, metadata, agent),
    do: Agent.update(agent, &[{event, measurements, metadata} | &1])

  def explode(_event, _measurements, _metadata, _config), do: raise("handler bug")

  defp capture(events) do
    agent = start_supervised!({Agent, fn -> [] end})
    id = "telemetry-test-#{System.unique_integer([:positive])}"
    :ok = :telemetry.attach_many(id, events, &__MODULE__.record/4, agent)
    on_exit(fn -> :telemetry.detach(id) end)
    fn -> agent |> Agent.get(& &1) |> Enum.reverse() end
  end

  test "events/0 lists the three emitted events" do
    assert AshSurface.Telemetry.events() == [
             [:ash_surface, :transport, :select],
             [:ash_surface, :receipt, :refused],
             [:ash_surface, :intent, :dispatch]
           ]
  end

  describe "[:ash_surface, :transport, :select]" do
    test "carries the decision state and nothing else" do
      events = capture([[:ash_surface, :transport, :select]])

      {:ok, decision} =
        Transport.select([:http, :phoenix_channel], [:phoenix_channel],
          preferred: :http,
          action_id: "Ticket#read"
        )

      assert [{[:ash_surface, :transport, :select], measurements, metadata}] = events.()
      assert measurements == %{available_count: 1}

      assert metadata == %{
               action_id: "Ticket#read",
               declared: [:http, :phoenix_channel],
               available: [:phoenix_channel],
               selected: decision.selected,
               reason: :preferred_unavailable,
               dimensions: :undelegated
             }
    end

    test "records declared dimensions and the weighed reason" do
      events = capture([[:ash_surface, :transport, :select]])
      facts = %{http: %{cost: :low}, phoenix_channel: %{cost: :high}}

      {:ok, _} =
        Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel],
          preferred: :phoenix_channel,
          facts: facts
        )

      assert [{_, _, %{selected: :http, reason: :dimension_weighed, dimensions: :declared}}] =
               events.()
    end

    test "a refused selection emits nothing" do
      events = capture([[:ash_surface, :transport, :select]])
      assert {:error, _} = Transport.select([:http], [:carrier_pigeon])
      assert events.() == []
    end
  end

  describe "[:ash_surface, :receipt, :refused]" do
    test "emits standing and reason class, never receipt values" do
      events = capture([[:ash_surface, :receipt, :refused]])

      assert {:error, %{standing: :REFUSED_INVALID_SUBJECT}} = EventProjection.from_receipt(%{})

      assert {:error, %{standing: :REFUSED_MISSING_TIMESTAMP}} =
               EventProjection.from_receipt(%{
                 "actionId" => "A#b",
                 "input" => %{"secret" => "s3"}
               })

      assert [
               {_, %{count: 1},
                %{standing: :REFUSED_INVALID_SUBJECT, reason_class: :unresolvable_subject_ref}},
               {_, _,
                %{
                  standing: :REFUSED_MISSING_TIMESTAMP,
                  reason_class: :no_parseable_receipt_timestamp
                } = md}
             ] = events.()

      assert Map.keys(md) |> Enum.sort() == [:reason_class, :standing]
    end

    test "digest mismatch is observed; a projected receipt is not" do
      events = capture([[:ash_surface, :receipt, :refused]])
      ts = "2026-09-28T00:00:00Z"

      assert {:ok, _} = EventProjection.from_receipt(%{"actionId" => "A#b", "timestamp" => ts})

      bad = %{"actionId" => "A#b", "timestamp" => ts, "receiptHash" => String.duplicate("0", 64)}

      assert {:error, %{standing: :REFUSED_RECEIPT_DIGEST_MISMATCH}} =
               EventProjection.from_receipt(bad)

      assert [
               {_, _,
                %{
                  standing: :REFUSED_RECEIPT_DIGEST_MISMATCH,
                  reason_class: :receipt_digest_mismatch
                }}
             ] =
               events.()
    end
  end

  describe "[:ash_surface, :intent, :dispatch]" do
    test "classifies submitted, bus error and pre-bus refusals" do
      events = capture([[:ash_surface, :intent, :dispatch]])

      assert {:ok, "receipt:1"} = Dispatch.submit(%{action_id: "A#b", note: "secret"}, Bus, %{})

      assert {:error, :REFUSED_NO_AUTHORITY} =
               Dispatch.submit(%{action_id: "A#b", refuse: true}, Bus, %{})

      assert {:error, :REFUSED_UNKNOWN_ACTION} =
               Dispatch.submit(%{action_id: "Z#z"}, Bus, %{admitted_action_ids: ["A#b"]})

      assert {:error, {:invalid_candidate, :missing_action_id}} = Dispatch.submit(%{}, Bus, %{})
      assert {:error, :REFUSED_NO_COMMAND_BUS} = Dispatch.submit(%{action_id: "A#b"}, nil, %{})

      assert Enum.map(events.(), fn {_e, _m, md} -> {md.action_id, md.outcome} end) == [
               {"A#b", :submitted},
               {"A#b", :bus_error},
               {"Z#z", {:refused, :unknown_action}},
               {nil, {:refused, :invalid_candidate}},
               {"A#b", {:refused, :no_command_bus}}
             ]
    end

    test "no payload value ever appears in the event" do
      events = capture([[:ash_surface, :intent, :dispatch]])
      {:ok, _} = Dispatch.submit(%{action_id: "A#b", note: "hunter2"}, Bus, %{})
      refute inspect(events.()) =~ "hunter2"
    end
  end

  describe "observer safety" do
    test "with no handler attached callers behave identically" do
      assert {:ok, %{selected: :http}} = Transport.select([:http], [:http])
      assert {:ok, "receipt:1"} = Dispatch.submit(%{action_id: "A#b"}, Bus, %{})
    end

    test "a raising handler is detached and never breaks the caller" do
      event = [:ash_surface, :transport, :select]
      id = "telemetry-explode-#{System.unique_integer([:positive])}"
      :ok = :telemetry.attach(id, event, &__MODULE__.explode/4, nil)
      on_exit(fn -> :telemetry.detach(id) end)
      assert Enum.any?(:telemetry.list_handlers(event), &(&1.id == id))

      assert {:ok, %{selected: :http}} = Transport.select([:http], [:http])

      refute Enum.any?(:telemetry.list_handlers(event), &(&1.id == id))
      assert {:ok, %{selected: :http}} = Transport.select([:http], [:http])
    end
  end
end
