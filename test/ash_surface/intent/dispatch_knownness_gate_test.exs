defmodule AshSurface.Intent.DispatchKnownnessGateTest do
  @moduledoc """
  The KNOWN-ness pre-bus gate as a STATE TABLE (chicago-intent-gate-032).

  Each row is a full state of the world — the injected context (carrying the
  admitted action set, or not), the candidate handed to
  `AshSurface.Intent.Dispatch.submit/3`, and the expected observable outcome —
  plus the expected number of bus calls. Bus-call counting is load-bearing
  because the law IS the boundary: a pre-bus refusal row must show the bus
  untouched (0 calls); an admitted row must show exactly one hand-off.

  Chicago-school discipline:

    - the unit under test is the REAL `AshSurface.Intent.Dispatch`; the only
      injected seams (`RecordingBus`, the context map) are seams the
      delegated-DO law itself demands (bus injection, context injection);
    - assertions touch observable outcomes only: returned values, typed
      refusals, and the bus-call record (allowed solely because bus-untouched
      is the law under test).

  Row set (mirrors the generated JS `dispatchIntent` `REFUSED_UNKNOWN_ACTION`
  gate over its frozen `ACTIONS` registry):

    1. in-set id reaches the bus exactly once
    2. membership, not position: an id admitted anywhere in the set passes
    3. out-of-set id refuses typed pre-bus (bus count 0)
    4. empty admitted set admits nothing (bus count 0)
    5. malformed set (not a list) refuses typed (bus count 0)
    6. malformed set (non-string members) refuses typed (bus count 0)
    7. malformed set (present-but-nil) refuses typed (bus count 0)
    8. no key: no gate — byte-identical pre-gate pass-through (bus count 1)
  """

  use ExUnit.Case, async: true

  alias AshSurface.Intent.CommandBus
  alias AshSurface.Intent.Dispatch
  alias AshSurface.Intent.Envelope

  # -------------------------------------------------------------------------
  # Bus double: conforms to the behaviour, records every submit in the test
  # process, and answers with a scripted receipt. Only Dispatch.submit/3 can
  # reach it — the count of its calls is the observable that proves pre-bus.
  # -------------------------------------------------------------------------
  defmodule CountingBus do
    @moduledoc false
    @behaviour CommandBus

    @impl CommandBus
    def submit(intent, context) do
      Process.put({__MODULE__, :calls}, [
        {intent, context} | Process.get({__MODULE__, :calls}, [])
      ])

      Process.get({__MODULE__, :outcome}, {:ok, :unscripted})
    end

    def set_outcome(outcome), do: Process.put({__MODULE__, :outcome}, outcome)

    def calls, do: {__MODULE__, :calls} |> Process.get([]) |> Enum.reverse()
  end

  @receipt "receipt-state-table"

  setup do
    CountingBus.set_outcome({:ok, @receipt})
    on_exit(fn -> Process.delete({CountingBus, :calls}) end)
    :ok
  end

  # -------------------------------------------------------------------------
  # The state table. `:expected` is the exact returned value of
  # Dispatch.submit/3; `:bus_calls` the exact number of bus invocations;
  # `:bus_sees` the exact single call the bus must record (nil = must record
  # nothing). Every field is an observable.
  # -------------------------------------------------------------------------
  @typed_refusal {:error, {:invalid_context, :admitted_action_ids_must_be_a_list_of_strings}}

  @state_table [
    %{
      label: "in-set id reaches the bus exactly once",
      context: %{admitted_action_ids: ["user.create", "ledger.close"], actor: :operator},
      candidate: %{action_id: "user.create", params: %{name: "ada"}},
      expected: {:ok, @receipt},
      bus_calls: 1,
      bus_sees:
        {%Envelope{action_id: "user.create", payload: %{params: %{name: "ada"}}},
         %{admitted_action_ids: ["user.create", "ledger.close"], actor: :operator}}
    },
    %{
      label: "membership not position: id admitted anywhere in the set passes",
      context: %{admitted_action_ids: ["zzz.last", "aaa.first", "mid.0"]},
      candidate: %{action_id: "aaa.first"},
      expected: {:ok, @receipt},
      bus_calls: 1,
      bus_sees:
        {%Envelope{action_id: "aaa.first", payload: %{}},
         %{admitted_action_ids: ["zzz.last", "aaa.first", "mid.0"]}}
    },
    %{
      label: "out-of-set id refuses typed pre-bus",
      context: %{admitted_action_ids: ["user.create", "ledger.close"]},
      candidate: %{action_id: "Nope#missing", params: %{}},
      expected: {:error, :REFUSED_UNKNOWN_ACTION},
      bus_calls: 0,
      bus_sees: nil
    },
    %{
      label: "empty admitted set admits nothing",
      context: %{admitted_action_ids: []},
      candidate: %{action_id: "user.create"},
      expected: {:error, :REFUSED_UNKNOWN_ACTION},
      bus_calls: 0,
      bus_sees: nil
    },
    %{
      label: "malformed set (not a list) refuses typed",
      context: %{admitted_action_ids: "user.create"},
      candidate: %{action_id: "user.create"},
      expected: @typed_refusal,
      bus_calls: 0,
      bus_sees: nil
    },
    %{
      label: "malformed set (non-string members) refuses typed",
      context: %{admitted_action_ids: [:user_create, "user.create"]},
      candidate: %{action_id: "user.create"},
      expected: @typed_refusal,
      bus_calls: 0,
      bus_sees: nil
    },
    %{
      label: "malformed set (present-but-nil) refuses typed",
      context: %{admitted_action_ids: nil},
      candidate: %{action_id: "user.create"},
      expected: @typed_refusal,
      bus_calls: 0,
      bus_sees: nil
    },
    %{
      label: "no key no gate: byte-identical pre-gate pass-through",
      context: %{actor: :operator, tenant: "acme"},
      candidate: %{action_id: "any.thing", tenant: "acme"},
      expected: {:ok, @receipt},
      bus_calls: 1,
      bus_sees:
        {%Envelope{action_id: "any.thing", payload: %{tenant: "acme"}},
         %{actor: :operator, tenant: "acme"}}
    }
  ]

  for row <- @state_table do
    test "state row: #{row.label}" do
      row = unquote(Macro.escape(row))

      outcome = Dispatch.submit(row.candidate, CountingBus, row.context)

      # Observable 1: the exact returned value (receipt or typed refusal).
      assert outcome == row.expected

      # Observable 2: the bus-call count — the law IS the boundary, so a
      # pre-bus refusal must show the bus untouched and an admitted row must
      # show exactly one hand-off.
      #
      # Observable 3: the exact call the bus recorded (envelope + context),
      # or none at all. `List.wrap/1` turns the row's expected single call
      # into `[call]` and nil into `[]`, so one equality assert covers both.
      assert CountingBus.calls() == List.wrap(row.bus_sees)
      assert length(CountingBus.calls()) == row.bus_calls
    end
  end

  test "the state table is non-vacuous (at least 6 rows, all labeled)" do
    assert length(@state_table) >= 6
    assert Enum.all?(@state_table, &is_binary(&1.label))
  end
end
