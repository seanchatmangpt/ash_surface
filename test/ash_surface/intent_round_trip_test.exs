# Chicago integration: the full human pipeline AS STATE, in one test.
#
#   O* -> Human (hand-built five-section IR) -> SurfaceIntent -> Candidate
#     -> DO (submit on an injected recording fake bus) -> Receipt -> Event
#
# The intent loop must never actuate: the real inline Ash resource sits behind a
# recording Simple-backed data layer, and the loop must leave that recorder
# EMPTY. Actuation belongs to a separately authorized actuator behind a real
# bus, never to ash_surface intent manufacture.

defmodule AshSurface.IntentRoundTripTest.Recorder do
  @moduledoc """
  Process recorder for resource invocations.

  Every data-layer callback fired against the real resource lands here. The
  loop must leave it empty; a positive control at the end of the test proves
  the recorder is not vacuously green.
  """

  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc "Records an invocation. Silently skips when the recorder is not running (compile time)."
  def record(event) do
    if pid = Process.whereis(__MODULE__) do
      Agent.update(pid, &[event | &1])
    end
  end

  @doc "All recorded invocations, in invocation order."
  def events do
    __MODULE__ |> Agent.get(& &1) |> Enum.reverse()
  end
end

defmodule AshSurface.IntentRoundTripTest.RecordingDataLayer do
  @moduledoc """
  `Ash.DataLayer.Simple` semantics with every observable callback recorded.

  Any feature probe (`can?/2`), read, or mutation of the resource is visible in
  the Recorder, so "the resource was never invoked" is an observed fact, not an
  assumption.
  """

  alias AshSurface.IntentRoundTripTest.Recorder

  @simple Ash.DataLayer.Simple

  def can?(resource, feature) do
    Recorder.record({:can?, resource, feature})
    @simple.can?(resource, feature)
  end

  def resource_to_query(resource, domain) do
    Recorder.record({:resource_to_query, resource})
    @simple.resource_to_query(resource, domain)
  end

  def run_query(query, resource) do
    Recorder.record({:run_query, resource})
    @simple.run_query(query, resource)
  end

  def create(resource, changeset) do
    Recorder.record({:create, resource})
    @simple.create(resource, changeset)
  end

  def bulk_create(resource, stream, options) do
    Recorder.record({:bulk_create, resource})
    @simple.bulk_create(resource, stream, options)
  end

  def update(resource, changeset) do
    Recorder.record({:update, resource})
    @simple.update(resource, changeset)
  end

  def destroy(resource, changeset) do
    Recorder.record({:destroy, resource})
    @simple.destroy(resource, changeset)
  end

  def limit(query, limit, resource), do: @simple.limit(query, limit, resource)
  def offset(query, offset, resource), do: @simple.offset(query, offset, resource)
  def set_tenant(resource, query, tenant), do: @simple.set_tenant(resource, query, tenant)
  def filter(query, filter, resource), do: @simple.filter(query, filter, resource)
  def sort(query, sort, resource), do: @simple.sort(query, sort, resource)
  def set_context(resource, query, context), do: @simple.set_context(resource, query, context)
end

defmodule AshSurface.IntentRoundTripTest.IntentIR do
  @moduledoc """
  Minimal canonical Intent IR: exactly five sections, nothing else.

  `subject | action | input | authority | evidence`

  The Human surface hands these over; the intent pipeline consumes them as
  state and never invents a sixth section.
  """

  @canonical_sections [:subject, :action, :input, :authority, :evidence]

  defstruct @canonical_sections

  @type t :: %__MODULE__{
          subject: map(),
          action: map(),
          input: map(),
          authority: map(),
          evidence: map()
        }

  @doc "The canonical five sections, in canonical order."
  @spec canonical_sections() :: [atom(), ...]
  def canonical_sections, do: @canonical_sections

  @doc "Admits a hand-built section map only when it carries exactly the five canonical sections."
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(sections) when is_map(sections) do
    keys = Map.keys(sections)
    missing = @canonical_sections -- keys
    extra = keys -- @canonical_sections

    cond do
      missing != [] -> {:error, {:missing_sections, Enum.sort(missing)}}
      extra != [] -> {:error, {:unknown_sections, Enum.sort(extra)}}
      true -> {:ok, struct(__MODULE__, sections)}
    end
  end
