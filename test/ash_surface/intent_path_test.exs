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
# Canonical-local declaration (per file discipline, precedent 52a9c2c): the
# intent family is absent from lib on this branch, so the canonical shapes are
# declared here exactly as manufactured on their owning branches -- create/3
# content addressing and the envelope from a037c50, the delegated-DO
# Dispatch/CommandBus contract from 90281a0. When lib admits them, these
# declarations retire in favor of the real modules.

defmodule AshSurface.IntentPathTest.SurfaceIntent do
  @moduledoc """
  Canonical SurfaceIntent: the pre-dispatch record of a consumer's will to act.

  An intent is DATA. It records that a surface wants to execute one
  `surface_action_id` with `input` against `subject_ref`. It carries no
  transport, no dispatch, and no authority; turning it into anything sendable
  is a separate, separately-gated step.

  Canonical-local declaration: owns the `SurfaceIntent` shape until a
  dedicated `intent.ex` is admitted. Constructed only through `create/3`,
  which content-addresses `intent_id` from the
  `(surface_action_id, subject_ref, input)` triple so identical will-to-act
  keeps one identity regardless of when it is re-created. `created_at` is
  captured at construction and never participates in the id: time is not
  identity.
  """

  @enforce_keys [:surface_action_id, :input, :subject_ref, :created_at, :intent_id]
  defstruct [:surface_action_id, :input, :subject_ref, :created_at, :intent_id]

  @type t :: %__MODULE__{
          surface_action_id: String.t(),
          input: term(),
          subject_ref: term(),
          created_at: DateTime.t(),
          intent_id: String.t()
        }

  @doc """
  Creates a content-addressed `SurfaceIntent`.

  `input` is stored exactly as given -- no normalization, no coercion, no
  JSON round-trip. `subject_ref` may be any subject term (an IRI string, a
  reference map, or `nil`; walls are downstream law). Re-creating the same
  triple yields the same identity.
  """
  @spec create(String.t(), term(), term()) :: t()
  def create(surface_action_id, input, subject_ref) when is_binary(surface_action_id) do
    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary({surface_action_id, subject_ref, input}))
      |> Base.encode16(case: :lower)

    %__MODULE__{
      surface_action_id: surface_action_id,
      input: input,
      subject_ref: subject_ref,
      created_at: DateTime.utc_now(),
      intent_id: "intent_" <> binary_part(digest, 0, 16)
    }
  end
end

defmodule AshSurface.IntentPathTest.IR do
  @moduledoc """
  Canonical IR action shape consumed by the candidate envelope.

  Canonical-local declaration until a dedicated `ir.ex` is admitted. An IR
  action is identified by `action_id` and carries two optional sections, each
  a plain map or `nil`: `:capability` and `:semantic`.

  A `nil` section is legal and meaningful: it means the source projected no
  such section, and every field that would have been pulled from it must
  surface as `nil`, never as a fabricated default.
  """

  @enforce_keys [:action_id]
  defstruct [:action_id, :capability, :semantic]

  @type section :: map() | nil

  @type t :: %__MODULE__{
          action_id: String.t(),
          capability: section(),
          semantic: section()
        }

  @doc """
  Creates an IR action. Sections default to `nil`; pass plain maps with atom
  keys (`%{capability_id: id}`, `%{semantic_id: id, subject_iri: iri}`).
  """
  @spec create(String.t(), section(), section()) :: t()
  def create(action_id, capability \\ nil, semantic \\ nil)
      when is_binary(action_id) and (is_map(capability) or is_nil(capability)) and
             (is_map(semantic) or is_nil(semantic)) do
    %__MODULE__{action_id: action_id, capability: capability, semantic: semantic}
  end
end

defmodule AshSurface.IntentPathTest.Candidate do
  @moduledoc """
  SA2A candidate envelope, shaped after `ash_a2a`'s candidate semantics.

  `to_candidate/2` folds a `SurfaceIntent` together with the IR action it
  names into the candidate envelope, which always self-describes as
  `standing: :candidate, authority: :none`.

  A candidate is DATA, never sent: no dispatch, no transport selection, no
  mutation of the intent or the IR. Fields are pulled honestly --
  `capability_id` from the IR capability section, `semantic_id`/`subject_iri`
  from the IR semantic section, `input` passed through from the intent
  untransformed. A missing section or field yields `nil`, never a placeholder.
  """

  alias AshSurface.IntentPathTest.{IR, SurfaceIntent}

  @envelope_keys ~w(capability_id subject_iri input semantic_id standing authority)a

  @doc """
  Projects `intent` and `ir_action` into the SA2A candidate envelope.

  Returns a plain map with `:capability_id`, `:subject_iri`, `:input`,
  `:semantic_id`, `:standing` (always `:candidate`), and `:authority`
  (always `:none`). Nil sections yield nil fields, present in the map.
  """
  @spec to_candidate(SurfaceIntent.t(), IR.t()) :: map()
  def to_candidate(%SurfaceIntent{} = intent, %IR{} = ir_action) do
    Map.new(@envelope_keys, fn
      :capability_id -> {:capability_id, section_field(ir_action.capability, :capability_id)}
      :subject_iri -> {:subject_iri, section_field(ir_action.semantic, :subject_iri)}
      :input -> {:input, intent.input}
      :semantic_id -> {:semantic_id, section_field(ir_action.semantic, :semantic_id)}
      :standing -> {:standing, :candidate}
      :authority -> {:authority, :none}
    end)
  end

  defp section_field(nil, _field), do: nil
  defp section_field(section, field) when is_map(section), do: Map.get(section, field)
