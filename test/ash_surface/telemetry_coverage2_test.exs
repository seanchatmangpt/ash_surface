defmodule AshSurface.TelemetryCoverage2Test do
  @moduledoc """
  Laws pinned: telemetry classifies dispatch outcomes and refusal reasons into
  a closed, value-free metadata vocabulary. Unknown result shapes are a
  `:bus_error`, never a fabricated success; unclassifiable refusal reasons are
  `:unclassified` and never leak their values. Handlers are global state, so
  this file is `async: false` and detaches every handler on exit.
  """

  use ExUnit.Case, async: false

  alias AshSurface.Telemetry

  defp capture(event) do
    id = "telemetry-cov2-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        id,
        event,
        fn _e, m, md, _ -> send(parent, {id, m, md}) end,
        nil
      )

    on_exit(fn -> :telemetry.detach(id) end)
    id
  end

  test "an unrecognised dispatch result is a bus error" do
    id = capture([:ash_surface, :intent, :dispatch])
    Telemetry.intent_dispatched("A#b", :weird)
    assert_received {^id, %{count: 1}, %{action_id: "A#b", outcome: :bus_error}}
  end

  test "a non-binary action id is dropped from metadata" do
    id = capture([:ash_surface, :intent, :dispatch])
    Telemetry.intent_dispatched(:not_a_binary, {:ok, %{}})
    assert_received {^id, _, %{action_id: nil, outcome: :submitted}}
  end

  test "refusal reasons are classified by head atom, else unclassified" do
    id = capture([:ash_surface, :receipt, :refused])

    Telemetry.receipt_refused(%{standing: :REFUSED_A, reason: :plain})
    Telemetry.receipt_refused(%{standing: :REFUSED_A, reason: {:tagged, "secret"}})
    Telemetry.receipt_refused(%{standing: :REFUSED_A, reason: {"binary head", 1}})
    Telemetry.receipt_refused(%{standing: :REFUSED_A, reason: {}})
    Telemetry.receipt_refused(%{standing: :REFUSED_A, reason: "free text secret"})

    classes =
      for _ <- 1..5 do
        assert_received {^id, _, %{reason_class: class}}
        class
      end

    assert classes == [:plain, :tagged, :unclassified, :unclassified, :unclassified]
  end
end