end

defmodule AshSurface.IntentRoundTripTest.Candidate do
  @moduledoc "Minimal canonical DO-boundary candidate projected from a SurfaceIntent."

  @enforce_keys [
    :action_id,
    :semantic_id,
    :authority_boundary,
    :do_authority,
    :input,
    :subject_ref,
    :intent_ref
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
          action_id: String.t(),
          semantic_id: String.t(),
          authority_boundary: String.t(),
          do_authority: boolean(),
          input: map(),
          subject_ref: String.t(),
          intent_ref: String.t()
        }
end

defmodule AshSurface.IntentRoundTripTest.SurfaceIntent do
  @moduledoc """
  Minimal canonical SurfaceIntent: admits a five-section IR requesting the DO
  boundary, and projects it to exactly one Candidate.
  """

  alias AshSurface.IntentRoundTripTest.{Candidate, IntentIR}

  @enforce_keys [:intent_id, :ir]
  defstruct [:intent_id, :ir, standing: :ADMITTED]

  @type t :: %__MODULE__{
          intent_id: String.t(),
          ir: IntentIR.t(),
          standing: atom()
        }

  @doc "Admits an IR whose authority section requests the DO boundary with a receipt."
  @spec create(IntentIR.t()) :: {:ok, t()} | {:error, term()}
  def create(%IntentIR{authority: authority} = ir) do
    if authority[:boundary] == :DO and authority[:do_authority] == true and
         authority[:receipt_required] == true do
      {:ok, %__MODULE__{intent_id: intent_id(ir), ir: ir}}
    else
      {:error, :REFUSED_NO_AUTHORITY}
    end
  end

  @doc "Projects the admitted intent to the single candidate that may cross the bus."
  @spec to_candidate(t()) :: Candidate.t()
  def to_candidate(%__MODULE__{intent_id: intent_id, ir: ir}) do
    %Candidate{
      action_id: ir.action[:action_id],
      semantic_id: ir.action[:semantic_id],
      authority_boundary: "DO",
      do_authority: true,
      input: ir.input,
      subject_ref: ir.subject[:exact_subject],
      intent_ref: intent_id
    }
  end

  defp intent_id(ir) do
    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(ir)) |> Base.encode16(case: :lower)

    "intent_" <> binary_part(digest, 0, 16)
  end
end

defmodule AshSurface.IntentRoundTripTest.Receipt do
  @moduledoc "Minimal canonical consequence receipt returned by a bus dispatch."

  @enforce_keys [
    :receipt_ref,
    :standing,
    :dispatch_state,
    :subject_ref,
    :action_id,
    :candidate_digest
  ]

  defstruct @enforce_keys

  @type t :: %__MODULE__{
          receipt_ref: String.t(),
          standing: atom(),
          dispatch_state: String.t(),
          subject_ref: String.t(),
          action_id: String.t(),
          candidate_digest: String.t()
        }
end

defmodule AshSurface.IntentRoundTripTest.Bus do
  @moduledoc """
  Injected transport boundary for DO-boundary candidate dispatch.

  A bus value is `{module, ref}` where `module` implements this behaviour and
  `ref` is the module-owned process handle. Dispatch stays ignorant of the
  concrete bus: injection, not lookup.
  """

  alias AshSurface.IntentRoundTripTest.{Candidate, Receipt}

  @callback dispatch(bus :: {module(), term()}, Candidate.t()) ::
              {:ok, Receipt.t()} | {:error, term()}

  @callback calls(bus :: {module(), term()}) :: [Candidate.t()]
end