end

defmodule AshSurface.IntentPathTest.CommandBus do
  @moduledoc """
  Delegated-DO boundary for intent dispatch.

  The surface never executes a consequential action itself. Actuation happens
  only on the far side of this behaviour, in a bus injected by the operator's
  runtime (Phoenix channel, HTTP command relay, test double). The bus owns
  the authority cut, the actuation, and the receipt; the surface owns only
  the manufacture of the intent handed over.
  """

  @doc """
  Submits a manufactured intent for actuation.

  Returns the bus's own receipt-bearing outcome `{:ok, receipt}` or a typed
  refusal `{:error, reason}` (for example `{:error, :REFUSED_NO_AUTHORITY}`).
  """
  @callback submit(AshSurface.IntentPathTest.Intent.t(), map()) ::
              {:ok, term()} | {:error, term()}
end

defmodule AshSurface.IntentPathTest.Intent do
  @moduledoc """
  Minimal manufactured intent handed to an injected `CommandBus`.

  The whole shape of the delegated-DO handover: an action identity plus the
  candidate payload carried verbatim. No execution semantics live here to
  misinterpret.
  """

  @enforce_keys [:action_id]
  defstruct [:action_id, :payload]

  @type t :: %__MODULE__{
          action_id: String.t(),
          payload: map()
        }
end

defmodule AshSurface.IntentPathTest.Dispatch do
  @moduledoc """
  Delegated-DO adapter: manufacture an intent from an admitted candidate map
  and hand it, with the caller's context, to the INJECTED command bus.

  This module never executes anything itself:

    - no Ash action calls; no transport, process, or store of its own;
    - shape validation only, then delegation via `command_bus.submit/2`;
    - bus outcomes pass through EXACTLY -- receipts are the bus's own, and
      typed refusals (e.g. `{:error, :REFUSED_NO_AUTHORITY}`) propagate
      untouched, never rewrapped or downgraded. A flaky bus's transient
      failures surface as the bus minted them; there is no bypass path.

  The only refusals minted here are fail-closed input refusals: an invalid
  candidate is refused before the bus is ever touched, and a bus that does
  not conform to the `CommandBus` behaviour is refused typed.
  """

  alias AshSurface.IntentPathTest.Intent

  @doc """
  Manufactures an intent from `candidate_map` and submits it to `command_bus`.

  `candidate_map` must be a map carrying a non-empty string `:action_id`;
  every other key rides the intent payload verbatim. `context` (for example
  bus handle, actor, tenant, or authority material) is handed to the bus
  unchanged.
  """
  @spec submit(map(), module(), map()) :: {:ok, term()} | {:error, term()}
  def submit(candidate_map, command_bus, context) do
    with :ok <- validate_candidate(candidate_map),
         :ok <- validate_bus(command_bus) do
      intent = %Intent{
        action_id: candidate_map.action_id,
        payload: Map.delete(candidate_map, :action_id)
      }

      command_bus.submit(intent, context)
    end
  end

  defp validate_candidate(candidate_map) when is_map(candidate_map) do
    action_id = Map.get(candidate_map, :action_id)

    cond do
      is_binary(action_id) and action_id != "" ->
        :ok

      action_id in [nil, ""] ->
        {:error, {:invalid_candidate, :missing_action_id}}

      true ->
        {:error, {:invalid_candidate, :invalid_action_id}}
    end
  end

  defp validate_candidate(_), do: {:error, {:invalid_candidate, :candidate_must_be_a_map}}

  defp validate_bus(command_bus)
       when is_atom(command_bus) and command_bus != nil do
    if function_exported?(command_bus, :submit, 2) do
      :ok
    else
      {:error, :REFUSED_NO_COMMAND_BUS}
    end
  end

  defp validate_bus(_), do: {:error, :REFUSED_NO_COMMAND_BUS}
