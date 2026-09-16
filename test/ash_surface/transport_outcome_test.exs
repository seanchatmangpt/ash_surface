defmodule AshSurface.TransportOutcomeTest do
  @moduledoc """
  State-based tests of the real `AshSurface.Transport` against the timeout/outcome
  law (see repo AGENTS.md, "Transport law"):

  - selection happens before dispatch;
  - a missing preferred transport may fall back to another admitted transport
    before dispatch only;
  - after dispatch, timeout/disconnect is `UNKNOWN_AFTER_DISPATCH` downstream and
    the module never authorizes automatic replay over another transport;
  - post-dispatch retry requires a separately admitted protocol.

  Current truth: the Elixir module is the pure pre-dispatch selection half of that
  law. It owns the typed reason terms and the post-dispatch fallback fence
  (`fallback_allowed?/1` closes permanently once `mark_dispatched/1` is applied).
  The executing half — a transport timeout during dispatch or reconcile surfacing
  as the typed `TRANSPORT_OUTCOME_UNKNOWN` error with an `unknown_after_dispatch`
  receipt that never flips to `completed` — lives in the projected JavaScript
  runtime at `priv/static/ash_surface_runtime.mjs`. That half is deliberately not
  driven from this file: executing it requires the pinned `zod` npm dependency
  (see package.json), i.e. an `npm install` environment step, which this hermetic
  suite refuses. Its executable coverage is `test/js/runtime.test.mjs`, run by
  `npm test`.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport

  test "selection returns the typed pre-dispatch decision with exact reason atoms" do
    assert {:ok, %Transport.Decision{} = decision} =
             Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel])

    assert decision.selected == :http
    assert decision.preferred == :http
    assert decision.reason == :preferred_available
    assert decision.declared == [:http, :phoenix_channel]
    assert decision.available == [:http, :phoenix_channel]
    assert decision.action_id == nil

    # A decision is born pre-dispatch: no selection path may claim a dispatched
    # or completed outcome, so no caller can inherit a silent success.
    assert decision.dispatch_state == :not_dispatched
    assert decision.fallback == :pre_dispatch_only
    assert Transport.fallback_allowed?(decision)
  end

  test "pre-dispatch fallback to a declared alternative is lawful and preserves alternatives" do
    assert {:ok, decision} =
             Transport.select([:http, :phoenix_channel], [:phoenix_channel],
               preferred: :http,
               action_id: "AshSurface.Fixtures.VolunteerMilestone#record"
             )

    assert decision.selected == :phoenix_channel
    assert decision.reason == :preferred_unavailable
    assert decision.action_id == "AshSurface.Fixtures.VolunteerMilestone#record"

    # Alternatives are preserved, not pruned, and remain usable only pre-dispatch.
    assert decision.declared == [:http, :phoenix_channel]
    assert decision.available == [:phoenix_channel]
    assert Transport.fallback_allowed?(decision)
  end

  test "refused selections return the exact typed error terms" do
    assert {:error, {:unsupported_transport, %{preferred: :phoenix_channel, available: []}}} =
             Transport.select([:http, :phoenix_channel], [], preferred: :phoenix_channel)

    assert {:error, {:unsupported_transport, %{preferred: :http, available: []}}} =
             Transport.select([:http], [])

    assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
             Transport.select([:http], [:http, :phoenix_channel])

    assert {:error, {:unknown_transport, :carrier_pigeon}} =
             Transport.select([:http], [:http], preferred: :carrier_pigeon)

    assert {:error, {:unknown_transport, [:carrier_pigeon]}} =
             Transport.select([:http, :carrier_pigeon], [:http])

    assert {:error, :transports_must_be_a_list} = Transport.select(:http, [:http])
    assert {:error, :transports_must_be_a_list} = Transport.select([:http], :http)
  end

  test "after dispatch the fallback fence closes for every lawful selection" do
    # A post-dispatch timeout or disconnect must never buy an automatic retry or
    # cross-transport replay, no matter which alternatives remain declared.
    lawful =
      [
        {[:http], [:http], :http},
        {[:http, :phoenix_channel], [:http, :phoenix_channel], :http},
        {[:http, :phoenix_channel], [:phoenix_channel], :http},
        {[:http, :phoenix_channel], [:http, :phoenix_channel], :phoenix_channel}
      ]

    for {declared, available, preferred} <- lawful do
      assert {:ok, decision} = Transport.select(declared, available, preferred: preferred)
      assert Transport.fallback_allowed?(decision)

      dispatched = Transport.mark_dispatched(decision)

      refute Transport.fallback_allowed?(dispatched),
             "post-dispatch fallback leaked for declared=#{inspect(declared)}"

      # Alternatives stay visible for an explicitly admitted retry protocol but
      # the fence marks fallback as pre-dispatch only, forever.
      assert dispatched.declared == declared
      assert dispatched.fallback == :pre_dispatch_only
    end
  end

  test "outcome state never flips implicitly: transitions are explicit, stable, and never completed" do
    assert {:ok, decision} = Transport.select([:http, :phoenix_channel], [:http])

    # mark_dispatched/1 is the only transition; it returns a new decision and
    # never mutates the original in place.
    dispatched = Transport.mark_dispatched(decision)
    assert decision.dispatch_state == :not_dispatched
    assert dispatched.dispatch_state == :dispatched

    # There is no implicit completion and no implicit reset: the admitted state
    # space of this module is only :not_dispatched | :dispatched, and repeated
    # dispatch marking stays stable. An outcome-unknown can therefore never flip
    # to COMPLETED here; resolving it is downstream's explicit job.
    for _ <- 1..3 do
      dispatched = Transport.mark_dispatched(dispatched)
      assert dispatched.dispatch_state == :dispatched
      refute Transport.fallback_allowed?(dispatched)
      assert dispatched.fallback == :pre_dispatch_only
    end

    # An explicit re-dispatch of the same action is a fresh decision; the prior
    # dispatched state is never laundered into the new selection.
    assert {:ok, fresh} =
             Transport.select([:http, :phoenix_channel], [:http],
               action_id: "AshSurface.Fixtures.VolunteerMilestone#record"
             )

    assert fresh.dispatch_state == :not_dispatched
  end
end