defmodule AshSurface.IntentRoundTripTest.RecordingFakeBus do
  @moduledoc """
  Recording fake bus: content-addresses the exact candidate into a receipt and
  records every dispatch. It never touches the Ash resource; standing in for a
  separately authorized actuator is its entire job.
  """

  @behaviour AshSurface.IntentRoundTripTest.Bus

  alias AshSurface.IntentRoundTripTest.{Candidate, Receipt}

  @doc "Starts the fake bus. Dispatch receipts are derived from the exact candidate."
  @spec start_link(keyword()) :: {:ok, {module(), pid()}}
  def start_link(_opts \\ []) do
    case Agent.start_link(fn -> [] end) do
      {:ok, pid} -> {:ok, {__MODULE__, pid}}
      error -> error
    end
  end

  @impl true
  def dispatch({_mod, ref}, %Candidate{} = candidate) do
    receipt =
      %Receipt{
        receipt_ref: "rcpt_" <> binary_part(candidate_digest(candidate), 0, 16),
        standing: :ALIVE,
        dispatch_state: "completed",
        subject_ref: candidate.subject_ref,
        action_id: candidate.action_id,
        candidate_digest: candidate_digest(candidate)
      }

    Agent.get_and_update(ref, fn calls -> {{:ok, receipt}, calls ++ [candidate]} end)
  end

  @impl true
  def calls({_mod, ref}), do: Agent.get(ref, & &1)

  defp candidate_digest(candidate) do
    :crypto.hash(:sha256, :erlang.term_to_binary(candidate)) |> Base.encode16(case: :lower)
  end
end

defmodule AshSurface.IntentRoundTripTest.Dispatch do
  @moduledoc """
  Minimal canonical dispatch: submits one DO-authorized candidate to an
  INJECTED bus exactly once and hands back the receipt-bearing outcome.
  """

  alias AshSurface.IntentRoundTripTest.Candidate

  @spec submit(Candidate.t(), {module(), term()}) :: {:ok, term()} | {:error, term()}
  def submit(%Candidate{authority_boundary: "DO", do_authority: true} = candidate, {mod, ref}) do
    mod.dispatch({mod, ref}, candidate)
  end

  def submit(%Candidate{}, _bus), do: {:error, :REFUSED_NO_AUTHORITY}
end

defmodule AshSurface.IntentRoundTripTest.LedgerDomain do
  @moduledoc "Domain for the inline ledger resource."

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.IntentRoundTripTest.MilestoneLedger)
  end
end

defmodule AshSurface.IntentRoundTripTest.MilestoneLedger do
  @moduledoc """
  Real inline Ash resource for the intent round trip.

  Simple-backed recording data layer: fully usable by an authorized actuator,
  and every invocation observable in the Recorder.
  """

  use Ash.Resource,
    domain: AshSurface.IntentRoundTripTest.LedgerDomain,
    data_layer: AshSurface.IntentRoundTripTest.RecordingDataLayer

  attributes do
    uuid_primary_key(:id)
    attribute(:member_id, :string, public?: true, allow_nil?: false)
    attribute(:milestone_id, :string, public?: true, allow_nil?: false)
    attribute(:cost_physical, :integer, public?: true, allow_nil?: false)
    attribute(:reward_spiritual, :integer, public?: true, allow_nil?: false)
    attribute(:status, :string, public?: true, default: "recorded")
  end

  actions do
    defaults([:read])

    create :record do
      accept([:member_id, :milestone_id, :cost_physical, :reward_spiritual])
    end
  end
end

