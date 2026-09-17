defmodule AshSurface.TransportFallbackTest do
  @moduledoc """
  State-based tests of the pre-dispatch fallback law in `AshSurface.Transport`.

  Law (from the module's own moduledoc): selection is intentionally separate
  from execution, and "Once dispatch begins, this module never authorizes
  automatic transport fallback: a timeout or disconnect can occur after the
  server has already executed a consequential action."

  Consequences exercised here:
    - every pre-dispatch state transition (adapter unavailable -> alternate
      selected, readiness recomputed) is legal and observable in the Decision;
    - post-dispatch fallback is explicitly refused (`fallback_allowed?/1`
      returns false once `dispatch_state` is `:dispatched`) and structurally
      impossible (`select/3` is the only producer of fresh decisions and always
      returns `:not_dispatched`; `fallback` is frozen at `:pre_dispatch_only`).

  The module under test is pure: declared/available are data, so no adapter
  doubles, env, db, or network are needed anywhere in this file.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport
  alias AshSurface.Transport.Decision

  @both_transports [:http, :phoenix_channel]

  # Table-driven from the module's own docs, struct defaults, and reason atoms.
  @selection_table [
    # desc                         declared                  available                 opts                              selected            reason
    {":preferred_available", @both_transports, @both_transports, [preferred: :http], :http,
     :preferred_available},
    {":preferred_available phoenix", @both_transports, @both_transports,
     [preferred: :phoenix_channel], :phoenix_channel, :preferred_available},
    {"http adapter unavailable -> phoenix_channel alternate", @both_transports,
     [:phoenix_channel], [preferred: :http], :phoenix_channel, :preferred_unavailable},
    {"phoenix adapter unavailable -> http alternate", @both_transports, [:http],
     [preferred: :phoenix_channel], :http, :preferred_unavailable},
    {"declared order picks the alternate when preferred is down", [:phoenix_channel, :http],
     [:phoenix_channel], [preferred: :http], :phoenix_channel, :preferred_unavailable},
    {"single declared transport with it available", [:http], [:http], [], :http,
     :preferred_available},
    {"default preferred is :http when opts omit it", @both_transports, @both_transports, [],
     :http, :preferred_available}
  ]

  describe "pre-dispatch selection transitions (table)" do
    for {desc, declared, available, opts, want_selected, want_reason} <- @selection_table do
      test "#{desc}: selects #{inspect(want_selected)} (#{want_reason})" do
        assert {:ok, %Decision{} = decision} =
                 Transport.select(unquote(declared), unquote(available), unquote(opts))

        assert decision.selected == unquote(want_selected)
        assert decision.reason == unquote(want_reason)
        assert decision.declared == unquote(declared)
        assert decision.available == unquote(available)
        assert decision.preferred == Keyword.get(unquote(opts), :preferred, :http)
        assert decision.dispatch_state == :not_dispatched
        assert decision.fallback == :pre_dispatch_only
        assert Transport.fallback_allowed?(decision)
      end
    end

    test "action_id is carried into the decision untouched" do
      assert {:ok, decision} =
               Transport.select(@both_transports, @both_transports, action_id: "issue_refund_42")

      assert decision.action_id == "issue_refund_42"
      assert decision.selected == :http
    end
  end

  describe "adapter unavailable -> alternate selected, readiness recomputed" do
    test "re-selecting after the preferred adapter drops recomputes readiness on the alternate" do
      {:ok, initial} = Transport.select(@both_transports, @both_transports, preferred: :http)
      assert initial.selected == :http
      assert initial.reason == :preferred_available
      assert Transport.fallback_allowed?(initial)

      # The http adapter reports unavailable pre-dispatch; the decision is
      # recomputed from the shrunk availability list.
      {:ok, recomputed} = Transport.select(@both_transports, [:phoenix_channel], preferred: :http)

      assert recomputed.selected == :phoenix_channel
      assert recomputed.reason == :preferred_unavailable
      assert recomputed.available == [:phoenix_channel]
      assert recomputed.dispatch_state == :not_dispatched
      assert Transport.fallback_allowed?(recomputed)
    end

    test "dispatching the stale decision never authorizes fallback on the recomputed one" do
      {:ok, stale} = Transport.select(@both_transports, @both_transports, preferred: :http)
      dispatched = Transport.mark_dispatched(stale)
      refute Transport.fallback_allowed?(dispatched)

      {:ok, fresh} = Transport.select(@both_transports, [:phoenix_channel], preferred: :http)
      # dispatch_state is per-decision: the refusal locks only the dispatched one.
      assert Transport.fallback_allowed?(fresh)
      assert fresh.selected == :phoenix_channel
    end

    test "fallback law refusals when no declared transport is available (no silent fallback)" do
      assert {:error, {:unsupported_transport, %{preferred: :http, available: []}}} =
               Transport.select(@both_transports, [], preferred: :http)

      assert {:error, {:unsupported_transport, %{preferred: :phoenix_channel, available: []}}} =
               Transport.select(@both_transports, [], preferred: :phoenix_channel)
    end
  end

  # Table-driven from the validators' own error shapes.
  @refusal_table [
    {"unknown transport in declared", [:http, :grpc], @both_transports, [],
     {:error, {:unknown_transport, [:grpc]}}},
    {"unknown transport in available", @both_transports, [:grpc, :http], [],
     {:error, {:unknown_transport, [:grpc]}}},
    {"declared not a list", :http, @both_transports, [], {:error, :transports_must_be_a_list}},
    {"available not a list", @both_transports, :http, [], {:error, :transports_must_be_a_list}},
    {"available not admitted by declared", [:http], @both_transports, [],
     {:error, {:unadmitted_transport, [:phoenix_channel]}}},
    {"unknown preferred", @both_transports, @both_transports, [preferred: :grpc],
     {:error, {:unknown_transport, :grpc}}}
  ]

  describe "pre-dispatch selection refusals (table)" do
    for {desc, declared, available, opts, expected} <- @refusal_table do
      test "#{desc}: refused with #{inspect(elem(expected, 0))}" do
        assert unquote(expected) =
                 Transport.select(unquote(declared), unquote(available), unquote(opts))
      end
    end
  end

  describe "post-dispatch fallback is refused, not merely discouraged" do
    setup do
      {:ok, decision} = Transport.select(@both_transports, @both_transports, action_id: "a1")
      %{decision: decision}
    end

    test "mark_dispatched/1 transitions dispatch_state and locks the selected transport", %{
      decision: decision
    } do
      dispatched = Transport.mark_dispatched(decision)

      assert dispatched.dispatch_state == :dispatched
      # The choice is frozen: every selection field survives dispatch untouched.
      assert dispatched.action_id == decision.action_id
      assert dispatched.declared == decision.declared
      assert dispatched.available == decision.available
      assert dispatched.selected == decision.selected
      assert dispatched.preferred == decision.preferred
      assert dispatched.reason == decision.reason
    end

    test "fallback_allowed?/1 explicitly refuses after dispatch (the moduledoc law)", %{
      decision: decision
    } do
      assert Transport.fallback_allowed?(decision)
      refute Transport.fallback_allowed?(Transport.mark_dispatched(decision))
    end

    test "fallback field stays :pre_dispatch_only in both states", %{decision: decision} do
      assert decision.fallback == :pre_dispatch_only
      assert Transport.mark_dispatched(decision).fallback == :pre_dispatch_only
    end
  end

  describe "post-dispatch fallback is structurally impossible on the API surface" do
    test "select/3 is the only decision producer and always returns :not_dispatched" do
      for available <- [[], [:http], [:phoenix_channel], @both_transports],
          preferred <- [:http, :phoenix_channel] do
        case Transport.select(@both_transports, available, preferred: preferred) do
          {:ok, decision} ->
            assert decision.dispatch_state == :not_dispatched
            assert decision.__struct__ == Decision

          {:error, _} ->
            :ok
        end
      end
    end

    test "the exported API has no re-selection path that takes a Decision" do
      public =
        for {name, arity} <- Transport.module_info(:functions),
            function_exported?(Transport, name, arity),
            name not in [:module_info, :__info__],
            do: {name, arity}

      # finish-select-025 admits facts_from_profile/1: a pure delegated-fact
      # reader (profile map -> normalized facts for select/3's :facts opt).
      # It takes no Decision — the no-re-selection law above holds.
      assert Enum.sort(public) == [
               facts_from_profile: 1,
               fallback_allowed?: 1,
               mark_dispatched: 1,
               select: 2,
               select: 3
             ]
    end

    test "feeding a dispatched Decision back into select/2 is refused as malformed input" do
      {:ok, decision} = Transport.select(@both_transports, @both_transports)
      dispatched = Transport.mark_dispatched(decision)

      assert {:error, :transports_must_be_a_list} = Transport.select(dispatched, dispatched)
    end
  end
end