end

defmodule AshSurface.IntentPathTest.FlakyBus do
  @moduledoc """
  Injected flaky bus: stands in for a separately authorized actuator.

  Implements the `CommandBus` behaviour with a caller-scripted outcome
  sequence, so transient failures and recovery are observable facts. The bus
  instance rides in `context` (`%{bus: pid}`): injection, not lookup. Every
  submit is recorded; receipts are content-addressed from the exact intent,
  so identical handovers receipt identically.
  """

  @behaviour AshSurface.IntentPathTest.CommandBus

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

  `SurfaceIntent.create/3 -> Candidate.to_candidate/2 -> Dispatch.submit/3`
  on an injected `CommandBus`.

  The path is state, not traversal: every edge below is a falsifier against
  idempotence loss, input coercion, dishonest nils, error laundering, or a
  local-execution bypass. Canonical shapes are declared locally in this file
  (absent from lib on this branch) per file discipline; see the header.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IntentPathTest.{Candidate, Dispatch, FlakyBus, IR, SurfaceIntent}

  @action "AshSurface.IntentPathTest.MilestoneLedger#record"
  @input %{member_id: "member_zoela_01", milestone_id: "milestone_serve_43", cost_physical: 10}

  # EDGE 1 -- identical intents idempotent --------------------------------

  test "identical addressed triples keep one intent_id across re-creation" do
    a = SurfaceIntent.create(@action, @input, "ir:abc123")
    b = SurfaceIntent.create(@action, @input, "ir:abc123")

    assert a.intent_id == b.intent_id
    assert String.starts_with?(a.intent_id, "intent_")

    # Time is not identity: created_at never enters the digest, so the two
    # records are the same edge even if stamped at different instants.
    assert %{a | created_at: nil} == %{b | created_at: nil}
    assert byte_size(a.intent_id) == 7 + 16

    # A different subject or action is a different edge -- the id discriminates.
    other_subject = SurfaceIntent.create(@action, @input, "ir:def456")
    other_action = SurfaceIntent.create(@action <> ":undo", @input, "ir:abc123")
    assert a.intent_id != other_subject.intent_id
    assert a.intent_id != other_action.intent_id
  end

  test "creation is pure: the SurfaceIntent module exports no execution path" do
    # Intent manufacture is data only. Any execute/submit/dispatch/actuate
    # export would be a local-DO bypass; this tripwire fails the build the
    # day one appears.
    for name <- [:execute, :submit, :dispatch, :actuate, :run, :call, :apply],
        arity <- 1..4 do
      refute function_exported?(SurfaceIntent, name, arity),
             "SurfaceIntent must not export #{name}/#{arity}: intent is not actuation"
    end

    assert function_exported?(SurfaceIntent, :create, 3)
  end

  # EDGE 2 -- input maps pass through byte-equal --------------------------

  test "input maps ride verbatim: byte-equal storage, no key or value coercion" do
    input = %{
      "counter" => 1,
      :nested => %{:deep => [1, 2, 3], "mixed" => "x"},
      :nil_valued => nil,
      :atom => :still_there
    }

    intent = SurfaceIntent.create(@action, input, "ir:abc123")

    assert intent.input === input
    assert :erlang.term_to_binary(intent.input) == :erlang.term_to_binary(input)

    # Re-creation hands back the same bytes: no silent normalization between
    # calls either.
    again = SurfaceIntent.create(@action, input, "ir:abc123")

    assert :erlang.term_to_binary(again.input) == :erlang.term_to_binary(input)

    # Coercion would collapse identity: string-key 1, atom-key 1, and
    # string "1" must be three DISTINCT intents, so no layer normalized
    # key types or stringified values on the way in.
    ids =
      [
        SurfaceIntent.create(@action, %{"n" => 1}, nil),
        SurfaceIntent.create(@action, %{n: 1}, nil),
        SurfaceIntent.create(@action, %{"n" => "1"}, nil)
      ]
      |> Enum.map(& &1.intent_id)
      |> Enum.uniq()
      |> length()

    assert ids == 3
  end

  # EDGE 3 -- all-nil-section candidates construct with honest nils -------

  test "an IR with no sections projects a candidate with nils present, never defaults" do
    intent = SurfaceIntent.create(@action, @input, nil)
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
    intent = SurfaceIntent.create(@action, @input, nil)
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
    # Manufacture refuses nothing about subject_ref: nil is honest content,
    # not coerced to "" and not rejected.
    nil_subject = SurfaceIntent.create(@action, @input, nil)
    empty_subject = SurfaceIntent.create(@action, @input, "")
    iri_subject = SurfaceIntent.create(@action, @input, "ir:abc123")

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