defmodule AshSurface.IntentRoundTripTest do
  @moduledoc """
  Chicago integration test for the full human pipeline as state:

  `O* -> Human (five-section IR) -> SurfaceIntent -> Candidate -> DO -> Receipt -> Event`

  One test, one loop. The bus is an injected recording fake (the one allowed
  injection); the Ash resource is real and inline, and the loop must never
  invoke it: intent is not actuation.
  """

  use ExUnit.Case, async: false

  alias AshSurface.{Event, Observation}

  alias AshSurface.IntentRoundTripTest.{
    Dispatch,
    IntentIR,
    LedgerDomain,
    MilestoneLedger,
    Recorder,
    RecordingFakeBus,
    SurfaceIntent
  }

  setup do
    {:ok, _} = Recorder.start_link([])
    {:ok, bus} = RecordingFakeBus.start_link()

    on_exit(fn ->
      if pid = Process.whereis(Recorder), do: Agent.stop(pid)
    end)

    %{bus: bus}
  end

  test "O*->Human->Candidate->DO->Receipt->Event as one state loop", %{bus: bus} do
    # -- O*: authoritative state observation projection (real lib) ------------
    obs =
      Observation.create("zoe:Milestone#milestone_serve_43", %{
        "kingdom_need_id" => "need_zoela_78",
        "milestone_id" => "milestone_serve_43",
        "member_id" => "member_zoela_01"
      })

    assert obs.authority_boundary == :OBSERVE
    assert String.starts_with?(obs.observation_id, "obs_")

    # -- Human: hand-built IR with exactly the five canonical sections --------
    ir_sections = %{
      subject: %{
        observation_id: obs.observation_id,
        exact_subject: obs.exact_subject,
        state_digest: obs.state_digest
      },
      action: %{
        action_id: "AshSurface.IntentRoundTripTest.MilestoneLedger#record",
        semantic_id: "zoe:RecordMilestone"
      },
      input: %{
        member_id: "member_zoela_01",
        milestone_id: "milestone_serve_43",
        cost_physical: 10,
        reward_spiritual: 100
      },
      authority: %{boundary: :DO, do_authority: true, receipt_required: true},
      evidence: %{
        evidence_refs: [obs.observation_id],
        possible_refusals: ["REFUSED_NO_AUTHORITY", "UNKNOWN_AFTER_DISPATCH"]
      }
    }

    assert length(IntentIR.canonical_sections()) == 5
    assert {:ok, ir} = IntentIR.new(ir_sections)
    assert %IntentIR{} = ir
    assert ir.subject[:observation_id] == obs.observation_id
    assert ir.authority[:boundary] == :DO

    # -- SurfaceIntent.create / to_candidate (projected state) ----------------
    assert {:ok, intent} = SurfaceIntent.create(ir)
    assert intent.standing == :ADMITTED

    candidate = SurfaceIntent.to_candidate(intent)
    assert candidate.action_id == ir_sections.action[:action_id]
    assert candidate.semantic_id == "zoe:RecordMilestone"
    assert candidate.subject_ref == obs.exact_subject
    assert candidate.intent_ref == intent.intent_id
    assert candidate.authority_boundary == "DO"
    assert candidate.do_authority

    # -- DO: submit against the injected recording fake bus -------------------
    assert {:ok, receipt} = Dispatch.submit(candidate, bus)

    # -- the bus was called EXACTLY once with the EXACT candidate -------------
    assert [bus_call] = RecordingFakeBus.calls(bus)
    assert bus_call == candidate

    # -- Receipt: consequence is content-addressed off the exact candidate ----
    assert String.starts_with?(receipt.receipt_ref, "rcpt_")
    assert receipt.standing == :ALIVE
    assert receipt.dispatch_state == "completed"
    assert receipt.action_id == candidate.action_id
    assert receipt.subject_ref == obs.exact_subject
    assert receipt.candidate_digest != ""

    # -- Event back-projection (real lib): receipt_ref flows into the event ---
    event =
      Event.create(obs.exact_subject, 1, "state_transition",
        payload: %{
          "actionId" => candidate.action_id,
          "dispatchState" => receipt.dispatch_state,
          "candidateDigest" => receipt.candidate_digest
        },
        evidence_ref: obs.observation_id,
        receipt_ref: receipt.receipt_ref
      )

    assert event.receipt_ref == receipt.receipt_ref
    assert event.evidence_ref == obs.observation_id
    assert event.subject_ref == obs.exact_subject
    assert event.authority_boundary == :OBSERVE
    assert event.sequence == 1

    # -- The real Ash resource was NEVER invoked by the intent loop -----------
    assert Recorder.events() == []

    # -- Positive control: the recorder demonstrably detects a real invocation.
    #    The loop above is complete; this actuation happens only here, by hand,
    #    exactly as the doctrine demands (actuation != intent).
    assert {:ok, _record} =
             Ash.create(MilestoneLedger, ir_sections.input,
               action: :record,
               domain: LedgerDomain
             )

    assert Recorder.events() != []
  end
end
