defmodule AshSurface.Intent.DispatchTest do
  @moduledoc """
  Falsifiers against the delegated-DO law.

  LAW:

    - `ash_surface` NEVER executes anything itself; actuation belongs to the
      INJECTED bus (`AshSurface.Intent.CommandBus`, `submit/2`).
    - Bus outcomes pass through EXACTLY: receipts are the bus's own, typed
      refusals (e.g. `{:error, :REFUSED_NO_AUTHORITY}`) propagate untouched.
    - The adapter mints refusals only fail-closed: invalid candidates are
      refused before the bus is touched; a non-conforming bus is refused typed.
    - KNOWN-ness pre-bus (F2): with the admitted action set injected in the
      context (`:admitted_action_ids`, the verified surface's action ids), an
      `action_id` outside the set is refused `{:error, :REFUSED_UNKNOWN_ACTION}`
      before the bus is consulted — the Elixir mirror of the generated JS
      `REFUSED_UNKNOWN_ACTION`. The set is injected, never looked up; without
      it there is no verdict and no gate.

  Each test is a falsification attempt through the public surface of
  `AshSurface.Intent.Dispatch`; the AST falsifier at the bottom proves over
  source that no intent module ever calls an Ash action directly.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Intent.Envelope
  alias AshSurface.Intent.CommandBus
  alias AshSurface.Intent.Dispatch

  # -------------------------------------------------------------------------
  # Bus double: conforms to the behaviour, records every submit in the test
  # process, and answers with a scripted outcome. It never dispatches on its
  # own; only Dispatch.submit/3 can reach it.
  # -------------------------------------------------------------------------
  defmodule RecordingBus do
    @moduledoc false
    @behaviour CommandBus

    @impl CommandBus
    def submit(intent, context) do
      record({intent, context})
      scripted_outcome()
    end

    def set_outcome(outcome), do: Process.put({__MODULE__, :outcome}, outcome)

    def calls, do: {__MODULE__, :calls} |> Process.get([]) |> Enum.reverse()

    defp record(call),
      do: Process.put({__MODULE__, :calls}, [call | Process.get({__MODULE__, :calls}, [])])

    defp scripted_outcome, do: Process.get({__MODULE__, :outcome}, {:ok, :unscripted})
  end

  # A module that exists but does not conform to the behaviour.
  defmodule NotABus do
    @moduledoc false
    def submit(_one_arg), do: {:ok, :forged}
  end

  setup do
    RecordingBus.set_outcome({:ok, "receipt-default"})
    on_exit(fn -> Process.delete({RecordingBus, :calls}) end)
    :ok
  end

  defp calls, do: RecordingBus.calls()

  # --------------------------------------------------------------------------
  # Falsifier 1: the delegation itself.
  # LAW: submit/3 calls the INJECTED bus exactly once and returns the bus's
  # own outcome; a receipt can only come from the bus, never be fabricated.
  # --------------------------------------------------------------------------

  test "delegates to the injected bus and returns its receipt exactly" do
    receipt = make_ref()
    RecordingBus.set_outcome({:ok, receipt})

    candidate = %{action_id: "user.create", params: %{name: "ada"}}
    context = %{actor: :operator, cut: :fresh}

    assert Dispatch.submit(candidate, RecordingBus, context) == {:ok, receipt}

    assert [
             {%Envelope{
                action_id: "user.create",
                payload: %{params: %{name: "ada"}}
              }, ^context}
           ] = calls()
  end

  # --------------------------------------------------------------------------
  # Falsifier 2: typed refusal passthrough.
  # LAW: bus refusals propagate typed and untouched — never rewrapped,
  # downgraded, or swallowed into a success.
  # --------------------------------------------------------------------------

  test "propagates the bus's typed refusal untouched" do
    RecordingBus.set_outcome({:error, :REFUSED_NO_AUTHORITY})

    assert Dispatch.submit(%{action_id: "ledger.close"}, RecordingBus, %{cut: :stale}) ==
             {:error, :REFUSED_NO_AUTHORITY}

    # The refusal crossed the bus (and only the bus), it was not minted here.
    assert [{%Envelope{action_id: "ledger.close"}, %{cut: :stale}}] = calls()
  end

  test "propagates a structured bus error shape verbatim" do
    reason = {:REFUSED_NO_AUTHORITY, resolver: :none, boundary: :operator_cut}
    RecordingBus.set_outcome({:error, reason})

    assert {:error, observed} = Dispatch.submit(%{action_id: "a.b"}, RecordingBus, %{})
    assert observed == reason
    assert [_] = calls()
  end

  # --------------------------------------------------------------------------
  # Falsifier 3: the intent payload.
  # LAW: the adapter interprets nothing — candidate keys other than
  # :action_id ride the intent verbatim.
  # --------------------------------------------------------------------------

  test "carries every non-action_id candidate key into the intent verbatim" do
    candidate = %{0 => :odd_key, action_id: "order.cancel", reason: "fraud", meta: %{trace: 7}}
    context = %{tenant: "acme"}

    assert {:ok, _} = Dispatch.submit(candidate, RecordingBus, context)

    assert [{%Envelope{action_id: "order.cancel"} = intent, ^context}] = calls()
    assert intent.payload == Map.delete(candidate, :action_id)
  end

  # --------------------------------------------------------------------------
  # Falsifier 4: fail-closed input refusals.
  # LAW: an invalid candidate is refused BEFORE any bus call; a bus that does
  # not conform to the behaviour is refused typed, never invoked.
  # --------------------------------------------------------------------------

  test "refuses invalid candidates with typed reasons before touching the bus" do
    refusals = [
      {nil, :candidate_must_be_a_map},
      {[], :candidate_must_be_a_map},
      {"action_id: x", :candidate_must_be_a_map},
      {%{}, :missing_action_id},
      {%{action_id: nil}, :missing_action_id},
      {%{action_id: ""}, :missing_action_id},
      {%{action_id: 7}, :invalid_action_id},
      {%{action_id: :user_create}, :invalid_action_id}
    ]

    for {bad, reason} <- refusals do
      assert Dispatch.submit(bad, RecordingBus, %{}) == {:error, {:invalid_candidate, reason}}
    end

    assert [] = calls()
  end

  test "refuses a non-conforming bus typed and never invokes it" do
    candidate = %{action_id: "user.create"}

    # NotABus exports submit/1, not submit/2: reaching it would raise, so the
    # typed return is itself proof it was never invoked.
    assert Dispatch.submit(candidate, NotABus, %{}) == {:error, :REFUSED_NO_COMMAND_BUS}
    assert Dispatch.submit(candidate, :not_a_module, %{}) == {:error, :REFUSED_NO_COMMAND_BUS}
    assert Dispatch.submit(candidate, nil, %{}) == {:error, :REFUSED_NO_COMMAND_BUS}
    assert [] = calls()
  end

  test "refuses the candidate before consulting the bus at all" do
    assert Dispatch.submit(%{}, NotABus, %{}) ==
             {:error, {:invalid_candidate, :missing_action_id}}
  end

  # --------------------------------------------------------------------------
  # Falsifier 5: KNOWN-ness pre-bus (F2, finish-classify-021).
  # LAW: when the context carries the injected admitted action set, an
  # :action_id outside the set is refused typed `{:error, :REFUSED_UNKNOWN_ACTION}`
  # BEFORE the bus is consulted — the Elixir mirror of the generated JS
  # `dispatchIntent` refusal. The set rides injection at the same hand-off as
  # the bus, never a lookup; absent key means no verdict is available.
  # --------------------------------------------------------------------------

  @admitted_set ["user.create", "ledger.close"]

  test "refuses an out-of-set action_id typed before touching the bus" do
    candidate = %{action_id: "Nope#missing", params: %{}}

    assert Dispatch.submit(candidate, RecordingBus, %{admitted_action_ids: @admitted_set}) ==
             {:error, :REFUSED_UNKNOWN_ACTION}

    assert [] = calls()
  end

  test "every id of the injected admitted set still reaches the bus unchanged" do
    for id <- @admitted_set do
      assert {:ok, _receipt} =
               Dispatch.submit(%{action_id: id}, RecordingBus, %{
                 admitted_action_ids: @admitted_set
               })
    end

    assert [
             {%Envelope{action_id: "user.create"}, %{admitted_action_ids: @admitted_set}},
             {%Envelope{action_id: "ledger.close"}, %{admitted_action_ids: @admitted_set}}
           ] = calls()
  end

  test "the KNOWN-ness gate fires before the bus-conformance check" do
    # NotABus would draw :REFUSED_NO_COMMAND_BUS if the gate ran after bus
    # validation; the unknown-action refusal proves the candidate is judged
    # first, before any bus consulting.
    assert Dispatch.submit(%{action_id: "Nope#missing"}, NotABus, %{
             admitted_action_ids: @admitted_set
           }) == {:error, :REFUSED_UNKNOWN_ACTION}
  end

  test "an empty injected admitted set admits nothing" do
    assert Dispatch.submit(%{action_id: "user.create"}, RecordingBus, %{
             admitted_action_ids: []
           }) == {:error, :REFUSED_UNKNOWN_ACTION}

    assert [] = calls()
  end

  test "a present-but-malformed admitted set is refused typed, never read as no-gate" do
    for bad <- ["user.create", %{"user.create" => true}, [:user_create], nil] do
      assert Dispatch.submit(%{action_id: "user.create"}, RecordingBus, %{
               admitted_action_ids: bad
             }) ==
               {:error, {:invalid_context, :admitted_action_ids_must_be_a_list_of_strings}}
    end

    assert [] = calls()
  end

  test "without an injected set the gate stays out of the way (admitted set unchanged)" do
    # Falsifiers 1-4 pin the pre-F2 behavior with no gate key in context. This
    # tripwire additionally forbids the gate from ever growing a lookup
    # fallback (global registry, application env): injection or nothing.
    assert {:ok, _} = Dispatch.submit(%{action_id: "any.thing"}, RecordingBus, %{})

    assert {:ok, _} =
             Dispatch.submit(%{action_id: "any.thing"}, RecordingBus, %{actor: :operator})

    assert [
             {%Envelope{action_id: "any.thing"}, %{}},
             {%Envelope{action_id: "any.thing"}, %{actor: :operator}}
           ] = calls()
  end

  # --------------------------------------------------------------------------
  # Falsifier 6: the export surface.
  # LAW: this module is delegation only; it must never grow an execute,
  # dispatch, retry, or receipt function.
  # --------------------------------------------------------------------------

  test "export surface is delegation only" do
    assert Dispatch.__info__(:functions) == [submit: 3]
    assert CommandBus.behaviour_info(:callbacks) == [submit: 2]
  end

  # --------------------------------------------------------------------------
  # Falsifier 7: no direct Ash action calls in intent modules.
  # LAW: ash_surface never executes anything itself. Proven over source: the
  # quoted AST of every module under lib/ash_surface/intent/ contains no call
  # of an Ash action function on the Ash module.
  # --------------------------------------------------------------------------

  @ash_action_funs MapSet.new([
                     :create,
                     :update,
                     :destroy,
                     :read,
                     :read_one,
                     :run_action,
                     :bulk_create,
                     :bulk_update,
                     :bulk_destroy,
                     :exists?,
                     :for_create,
                     :for_update,
                     :for_destroy,
                     :for_action
                   ])

  test "no intent module source contains a direct Ash action call" do
    sources = Path.wildcard("lib/ash_surface/intent/**/*.ex")
    refute sources == [], "vacuous falsifier: no intent sources found"

    for file <- sources do
      ast = file |> File.read!() |> Code.string_to_quoted!()

      assert [] = ash_action_calls(ast, file),
             "intent module #{file} calls the Ash action API directly"
    end
  end

  defp ash_action_calls(ast, file) do
    {_, violations} =
      Macro.prewalk(ast, [], fn
        {{:., _, [{:__aliases__, _, [root | _]} = mod, fun]}, _, _args} = node, acc
        when is_atom(root) and is_atom(fun) ->
          if root == :Ash and MapSet.member?(@ash_action_funs, fun) do
            {node, ["#{file}: #{Macro.to_string(mod)}.#{fun}" | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(violations)
  end
end
