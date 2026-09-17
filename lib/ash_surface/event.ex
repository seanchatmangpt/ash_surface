defmodule AshSurface.Event do
  @moduledoc """
  Realtime Event Projection for Server -> Client observation stream.

  Used to stream state changes, receipts, obligation shifts, or presence observations
  across Phoenix Channels or WebSocket connections with explicit `authority_boundary: :OBSERVE`.
  """

  alias AshSurface.CanonicalJSON
  alias AshSurface.IR.EventProjection

  @enforce_keys [:event_id, :sequence, :subject_ref, :event_type, :state_digest]
  defstruct [
    :event_id,
    :sequence,
    :subject_ref,
    :event_type,
    :state_digest,
    :evidence_ref,
    :receipt_ref,
    :payload,
    occurred_at: nil,
    authority_boundary: :OBSERVE
  ]

  @type t :: %__MODULE__{
          event_id: String.t(),
          sequence: non_neg_integer(),
          subject_ref: String.t(),
          event_type: String.t(),
          state_digest: String.t(),
          evidence_ref: String.t() | nil,
          receipt_ref: String.t() | nil,
          payload: map() | nil,
          occurred_at: DateTime.t(),
          authority_boundary: :OBSERVE
        }

  @doc """
  Creates a new event projection.

  `subject_ref` and `event_type` are runtime-validated (F3): both must be
  non-empty binaries, since both are digest-bound identity inputs and wire
  fields mirrored by the zod `eventProjectionSchema` (`min(1)`). Anything
  else is refused with `ArgumentError`, never silently digested.
  """
  @spec create(String.t(), non_neg_integer(), String.t(), keyword()) :: t()
  def create(subject_ref, sequence, event_type, opts \\ []) do
    validate_identity_ref(subject_ref, "subject_ref")
    validate_identity_ref(event_type, "event_type")

    payload = Keyword.get(opts, :payload, %{})
    occurred_at = Keyword.get(opts, :occurred_at, DateTime.utc_now())
    evidence_ref = Keyword.get(opts, :evidence_ref)
    receipt_ref = Keyword.get(opts, :receipt_ref)

    # Canonical (key-sorted) JSON: event identity is invariant under payload
    # map construction history, flatmap or >32-key HAMT alike.
    digest =
      :crypto.hash(
        :sha256,
        "#{subject_ref}:#{sequence}:#{event_type}:#{CanonicalJSON.encode(payload)}"
      )
      |> Base.encode16(case: :lower)

    event_id = "ev_#{binary_part(digest, 0, 16)}"

    %__MODULE__{
      event_id: event_id,
      sequence: sequence,
      subject_ref: subject_ref,
      event_type: event_type,
      state_digest: digest,
      evidence_ref: evidence_ref,
      receipt_ref: receipt_ref,
      payload: payload,
      occurred_at: occurred_at,
      authority_boundary: :OBSERVE
    }
  end

  @doc "Serializes the event projection to a JSON map."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = ev) do
    %{
      "eventId" => ev.event_id,
      "sequence" => ev.sequence,
      "subjectRef" => ev.subject_ref,
      "eventType" => ev.event_type,
      "stateDigest" => ev.state_digest,
      "evidenceRef" => ev.evidence_ref,
      "receiptRef" => ev.receipt_ref,
      "payload" => ev.payload,
      "occurredAt" => DateTime.to_iso8601(ev.occurred_at),
      "authorityBoundary" => "OBSERVE"
    }
  end

  @doc """
  The production route for runtime receipts onto the observation stream.

  Every runtime-produced consequence receipt (the JSON receipt emitted by the
  consumer runtime) is back-projected through
  `AshSurface.IR.EventProjection.from_receipt/2` — the one lawful path from a
  receipt to an `AshSurface.Event`. There is no other admitted route; callers
  must never hand-roll an event from receipt sections.

  Returns `{:ok, event}` on success, or `{:error, refusal}` typed by the
  projection (e.g. a receipt carrying no parseable timestamp refuses instead
  of inventing one — replay equality is preserved by construction).
  """
  @spec from_receipt(map(), map() | nil) :: {:ok, t()} | {:error, EventProjection.refusal()}
  def from_receipt(receipt, ir_action \\ nil) when is_map(receipt) do
    EventProjection.from_receipt(receipt, ir_action)

 defp validate_identity_ref(ref, _name) when is_binary(ref) and ref != "", do: :ok

  defp validate_identity_ref(ref, name) do
    raise ArgumentError,
          "Event.create/4 requires a non-empty binary #{name}, got: #{inspect(ref)}"
  end
end
