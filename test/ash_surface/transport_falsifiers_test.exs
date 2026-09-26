defmodule AshSurface.TransportFalsifiersTest do
  @moduledoc """
  Adversarial falsifiers against the no-silent-replay transport law.

  LAW (AGENTS.md, "Transport law"):

    - Selection happens BEFORE dispatch.
    - A missing preferred transport may fall back to another admitted
      transport only pre-dispatch.
    - After dispatch, timeout/disconnect is `UNKNOWN_AFTER_DISPATCH`; the
      action must never be silently replayed over another transport.
    - Post-dispatch retry requires a separately admitted idempotency
      protocol.

  Each test below is a falsification attempt through the public surface of
  `AshSurface.Transport`. Every attempt that survives is kept here as a
  regression test; the comment on each test names the law clause it guards.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport
  alias AshSurface.Transport.Decision

  # -------------------------------------------------------------------------
  # Adapter double: a scripted, in-process transport adapter. It records every
  # dispatch per commandId, always answers the first dispatch with a timeout,
  # and can then deliver replies late and out of order. It never dispatches on
  # its own; only the law-abiding runtime below can, and only when the module
  # authorizes fallback.
  # -------------------------------------------------------------------------

  defmodule AdapterDouble do
    @moduledoc false
    defstruct [:deadline, now: 0, dispatches: []]

    @doc """
    Law-abiding dispatch of the admitted selection. Returns the timeout that
    real adapters produce; a reply may still arrive later via `late_reply/3`.
    """
    def dispatch(%AdapterDouble{} = adapter, %Decision{} = decision) do
      adapter = %{
        adapter
        | dispatches: [{decision.action_id, decision.selected} | adapter.dispatches]
      }

      {adapter, {:error, :timeout}}
    end

    @doc """
    A reply that arrives at wall-time `at`. Past the deadline it is LATE: it
    may carry an adapter receipt, but a late reply is a fact about the past,
    never authorization for another dispatch.
    """
    def late_reply(%AdapterDouble{} = adapter, action_id, at) do
      latency = if at > adapter.deadline, do: :late, else: :on_time
      {:ok, %{adapter_receipt: {action_id, at}, consequence: :unknown, latency: latency}}
    end

    def dispatch_count(%AdapterDouble{} = adapter, action_id) do
      Enum.count(adapter.dispatches, fn {id, _selected} -> id == action_id end)
    end

    def transports_used(%AdapterDouble{} = adapter, action_id) do
      adapter.dispatches
      |> Enum.reverse()
      |> Enum.filter(fn {id, _selected} -> id == action_id end)
      |> Enum.map(fn {_id, selected} -> selected end)
    end
  end

  # The forbidden move, performed only if the module authorizes it: after a
  # timeout, re-select an alternative admitted transport through the public
  # selection API and dispatch the SAME commandId again. If
  # `Transport.fallback_allowed?/1` ever returns true for a dispatched
  # decision, this helper executes the silent replay and the caller's
  # count/marker assertions fail, proving the defect.
  defp silent_replay_if_authorized(%AdapterDouble{} = adapter, %Decision{} = decision) do
    if Transport.fallback_allowed?(decision) do
      alternative = hd(decision.declared -- [decision.selected])

      {:ok, replay} =
        Transport.select(decision.declared, [alternative],
          preferred: alternative,
          action_id: decision.action_id
        )

      AdapterDouble.dispatch(adapter, replay)
    else
      {adapter, :unknown_after_dispatch}
    end
  end

  defp admit(action_id, opts \\ []) do
    {:ok, decision} = Transport.select([:http], [:http], Keyword.put(opts, :action_id, action_id))
    decision
  end

  # --------------------------------------------------------------------------
  # Falsifier 1: late reply after timeout.
  # LAW: after dispatch, timeout/disconnect is UNKNOWN_AFTER_DISPATCH; do not
  # silently replay the action over another transport.
  # --------------------------------------------------------------------------

  test "late reply after timeout never yields a second dispatch or a fabricated receipt" do
    adapter = %AdapterDouble{deadline: 10}

    # Lawful pre-dispatch selection, then exactly one dispatch, which times out.
    decision = admit("cmd-late-1")
    {adapter, {:error, :timeout}} = AdapterDouble.dispatch(adapter, decision)
    marked = Transport.mark_dispatched(decision)
    assert Transport.fallback_allowed?(marked) == false

    # The reply arrives past the deadline, carrying an adapter receipt.
    {:ok, reply} = AdapterDouble.late_reply(adapter, "cmd-late-1", 60)
    assert reply.latency == :late

    # The late reply must not authorize anything: the runtime asks the module
    # and the module must refuse fallback, so no replay dispatch happens.
    {adapter, outcome} = silent_replay_if_authorized(adapter, marked)
    assert outcome == :unknown_after_dispatch
    assert AdapterDouble.dispatch_count(adapter, "cmd-late-1") == 1

    # No fabricated receipt: the decision remains a selection, not a receipt.
    # The module has no channel through which a late reply could enter it
    # (guarded by the export tripwire below), and its decision never carries
    # reply/result data.
    refute Enum.any?(Map.keys(marked), &(&1 in [:receipt, :reply, :result, :adapter_receipt]))
    assert marked.dispatch_state == :dispatched
  end

  # --------------------------------------------------------------------------
  # Falsifier 2: out-of-order replies.
  # LAW: the no-silent-replay marker is per dispatched decision; replies
  # arriving out of order must not unlock or cross-contaminate markers.
  # --------------------------------------------------------------------------

  test "out-of-order replies keep per-command markers locked and dispatch counts at one" do
    adapter = %AdapterDouble{deadline: 10}

    decision_a = admit("cmd-ooo-a")
    decision_b = admit("cmd-ooo-b")

    {adapter, {:error, :timeout}} = AdapterDouble.dispatch(adapter, decision_a)
    {adapter, {:error, :timeout}} = AdapterDouble.dispatch(adapter, decision_b)
    marked_a = Transport.mark_dispatched(decision_a)
    marked_b = Transport.mark_dispatched(decision_b)

    # Replies arrive strictly out of order (b, then a), both late.
    {:ok, reply_b} = AdapterDouble.late_reply(adapter, "cmd-ooo-b", 60)
    {:ok, reply_a} = AdapterDouble.late_reply(adapter, "cmd-ooo-a", 70)
    assert reply_b.latency == :late and reply_a.latency == :late

    # Neither late reply may re-enable fallback for either command.
    {adapter, outcome_a} = silent_replay_if_authorized(adapter, marked_a)
    {adapter, outcome_b} = silent_replay_if_authorized(adapter, marked_b)
    assert outcome_a == :unknown_after_dispatch
    assert outcome_b == :unknown_after_dispatch

    assert AdapterDouble.dispatch_count(adapter, "cmd-ooo-a") == 1
    assert AdapterDouble.dispatch_count(adapter, "cmd-ooo-b") == 1
    # No cross-contamination: each command was dispatched over its own
    # admitted selection exactly once.
    assert AdapterDouble.transports_used(adapter, "cmd-ooo-a") == [:http]
    assert AdapterDouble.transports_used(adapter, "cmd-ooo-b") == [:http]
  end

  # --------------------------------------------------------------------------
  # Falsifier 3: timeout while an alternative admitted transport exists.
  # LAW: do not silently replay the action over another transport. The most
  # tempting replay is onto a transport that was admitted all along.
  # --------------------------------------------------------------------------

  test "timeout with an alternative admitted transport still forbids replay over it" do
    adapter = %AdapterDouble{deadline: 10}

    {:ok, decision} =
      Transport.select([:http, :phoenix_channel], [:http, :phoenix_channel],
        preferred: :http,
        action_id: "cmd-alt-1"
      )

    assert decision.selected == :http
    assert decision.reason == :preferred_available

    {adapter, {:error, :timeout}} = AdapterDouble.dispatch(adapter, decision)
    marked = Transport.mark_dispatched(decision)

    # Alternative transport is admitted AND available: the silent replay is
    # fully selectable through the public API if fallback were authorized.
    assert :phoenix_channel in marked.declared
    assert :phoenix_channel in marked.available
    assert Transport.fallback_allowed?(marked) == false

    {adapter, outcome} = silent_replay_if_authorized(adapter, marked)
    assert outcome == :unknown_after_dispatch
    assert AdapterDouble.dispatch_count(adapter, "cmd-alt-1") == 1
    assert AdapterDouble.transports_used(adapter, "cmd-alt-1") == [:http]

    # A fresh selection for the alternative is lawful pre-dispatch, but it is
    # a NEW decision: it does not re-enable fallback for the dispatched one
    # and it is never born with a dispatch marker or a permissive fallback.
    {:ok, fresh} =
      Transport.select([:http, :phoenix_channel], [:phoenix_channel],
        preferred: :phoenix_channel,
        action_id: "cmd-alt-1"
      )

    assert fresh.dispatch_state == :not_dispatched
    assert fresh.fallback == :pre_dispatch_only
    assert Transport.fallback_allowed?(fresh)
    assert Transport.fallback_allowed?(marked) == false
  end

  # --------------------------------------------------------------------------
  # Falsifier 4: dispatch with no admitted transport.
  # LAW: selection happens before dispatch and only over admitted transports;
  # with nothing admitted there must be no dispatchable decision at all, and
  # the refusal must not smuggle a selection or receipt into the error.
  # --------------------------------------------------------------------------

  test "no admitted transport yields an error, never a dispatchable decision" do
    # Declared but nowhere available; available but never declared; nothing
    # declared at all; unknown transport names; non-list inputs.
    assert {:error, {:unsupported_transport, %{available: []}}} =
             Transport.select([:http], [])

    assert {:error, {:unsupported_transport, _}} = Transport.select([], [])

    assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
             Transport.select([:http], [:http, :phoenix_channel])

    assert {:error, {:unknown_transport, [:carrier_pigeon]}} =
             Transport.select([:carrier_pigeon], [:carrier_pigeon])

    assert {:error, :transports_must_be_a_list} = Transport.select(:http, [])
    assert {:error, :transports_must_be_a_list} = Transport.select(nil, [])

    assert {:error, {:unknown_transport, :carrier_pigeon}} =
             Transport.select([], [], preferred: :carrier_pigeon)
  end

  test "refusals never smuggle a selection, marker, or receipt into the error term" do
    errors =
      [
        Transport.select([:http], []),
        Transport.select([], []),
        Transport.select([:http], [:http, :phoenix_channel]),
        Transport.select([:carrier_pigeon], []),
        Transport.select(:http, [])
      ]

    for {:error, reason} <- errors do
      payload = inspect(reason)
      refute payload =~ ":selected"
      refute payload =~ "receipt"
      assert is_struct(reason) == false or match?(%Decision{}, reason) == false
    end
  end

  test "the dispatch marker cannot be forged onto anything but a real decision" do
    # apply/3 keeps the forged payloads out of literal type warnings; the
    # point under test is the FunctionClauseError refusal itself.
    assert_raise FunctionClauseError, fn ->
      apply(Transport, :mark_dispatched, [{:ok, :fabricated}])
    end

    assert_raise FunctionClauseError, fn ->
      apply(Transport, :mark_dispatched, [%{dispatch_state: :not_dispatched, selected: :http}])
    end
  end

  # --------------------------------------------------------------------------
  # Falsifier 5: fallback after the dispatch marker.
  # LAW: fallback is :pre_dispatch_only; once marked, no path may re-enable
  # it, and the marker must be the only mutation.
  # --------------------------------------------------------------------------

  test "fallback after the dispatch marker is refused and the marker cannot be reset" do
    decision = admit("cmd-fb-1")
    assert decision.fallback == :pre_dispatch_only
    assert decision.dispatch_state == :not_dispatched
    assert Transport.fallback_allowed?(decision)

    marked = Transport.mark_dispatched(decision)
    assert marked.dispatch_state == :dispatched
    assert Transport.fallback_allowed?(marked) == false

    # Marking twice (double-ack, replays of the marker itself) must not reset.
    assert Transport.mark_dispatched(marked) == marked
    assert Transport.fallback_allowed?(Transport.mark_dispatched(marked)) == false

    # The marker is the ONLY mutation: everything else is bit-for-bit equal.
    assert Map.delete(marked, :dispatch_state) == Map.delete(decision, :dispatch_state)
    assert marked.fallback == :pre_dispatch_only
  end

  test "forged dispatch states fail closed: only exactly :not_dispatched allows fallback" do
    base = %{
      declared: [:http],
      available: [:http],
      selected: :http,
      preferred: :http,
      reason: :preferred_available
    }

    forged_states = [
      nil,
      :dispatched,
      :unknown_after_dispatch,
      :replaying,
      :bogus,
      "not_dispatched"
    ]

    for state <- forged_states do
      decision = struct!(Decision, Map.put(base, :dispatch_state, state))

      assert Transport.fallback_allowed?(decision) == false,
             "dispatch_state #{inspect(state)} must fail closed"
    end

    only_admitted = struct!(Decision, Map.put(base, :dispatch_state, :not_dispatched))
    assert Transport.fallback_allowed?(only_admitted)
  end

  # --------------------------------------------------------------------------
  # Falsifier 6: duplicate dispatch of the same commandId through the
  # selection API.
  # LAW: post-dispatch replay protection is per admitted decision; a
  # commandId-level dedup registry is a separately admitted idempotency
  # protocol, and this module must never silently pretend to provide it.
  # --------------------------------------------------------------------------

  test "duplicate commandId selections are pure: no silent dedup, no silent dispatch" do
    first = admit("cmd-dup-1")
    second = admit("cmd-dup-1")

    # Selection is pure bookkeeping-free: identical inputs, identical fresh
    # decisions. The module keeps no registry, so it can neither silently
    # perform nor silently prevent a duplicate dispatch of the commandId.
    assert first == second
    assert first.dispatch_state == :not_dispatched
    assert second.dispatch_state == :not_dispatched

    # Marking one decision never marks the other: replay protection is per
    # admitted decision object, exactly as the law scopes it.
    marked_first = Transport.mark_dispatched(first)
    assert Transport.fallback_allowed?(marked_first) == false
    assert Transport.fallback_allowed?(second) == true
    assert second.dispatch_state == :not_dispatched
  end

  # --------------------------------------------------------------------------
  # Falsifier 7: the export surface itself.
  # LAW: this module is pure pre-dispatch selection; it must never grow a
  # dispatch, replay, or receipt function. Any new export must consciously
  # update this guard with an admitted protocol.
  # --------------------------------------------------------------------------

  test "the module exposes selection and marker functions only" do
    exports = Transport.__info__(:functions) |> Enum.sort()

    # finish-select-025 admits facts_from_profile/1: a pure delegated-fact
    # reader (profile map -> normalized facts for select/3's :facts opt).
    # It takes no Decision and dispatches nothing — the law above holds.
    assert exports == [
             facts_from_profile: 1,
             fallback_allowed?: 1,
             mark_dispatched: 1,
             select: 2,
             select: 3
           ]
  end

  test "selection never fabricates a dispatch marker or a receipt on any reason path" do
    paths = [
      {[:http], [:http], []},
      {[:http, :phoenix_channel], [:http], [preferred: :phoenix_channel]},
      {[:http, :phoenix_channel], [:http, :phoenix_channel], [preferred: :phoenix_channel]},
      {[:http, :phoenix_channel], [:phoenix_channel], []}
    ]

    for {declared, available, opts} <- paths do
      assert {:ok, decision} = Transport.select(declared, available, opts)
      assert decision.dispatch_state == :not_dispatched
      assert decision.fallback == :pre_dispatch_only
      refute Enum.any?(Map.keys(decision), &(&1 in [:receipt, :reply, :result]))
    end
  end
end
