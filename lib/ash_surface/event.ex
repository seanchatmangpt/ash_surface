defmodule AshSurface.Event do
  @moduledoc """
  Realtime Event Projection for Server -> Client observation stream.

  Used to stream state changes, receipts, obligation shifts, or presence observations
  across Phoenix Channels or WebSocket connections with explicit `authority_boundary: :OBSERVE`.
  """

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

  @doc "Creates a new event projection."
  @spec create(String.t(), non_neg_integer(), String.t(), keyword()) :: t()
  def create(subject_ref, sequence, event_type, opts \\ []) do
    payload = Keyword.get(opts, :payload, %{})
    occurred_at = Keyword.get(opts, :occurred_at, DateTime.utc_now())
    evidence_ref = Keyword.get(opts, :evidence_ref)
    receipt_ref = Keyword.get(opts, :receipt_ref)

    digest =
      :crypto.hash(:sha256, "#{subject_ref}:#{sequence}:#{event_type}:#{Jason.encode!(payload)}")
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
end
