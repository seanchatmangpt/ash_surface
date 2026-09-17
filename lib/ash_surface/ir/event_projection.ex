defmodule AshSurface.IR.EventProjection do
  @moduledoc """
  Consequence -> observation back-projection: `from_receipt/2` turns a
  brokered DO-consequence receipt (the JSON receipt emitted by the consumer
  runtime, see `test/js/consumer_e2e_runner.mjs`) into an
  `AshSurface.Event{}` on the server -> client observation stream.

  The projection is a lossy observation of a consequence, never a re-actuation:
  the event is created through `AshSurface.Event.create/4`, which pins
  `authority_boundary: :OBSERVE` structurally. Even receipts that carry DO
  authority (`doAuthority`, `authorityBoundary: "DO"`) back-project to an
  OBSERVE-only event; authority cannot be widened through this path.

  ## Canonical IR action shape

  The declared action shape stays local by design: it is the JSON-decoded
  receipt shape, not the `%AshSurface.IR{}` five-section struct carrier
  (`lib/ash_surface/ir.ex`), so there is no owner module for it to move into.
  Atom and string keys are both accepted (receipts arrive JSON-decoded):

      %{
        "resource" => "AshSurface.Fixtures.VolunteerMilestone",
        "action" => "record",
        "semantic" => %{"subject_iri" => "zoe:KingdomNeed#need_42"}
      }

  `subject_ref` resolution order:

  1. `semantic.subject_iri` on the IR action, when present and non-blank.
  2. `ash:<resource>#<action>` from the IR action (the manifest semanticId
     fallback convention, e.g. `"ash:AshSurfaceTest.Post#create"`).
  3. `ash:<actionId>` from the receipt itself (`actionId` already carries
     `<resource>#<action>`).

  ## Typed refusal, never invented fields (finish-replay-020)

  The projection never invents receipt content. Since finish-replay-020 the
  function returns a typed result:

    * `{:ok, event}` — every section resolved;
    * `{:error, refusal}` with `standing: :REFUSED_MISSING_TIMESTAMP` when the
      receipt carries no parseable `timestamp`/`occurredAt` — the previous
      `DateTime.utc_now()` fallback made timestamp-less receipts replay to
      DIFFERENT observations, so it is now a typed refusal;
    * `{:error, refusal}` with `standing: :REFUSED_INVALID_SUBJECT` when no
      `subject_ref` can be resolved from any of the three sources above;
    * `{:error, refusal}` with `standing: :REFUSED_RECEIPT_DIGEST_MISMATCH`
      (chicago-replay-state-028) when the receipt carries a runtime-minted
      `receiptHash` (64 bytes, the exact byte length of the sha256 hex the
      consumer runtime mints) that does NOT bind the canonical re-encoding of
      its covered sections (`actionId`, `input`, `consequence`,
      `dispatchState`, `selectedTransport`, `timestamp` — the same section
      set the JS runtime hashes in `test/js/consumer_e2e_runner.mjs`). A
      receipt whose own binding evidence contradicts its content never
      reaches the observation stream. A carried value outside that byte
      shape (or no digest at all) is an opaque `receipt_ref`, carried
      verbatim as before.

  Refusal ordering is part of the law: subject, then timestamp, then digest
  binding — a receipt refusing on identity or time never reaches the digest
  check, and a tampered digest on a time-intact receipt refuses on the digest.

  A refusal is a plain map `%{standing: atom, reason: term, authority_boundary: :OBSERVE}`
  (the runtime-minted refusal shape, cf. `AshSurface.Health`). The production
  route for runtime receipts is `AshSurface.Event.from_receipt/2`.
  """

  alias AshSurface.CanonicalJSON
  alias AshSurface.Event

  @typedoc "Local declaration of the canonical IR action shape (see moduledoc)."
  @type ir_action :: %{
          optional(:resource) => String.t(),
          optional(:action) => String.t(),
          optional(:semantic) => semantic(),
          # JSON-decoded receipts/actions arrive with string keys; every key
          # above is read through both spellings (see `fetch/2`).
          optional(String.t()) => term()
        }

  @typep semantic :: %{
           optional(:subject_iri) => String.t() | nil,
           optional(String.t()) => term()
         }

  @typedoc "Typed refusal (runtime-minted shape, cf. `AshSurface.Health`)."
  @type refusal :: %{
          required(:standing) => atom(),
          required(:reason) => term(),
          required(:authority_boundary) => :OBSERVE
        }

  @typep receipt :: map()

  @event_type "state_transition"

  @doc """
  Back-projects a consequence receipt into an OBSERVE-only `AshSurface.Event`.

  The receipt sections are reused verbatim per the existing Event law:
  `consequence` becomes the payload, `receiptHash` the `receipt_ref`,
  `timestamp` the `occurred_at`, and `sequence` (when the receipt carries
  one) is carried verbatim instead of being invented here.

  Returns `{:ok, event}`, or `{:error, refusal}` when the receipt carries no
  resolvable subject (`:REFUSED_INVALID_SUBJECT`), no parseable timestamp
  (`:REFUSED_MISSING_TIMESTAMP`), or a runtime-minted `receiptHash` that does
  not bind its covered sections (`:REFUSED_RECEIPT_DIGEST_MISMATCH`) — a
  receipt missing identity or time does not replay to identical bytes, and a
  receipt contradicting its own digest is never projected as an observation.
  """
  @spec from_receipt(receipt(), ir_action() | nil) :: {:ok, Event.t()} | {:error, refusal()}
  def from_receipt(receipt, ir_action \\ nil) when is_map(receipt) do
    with {:ok, subject} <- subject_ref(receipt, ir_action),
         {:ok, occurred} <- occurred_at(receipt),
         :ok <- bind_receipt_digest(receipt) do
      {:ok,
       Event.create(
         subject,
         sequence(receipt),
         @event_type,
         payload: fetch(receipt, [:consequence, "consequence"]) || %{},
         receipt_ref: fetch(receipt, [:receipt_hash, "receiptHash", :receipt_ref, "receiptRef"]),
         occurred_at: occurred
       )}
    end
  end

  ## Subject resolution: IR semantic subject_iri first, ash:<resource>#<action> fallback.

  defp subject_ref(receipt, ir_action) do
    semantic = fetch(ir_action || %{}, [:semantic, "semantic"]) || %{}

    case fetch(semantic, [:subject_iri, "subject_iri"]) do
      iri when is_binary(iri) and iri != "" ->
        {:ok, iri}

      _ ->
        case {fetch(ir_action || %{}, [:resource, "resource"]),
              fetch(ir_action || %{}, [:action, "action"])} do
          {resource, action} when is_binary(resource) and is_binary(action) ->
            {:ok, "ash:" <> resource <> "#" <> action}

          _ ->
            case fetch(receipt, [:action_id, "actionId"]) do
              action_id when is_binary(action_id) ->
                {:ok, "ash:" <> action_id}

              _ ->
                {:error,
                 %{
                   standing: :REFUSED_INVALID_SUBJECT,
                   reason: :unresolvable_subject_ref,
                   authority_boundary: :OBSERVE
                 }}
            end
        end
    end
  end

  defp sequence(receipt) do
    case fetch(receipt, [:sequence, "sequence"]) do
      seq when is_integer(seq) and seq >= 0 -> seq
      _ -> 0
    end
  end

  ## Typed refusal on missing/unparseable time: never invent wall-clock into a replayed fact.

  defp occurred_at(receipt) do
    case fetch(receipt, [:timestamp, "timestamp", :occurred_at, "occurredAt"]) do
      ts when is_binary(ts) ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _offset} ->
            {:ok, dt}

          _ ->
            {:error, missing_timestamp_refusal(ts)}
        end

      %DateTime{} = dt ->
        {:ok, dt}

      other ->
        {:error, missing_timestamp_refusal(other)}
    end
  end

  defp missing_timestamp_refusal(raw) do
    %{
      standing: :REFUSED_MISSING_TIMESTAMP,
      reason: {:no_parseable_receipt_timestamp, raw},
      authority_boundary: :OBSERVE
    }
  end

  ## Receipt-digest binding (chicago-replay-state-028): a receipt that claims
  ## the runtime-minted digest shape (64 bytes — the exact byte length of the
  ## sha256 hex the consumer runtime emits for `receiptHash`) must BIND the
  ## canonical re-encoding of its covered sections, or it is refused typed.
  ## Anything else in the slot (absent, or an opaque reference like a domain
  ## id) is carried verbatim as the event's `receipt_ref`, exactly as before.

  defp bind_receipt_digest(receipt) do
    case fetch(receipt, [:receipt_hash, "receiptHash"]) do
      hash when is_binary(hash) and byte_size(hash) == 64 ->
        actual = CanonicalJSON.sha256_hex(digest_payload(receipt))

        if actual == hash do
          :ok
        else
          {:error,
           %{
             standing: :REFUSED_RECEIPT_DIGEST_MISMATCH,
             reason: {:receipt_digest_mismatch, hash, actual},
             authority_boundary: :OBSERVE
           }}
        end

      _opaque_or_absent ->
        :ok
    end
  end

  ## The exact section set the consumer runtime covers when minting
  ## `receiptHash` (test/js/consumer_e2e_runner.mjs `receiptPayload`), read
  ## through both key spellings so atom-keyed receipts bind identically.

  defp digest_payload(receipt) do
    %{
      "actionId" => fetch(receipt, [:action_id, "actionId"]),
      "input" => fetch(receipt, [:input, "input"]),
      "consequence" => fetch(receipt, [:consequence, "consequence"]),
      "dispatchState" => fetch(receipt, [:dispatch_state, "dispatchState"]),
      "selectedTransport" => fetch(receipt, [:selected_transport, "selectedTransport"]),
      "timestamp" => fetch(receipt, [:timestamp, "timestamp", :occurred_at, "occurredAt"])
    }
  end

  ## Zero-config key access: atom or string keys, JSON-decoded or literal maps.

  defp fetch(map, keys) when is_map(map) do
    Enum.find_value(keys, fn key ->
      case Map.fetch(map, key) do
        {:ok, value} -> value
        :error -> nil
      end
    end)
  end
end
