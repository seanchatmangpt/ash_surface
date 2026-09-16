# Chicago intent-path edges: the manufactured-intent family as state law.
#
#   SurfaceIntent.create/3 -> Candidate.to_candidate/2 -> Dispatch.submit/3
#   on an INJECTED CommandBus
#
# Edges held here (each test is a falsifier that survived construction):
#
#   1. identical intents idempotent: same addressed triple -> same intent_id,
#      creation is pure (data only, no execution path on the module);
#   2. input maps pass through byte-equal: no normalization, no coercion --
#      mixed-key and mixed-value inputs keep distinct identities;
#   3. all-nil-section candidates constructible with honest nils: a nil IR
#      section yields nil fields PRESENT in the envelope, never placeholders
#      and never dropped keys;
#   4. flaky-bus retries surface typed errors exactly as the bus minted them,
#      and no failure or retry ever bypasses the bus to direct execution;
#   5. nil subject_ref constructs: manufacture refuses nothing -- the walls
#      (missing action_id) stand at the DO boundary, downstream of intent.
#
# Canon status (gapfix-intent-canon-004): the canonical-local declarations
# RETIRED. lib admitted the family (b43e051 SurfaceIntent, a037c50 candidate
# envelope, 90281a0 delegated-DO dispatch; v50 reconciliation 4058b87), so per
# the retirement promise every edge below now runs against the REAL modules:
# `AshSurface.Intent`, `AshSurface.Intent.IR`, `AshSurface.Intent.Candidate`,
# `AshSurface.Intent.Dispatch`, and the `AshSurface.Intent.CommandBus`
# behaviour with its `AshSurface.Intent.Envelope` handover. Only the flaky
# bus remains local: it is an injected test double, not a canon.
#
# ONE IDENTITY LAW, repo-wide: `intent_id` is the lowercase sha256 hex over
# `Jason.encode!([surface_action_id, input, subject_ref])` -- 64 hex chars,
# no prefix -- owned solely by lib/ash_surface/intent.ex. The superseded
# test-local scheme (prefixed 16-hex over `term_to_binary` of the triple) is
# retired here and in intent_round_trip_test.exs. Recorded semantic delta of
# that reconciliation, so nothing retires silently: the old law was
# term-true, the one law is JSON-true -- `%{n: 1}` and `%{"n" => 1}` are the
# SAME identity under canonical JSON (both encode `{"n":1}`), while a value
# type change (`1` vs `"1"`) stays a different edge. Storage remains
# verbatim in every case: the map handed in is the map stored, byte-equal.

defmodule AshSurface.IntentPathTest.FlakyBus do
  @moduledoc """
  Injected flaky bus: stands in for a separately authorized actuator.

  Implements the `AshSurface.Intent.CommandBus` behaviour with a
  caller-scripted outcome sequence, so transient failures and recovery are
  observable facts. The bus instance rides in `context` (`%{bus: pid}`):
  injection, not lookup. Every submit is recorded; receipts are
  content-addressed from the exact envelope, so identical handovers receipt
  identically.
  """

  @behaviour AshSurface.Intent.CommandBus

  use Agent

  @doc "Starts the flaky bus with a scripted outcome list, one per submit."
  @spec start_link([{:ok, term()} | {:error, term()}]) :: {:ok, pid()}
  def start_link(script) do
    case Agent.start_link(fn -> {script, []} end) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, _pid}} -> {:error, :bus_already_started}
    end
  end

  @impl true
  def submit(intent, %{bus: pid} = context) do
    Agent.get_and_update(pid, fn
      {[outcome | rest], calls} ->
        {receipt_for(outcome, intent), {rest, [{intent, context, outcome} | calls]}}

      {[], calls} ->
        exhausted = {intent, context, :REFUSED_SCRIPT_EXHAUSTED}
        {{:error, :REFUSED_SCRIPT_EXHAUSTED}, {[], [exhausted | calls]}}
    end)
  end

  @doc "All recorded submits, oldest first, as `{intent, context, outcome}`."
  @spec calls(pid()) :: [{term(), term(), term()}]
  def calls(pid), do: pid |> Agent.get(fn {_, calls} -> calls end) |> Enum.reverse()

  defp receipt_for({:ok, _term}, intent) do
    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(intent)) |> Base.encode16(case: :lower)

    {:ok, %{receipt_ref: "rcpt_" <> binary_part(digest, 0, 16)}}
  end

  defp receipt_for(other, _intent), do: other
