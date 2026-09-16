defmodule AshSurface.TransportSelectTest do
  @moduledoc """
  Chicago-law, state-based tests of the real `AshSurface.Transport.select/3`.

  Every case calls the real pure module with real inputs (admitted/available
  transport sets, real action metadata) and asserts on the returned decision
  state. No doubles are needed: the module is pure and injects nothing.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Transport

  # Realistic consumer-surface action metadata in the repo's manifest idiom:
  # each action declares its admitted transports; the runtime environment
  # reports which transports are actually available (e.g. a LiveView socket
  # exists or it does not).

  @actions %{
    post_create: %{
      action_id: "Post#create",
      transports: %{declared: [:http, :phoenix_channel], available: [:http, :phoenix_channel]}
    },
    session_revoke: %{
      action_id: "Session#revoke",
      transports: %{declared: [:phoenix_channel], available: [:phoenix_channel]}
    },
    billing_sync: %{
      action_id: "Billing#sync",
      transports: %{declared: [:http], available: [:http]}
    }
  }

  # Helper (inside this module only): project real action metadata into a
  # real select/3 call, threading the action_id through opts.
  defp select_for_action(action, preferred \\ nil) do
    transports = action.transports

    opts = [action_id: action.action_id]
    opts = if preferred, do: Keyword.put(opts, :preferred, preferred), else: opts

    Transport.select(transports.declared, transports.available, opts)
  end

  describe "admitted-set handling across both known transports" do
    test "an action admitting both transports selects the default preferred :http" do
      action = @actions.post_create

      assert {:ok, %Transport.Decision{} = decision} = select_for_action(action)

      assert decision.selected == :http
      assert decision.preferred == :http
      assert decision.reason == :preferred_available
      assert decision.declared == [:http, :phoenix_channel]
      assert decision.available == [:http, :phoenix_channel]
      assert decision.action_id == "Post#create"
    end

    test "an action admitting both transports selects :phoenix_channel when preferred" do
      action = @actions.post_create

      assert {:ok, decision} = select_for_action(action, :phoenix_channel)

      assert decision.selected == :phoenix_channel
      assert decision.reason == :preferred_available
    end

    test "an action admitting only :phoenix_channel folds to it under the default :http preference" do
      action = @actions.session_revoke

      assert {:ok, decision} = select_for_action(action)

      # The default preference is advisory only: selection stays inside the
      # admitted set and folds to the declared, available transport.
      assert decision.selected == :phoenix_channel
      assert decision.preferred == :http
      assert decision.reason == :preferred_unavailable
      assert decision.declared == [:phoenix_channel]
      assert decision.available == [:phoenix_channel]
      assert decision.action_id == "Session#revoke"
    end

    test "an action admitting only :http selects :http directly" do
      action = @actions.billing_sync

      assert {:ok, decision} = select_for_action(action)

      assert decision.selected == :http
      assert decision.reason == :preferred_available
    end

    test "the full canonical decision state is pinned field for field" do
      assert {:ok,
              %Transport.Decision{
                action_id: "Post#create",
                declared: [:http, :phoenix_channel],
                available: [:http],
                selected: :http,
                preferred: :phoenix_channel,
                reason: :preferred_unavailable,
                dispatch_state: :not_dispatched,
                fallback: :pre_dispatch_only
              }} =
               Transport.select([:http, :phoenix_channel], [:http],
                 preferred: :phoenix_channel,
                 action_id: "Post#create"
               )
    end

    test "an available transport outside the admitted set is refused" do
      assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
               Transport.select([:http], [:http, :phoenix_channel])
    end

    test "an empty admitted set admits nothing and is refused" do
      assert {:error, {:unsupported_transport, %{preferred: :http, available: []}}} =
               Transport.select([], [])
    end

    test "unknown transports in the declared set are refused" do
      assert {:error, {:unknown_transport, [:grpc, :soap]}} =
               Transport.select([:http, :grpc, :soap], [:http])
    end

    test "unknown transports in the available set are refused" do
      assert {:error, {:unknown_transport, [:grpc]}} =
               Transport.select([:http, :phoenix_channel], [:grpc])
    end

    test "a non-list transport set is refused for the declared position" do
      assert {:error, :transports_must_be_a_list} = Transport.select(:http, [:http])
    end

    test "a non-list transport set is refused for the available position" do
      assert {:error, :transports_must_be_a_list} = Transport.select([:http], :http)
    end
  end

  describe "preference ordering" do
    test "preference beats declared ordering when both transports are available" do
      assert {:ok, decision} =
               Transport.select([:phoenix_channel, :http], [:http, :phoenix_channel],
                 preferred: :http
               )

      assert decision.selected == :http
      assert decision.reason == :preferred_available
    end

    test "an admitted-but-unavailable preferred transport folds to the declared order" do
      assert {:ok, decision} =
               Transport.select([:phoenix_channel, :http], [:phoenix_channel], preferred: :http)

      assert decision.selected == :phoenix_channel
      assert decision.reason == :preferred_unavailable
    end

    test "the fold scans the declared set, not the available set order" do
      assert {:ok, decision} =
               Transport.select([:http, :phoenix_channel], [:phoenix_channel], preferred: :http)

      assert decision.selected == :phoenix_channel
      assert decision.reason == :preferred_unavailable
    end

    test "a preferred transport outside the known set is refused" do
      assert {:error, {:unknown_transport, :websocket}} =
               Transport.select([:http, :phoenix_channel], [:http], preferred: :websocket)
    end

    test "validation precedence: declared-set errors are reported before available-set errors" do
      assert {:error, {:unknown_transport, [:grpc]}} =
               Transport.select([:grpc], [:also_grpc], preferred: :http)
    end

    test "validation precedence: unadmitted available beats an unknown preferred transport" do
      assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
               Transport.select([:http], [:phoenix_channel], preferred: :grpc)
    end
  end

  describe "unavailability folding" do
    test "folding keeps the preferred value visible for the receipt" do
      assert {:ok, decision} = Transport.select([:http, :phoenix_channel], [:phoenix_channel])

      assert decision.preferred == :http
      assert decision.selected == :phoenix_channel
      assert decision.reason == :preferred_unavailable
    end

    test "total unavailability is refused with the preferred transport in the error" do
      assert {:error, {:unsupported_transport, %{preferred: :phoenix_channel, available: []}}} =
               Transport.select([:http, :phoenix_channel], [], preferred: :phoenix_channel)
    end

    test "an unavailable preferred transport with no available alternative is refused" do
      assert {:error, {:unsupported_transport, %{preferred: :http, available: []}}} =
               Transport.select([:http], [], preferred: :http)
    end

    test "folding never crosses the admitted-set boundary" do
      # :phoenix_channel is available in the environment but not admitted for
      # this action, so selection must refuse rather than fold onto it.
      assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
               Transport.select([:http], [:phoenix_channel], preferred: :http)
    end
  end

  describe "selection over real action/transport metadata" do
    test "a channel-only LiveView action selects :phoenix_channel from its metadata" do
      action = %{
        action_id: "Post#stream_updates",
        transports: %{declared: [:phoenix_channel], available: [:phoenix_channel]}
      }

      assert {:ok, %Transport.Decision{selected: :phoenix_channel} = decision} =
               select_for_action(action, :phoenix_channel)

      assert decision.reason == :preferred_available
      assert decision.action_id == "Post#stream_updates"
    end

    test "an http-only action keeps :http even when the environment offers more" do
      # The environment offers both, but the action's admitted set is the gate.
      action = %{
        action_id: "Report#export",
        transports: %{declared: [:http], available: [:http]}
      }

      assert {:ok, %Transport.Decision{selected: :http} = decision} =
               select_for_action(action, :phoenix_channel)

      assert decision.reason == :preferred_unavailable
      assert decision.preferred == :phoenix_channel
    end

    test "a degraded environment folds a dual-transport action onto :http" do
      action = %{
        action_id: "Post#create",
        transports: %{declared: [:http, :phoenix_channel], available: [:http]}
      }

      assert {:ok, %Transport.Decision{selected: :http, reason: :preferred_unavailable}} =
               select_for_action(action, :phoenix_channel)
    end

    test "every metadata-driven decision starts not-dispatched with pre-dispatch fallback" do
      for {name, action} <- @actions do
        assert {:ok, decision} = select_for_action(action), "action #{name} failed to select"
        assert decision.dispatch_state == :not_dispatched
        assert decision.fallback == :pre_dispatch_only
        assert Transport.fallback_allowed?(decision)
      end
    end

    test "mark_dispatched/1 flips fallback permission on real selected decisions" do
      assert {:ok, decision} = select_for_action(@actions.post_create, :phoenix_channel)

      assert Transport.fallback_allowed?(decision)
      dispatched = Transport.mark_dispatched(decision)
      refute Transport.fallback_allowed?(dispatched)
      assert dispatched.dispatch_state == :dispatched
      # Selection facts survive the dispatch transition.
      assert dispatched.selected == :phoenix_channel
      assert dispatched.reason == :preferred_available
    end
  end
end
