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
  """

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

  @typep receipt :: map()

  @event_type "state_transition"

  @doc """
  Back-projects a consequence receipt into an OBSERVE-only `AshSurface.Event`.

  The receipt sections are reused verbatim per the existing Event law:
  `consequence` becomes the payload, `receiptHash` the `receipt_ref`,
  `timestamp` the `occurred_at`, and `sequence` (when the receipt carries
  one) is carried verbatim instead of being invented here.
  """
  @spec from_receipt(receipt(), ir_action() | nil) :: Event.t()
  def from_receipt(receipt, ir_action \\ nil) when is_map(receipt) do
    Event.create(
      subject_ref(receipt, ir_action),
      sequence(receipt),
      @event_type,
      payload: fetch(receipt, [:consequence, "consequence"]) || %{},
      receipt_ref: fetch(receipt, [:receipt_hash, "receiptHash", :receipt_ref, "receiptRef"]),
      occurred_at: occurred_at(receipt)
    )
  end

  ## Subject resolution: IR semantic subject_iri first, ash:<resource>#<action> fallback.

  defp subject_ref(receipt, ir_action) do
    semantic = fetch(ir_action || %{}, [:semantic, "semantic"]) || %{}

    case fetch(semantic, [:subject_iri, "subject_iri"]) do
      iri when is_binary(iri) and iri != "" ->
        iri

      _ ->
        case {fetch(ir_action || %{}, [:resource, "resource"]),
              fetch(ir_action || %{}, [:action, "action"])} do
          {resource, action} when is_binary(resource) and is_binary(action) ->
            "ash:" <> resource <> "#" <> action

          _ ->
            case fetch(receipt, [:action_id, "actionId"]) do
              action_id when is_binary(action_id) ->
                "ash:" <> action_id

              _ ->
                raise ArgumentError,
                      "from_receipt/2 cannot resolve a subject_ref: no subject_iri, resource/action, or actionId"
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

  defp occurred_at(receipt) do
    case fetch(receipt, [:timestamp, "timestamp", :occurred_at, "occurredAt"]) do
      ts when is_binary(ts) ->
        case DateTime.from_iso8601(ts) do
          {:ok, dt, _offset} -> dt
          _ -> DateTime.utc_now()
        end

      %DateTime{} = dt ->
        dt

      _ ->
        DateTime.utc_now()
    end
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