end

defmodule AshSurface.IntentPathTest do
  @moduledoc """
  Chicago edge tests for the intent path:

  `AshSurface.Intent.create/3 -> AshSurface.Intent.Candidate.to_candidate/2
  -> AshSurface.Intent.Dispatch.submit/3` on an injected flaky
  `AshSurface.Intent.CommandBus`.

  The path is state, not traversal: every edge below is a falsifier against
  idempotence loss, input coercion, dishonest nils, error laundering, or a
  local-execution bypass. All shapes come from the admitted lib family; the
  former canonical-local declarations retired per the header (one identity
  law, gapfix-intent-canon-004).
  """

  use ExUnit.Case, async: true

  alias AshSurface.Intent
  alias AshSurface.Intent.{Candidate, Dispatch, IR}
  alias AshSurface.IntentPathTest.FlakyBus

  @action "AshSurface.IntentPathTest.MilestoneLedger#record"
  @input %{member_id: "member_zoela_01", milestone_id: "milestone_serve_43", cost_physical: 10}

  # EDGE 1 -- identical intents idempotent --------------------------------

  test "identical addressed triples keep one intent_id across re-creation" do
    a = Intent.create(@action, @input, "ir:abc123")
    b = Intent.create(@action, @input, "ir:abc123")

    assert a.intent_id == b.intent_id

    # One identity law: bare lowercase sha256 hex over the canonical JSON of
    # the ordered triple -- 64 chars, no prefix (lib/ash_surface/intent.ex).
    assert a.intent_id =~ ~r/^[0-9a-f]{64}$/
    assert byte_size(a.intent_id) == 64

    # Time is not identity: created_at never enters the digest, so the two
    # records are the same edge even if stamped at different instants.
    assert %{a | created_at: nil} == %{b | created_at: nil}

    # A different subject or action is a different edge -- the id discriminates.
    other_subject = Intent.create(@action, @input, "ir:def456")
    other_action = Intent.create(@action <> ":undo", @input, "ir:abc123")
    assert a.intent_id != other_subject.intent_id
    assert a.intent_id != other_action.intent_id
  end

  test "creation is pure: the SurfaceIntent module exports no execution path" do
    # Intent manufacture is data only. Any execute/submit/dispatch/actuate
    # export would be a local-DO bypass; this tripwire fails the build the
    # day one appears (held against the lib owner AshSurface.Intent).
    for name <- [:execute, :submit, :dispatch, :actuate, :run, :call, :apply],
        arity <- 1..4 do
      refute function_exported?(Intent, name, arity),
             "SurfaceIntent must not export #{name}/#{arity}: intent is not actuation"
    end

    assert function_exported?(Intent, :create, 3)
  end

  # EDGE 2 -- input maps pass through byte-equal --------------------------

  test "input maps ride verbatim: byte-equal storage, no key or value coercion" do
    input = %{
      "counter" => 1,
      :nested => %{:deep => [1, 2, 3], "mixed" => "x"},
      :nil_valued => nil,
      :atom => :still_there
    }

    intent = Intent.create(@action, input, "ir:abc123")

    assert intent.input === input
    assert :erlang.term_to_binary(intent.input) == :erlang.term_to_binary(input)

    # Re-creation hands back the same bytes: no silent normalization between
    # calls either.
    again = Intent.create(@action, input, "ir:abc123")

    assert :erlang.term_to_binary(again.input) == :erlang.term_to_binary(input)

    # Identity under the ONE law is canonical JSON, so the atom-key and
    # string-key maps collapse to the same identity (both encode {"n":1}) --
    # that is the law, not storage coercion -- while a value-type change
    # ("1" vs 1) stays a different edge. The stored maps themselves remain
    # verbatim, asserted below: nothing was normalized on the way in.
    json_key = Intent.create(@action, %{"n" => 1}, nil)
    atom_key = Intent.create(@action, %{n: 1}, nil)
    string_val = Intent.create(@action, %{"n" => "1"}, nil)

    assert json_key.intent_id == atom_key.intent_id
    assert json_key.intent_id != string_val.intent_id
    assert json_key.input === %{"n" => 1}
    assert atom_key.input === %{n: 1}
    assert string_val.input === %{"n" => "1"}
  end

  # EDGE 3 -- all-nil-section candidates construct with honest nils -------

  test "an IR with no sections projects a candidate with nils present, never defaults" do
    intent = Intent.create(@action, @input, nil)
    bare_ir = IR.create(@action)

    assert bare_ir.capability == nil
    assert bare_ir.semantic == nil

    candidate = Candidate.to_candidate(intent, bare_ir)

    # Exact envelope shape: six keys, the honest nils PRESENT as nil fields
    # (Map equality would pass with dropped keys only if keys were gone --
    # the explicit has_key? assertions pin presence), no fabricated
    # placeholders, input untransformed, self-description exact.
    assert Map.has_key?(candidate, :capability_id)
    assert Map.has_key?(candidate, :subject_iri)
    assert Map.has_key?(candidate, :semantic_id)

    assert candidate == %{
             capability_id: nil,
             subject_iri: nil,
             input: @input,
             semantic_id: nil,
             standing: :candidate,
             authority: :none
           }

    # A present-but-fieldless semantic section is equally honest: a section
    # without subject_iri is nil for subject_iri, not "" or :unknown.
    sparse = Candidate.to_candidate(intent, IR.create(@action, %{capability_id: "cap:1"}, %{}))

    assert sparse.capability_id == "cap:1"
    assert sparse.subject_iri == nil
    assert sparse.semantic_id == nil
    assert sparse.standing == :candidate
  end

  # EDGE 4 -- flaky-bus retries surface typed errors, no bypass -----------

  test "flaky-bus failures surface as the bus's own typed errors, then recover" do
    intent = Intent.create(@action, @input, nil)
    ir = IR.create(@action)

    envelope = Candidate.to_candidate(intent, ir)

    # The DO caller stamps the IR action identity into the candidate map:
    # action_id is the boundary key Dispatch requires; the rest rides
    # verbatim as the intent payload.
    candidate_map = Map.put(envelope, :action_id, ir.action_id)

    {:ok, bus} =
      FlakyBus.start_link([
        {:error, :REFUSED_NO_AUTHORITY},
        {:error, {:transport_down, :reconnecting}},
        {:ok, :applied},
        {:ok, :applied}
      ])

    context = %{bus: bus, actor: "member_zoela_01"}

    # Caller-driven retries against the same injected bus. Every failure
    # surfaces EXACTLY as the bus minted it: same shape, same terms, never
    # rewrapped, never downgraded to a crash, never laundered into {:ok, _}.
    assert {:error, :REFUSED_NO_AUTHORITY} = Dispatch.submit(candidate_map, FlakyBus, context)

    assert {:error, {:transport_down, :reconnecting}} =
             Dispatch.submit(candidate_map, FlakyBus, context)

    assert {:ok, %{receipt_ref: first}} = Dispatch.submit(candidate_map, FlakyBus, context)
    assert {:ok, %{receipt_ref: again}} = Dispatch.submit(candidate_map, FlakyBus, context)

    # Content-addressed receipt: the identical handover receipts
    # identically -- recovery after flakiness is idempotent at the bus.
    assert first == again
    assert String.starts_with?(first, "rcpt_")

    # NO BYPASS, observed: four submits, four bus consultations, and the bus
    # is the only actuator in the room. A direct-execution shortcut past a
    # failing bus would show up here as a missing call.
    calls = FlakyBus.calls(bus)
    assert length(calls) == 4

    # The bus saw the exact scripted sequence, one consultation per submit,
    # in order: retries went back through the bus, never around it.
    assert Enum.map(calls, &elem(&1, 2)) == [
             {:error, :REFUSED_NO_AUTHORITY},
             {:error, {:transport_down, :reconnecting}},
             {:ok, :applied},
             {:ok, :applied}
           ]

    for {handover, handed_context, _outcome} <- calls do
      assert handover.action_id == ir.action_id
      assert handed_context === context

      # The payload is the envelope byte-for-byte on every attempt --
      # failing or not: no coercion at the DO boundary either.
      assert :erlang.term_to_binary(handover.payload) == :erlang.term_to_binary(envelope)
    end

    # NO BYPASS, structural: Dispatch exports exactly submit/3 and nothing
    # that could execute an action itself.
    for name <- [:execute, :exec, :apply_action, :actuate, :run, :dispatch_direct],
        arity <- 1..4 do
      refute function_exported?(Dispatch, name, arity),
             "Dispatch must not export #{name}/#{arity}: delegated-DO only"
    end
  end

  test "fail-closed input refusals fire before the bus is ever touched" do
    {:ok, bus} = FlakyBus.start_link([])

    # Missing and blank action ids are refused typed, pre-bus.
    assert {:error, {:invalid_candidate, :missing_action_id}} ==
             Dispatch.submit(%{input: @input}, FlakyBus, %{bus: bus})

    assert {:error, {:invalid_candidate, :missing_action_id}} ==
             Dispatch.submit(%{action_id: "", input: @input}, FlakyBus, %{bus: bus})

    assert {:error, {:invalid_candidate, :invalid_action_id}} ==
             Dispatch.submit(%{action_id: :not_a_string}, FlakyBus, %{bus: bus})

    assert {:error, {:invalid_candidate, :candidate_must_be_a_map}} ==
             Dispatch.submit(:not_a_map, FlakyBus, %{bus: bus})

    # A non-conforming bus is refused typed without a call.
    assert {:error, :REFUSED_NO_COMMAND_BUS} ==
             Dispatch.submit(%{action_id: @action, input: @input}, Kernel, %{bus: bus})

    assert {:error, :REFUSED_NO_COMMAND_BUS} ==
             Dispatch.submit(%{action_id: @action, input: @input}, nil, %{bus: bus})

    # The bus saw none of it: zero consultations across all six refusals.
    assert FlakyBus.calls(bus) == []
  end

  # EDGE 5 -- nil subject_ref constructs; walls are downstream law --------

  test "nil subject_ref constructs and flows; the wall stands at the DO boundary" do
    # Manufacture refuses nothing about subject_ref: the lib canon imposes no
    # guard on it (nil is honest content, not coerced to "" and not
    # rejected); its own spec prefers an IRI-shaped ref. The wall stands
    # downstream, at the DO boundary.
    nil_subject = Intent.create(@action, @input, nil)
    empty_subject = Intent.create(@action, @input, "")
    iri_subject = Intent.create(@action, @input, "ir:abc123")

    assert nil_subject.subject_ref == nil
    assert nil_subject.intent_id != empty_subject.intent_id
    assert nil_subject.intent_id != iri_subject.intent_id

    # The nil-subject intent still projects a candidate envelope (honest
    # nils ride from the IR, edge 3) and still dispatches: the pipeline has
    # no gate on subject_ref.
    ir = IR.create(@action, %{capability_id: "cap:1"}, %{semantic_id: "sem:1", subject_iri: nil})

    envelope = Candidate.to_candidate(nil_subject, ir)
    candidate_map = Map.put(envelope, :action_id, ir.action_id)

    {:ok, bus} = FlakyBus.start_link([{:ok, :applied}])

    assert {:ok, %{receipt_ref: ref}} =
             Dispatch.submit(candidate_map, FlakyBus, %{bus: bus, actor: "member_zoela_01"})

    assert String.starts_with?(ref, "rcpt_")

    [{handover, _context, {:ok, :applied}}] = FlakyBus.calls(bus)
    assert handover.payload.subject_iri == nil
    assert :erlang.term_to_binary(handover.payload) == :erlang.term_to_binary(envelope)

    # The wall is DOWNSTREAM law: the DO boundary does refuse a candidate
    # without an action identity. Manufacture holds no such fence; dispatch
    # holds exactly that one.
    assert {:error, {:invalid_candidate, :missing_action_id}} ==
             Dispatch.submit(Map.delete(candidate_map, :action_id), FlakyBus, %{bus: bus})
  end
end
