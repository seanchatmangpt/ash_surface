defmodule AshSurface.Intent do
  @moduledoc """
  Human consequence EDGE as data: the SurfaceIntent projection.

  `AshSurface.Intent` is the SurfaceIntent: it records that a human aimed a
  surface action at a subject with some input — nothing more. It is the
  manufactured edge of the consequence graph,
  not its traversal: this module exports creation and inspection only. No
  `execute`/`submit`/`dispatch` path exists or will exist here; actuation requires
  an explicit cut and fresh operator-supplied authority through a brokered,
  receipt-bearing path (planning != actuation; candidate != authorized).

  The struct is exactly the addressed triple plus bookkeeping:

    * `surface_action_id` — the action identity the human aimed (from the
      surface projection's stable action namespace),
    * `input` — the action input map the human supplied,
    * `subject_ref` — the exact subject the consequence edge terminates at.
      Conventionally this addresses the canonical intermediate representation
      (`ir:<digest>`), whose local canonical shape — `ir.ex` is not yet admitted —
      is `IR{version, digest, ash, semantic, capability, presentation, schema}`
      with `ash`, `semantic`, `capability`, `presentation`, and `schema` as the
      five embedded structs,
    * `created_at` — when the edge was recorded (never part of its identity),
    * `intent_id` — `sha256` hex (lowercase) over the canonical JSON encoding of
      the ordered triple `[surface_action_id, input, subject_ref]`, so the id is
      deterministic and content-addressed: same triple, same id, any time.

  `created_at` is deliberately excluded from the digest: time is not identity.
  """

  @enforce_keys [:surface_action_id, :input, :subject_ref, :created_at, :intent_id]
  defstruct [:surface_action_id, :input, :subject_ref, :created_at, :intent_id]

  @type t :: %__MODULE__{
          surface_action_id: String.t(),
          input: map(),
          subject_ref: String.t(),
          created_at: DateTime.t(),
          intent_id: String.t()
        }

  @doc """
  Creates a new SurfaceIntent edge from the addressed triple.

  `intent_id` is a pure function of `(surface_action_id, input, subject_ref)`:
  the sha256 hex of their canonical JSON encoding. `opts` may override
  `:created_at` for replay/determinism; the override never changes the id.

  ## Examples

      iex> intent = AshSurface.Intent.create("Ticket#read", %{"id" => 1}, "ir:abc123", created_at: ~U[2026-09-17 06:30:00Z])
      iex> {intent.surface_action_id, intent.input, intent.subject_ref, intent.created_at}
      {"Ticket#read", %{"id" => 1}, "ir:abc123", ~U[2026-09-17 06:30:00Z]}
      iex> intent.intent_id
      "79f3ebbf01481d37a1451cb64c98a8af5df0b1cd0f5efb3cc6029fa71998b5a2"

      Time is not identity: a different `:created_at` replays the same id.

      iex> a = AshSurface.Intent.create("Ticket#read", %{"id" => 1}, "ir:abc123", created_at: ~U[2026-09-17 06:30:00Z])
      iex> b = AshSurface.Intent.create("Ticket#read", %{"id" => 1}, "ir:abc123", created_at: ~U[2020-01-01 00:00:00Z])
      iex> {a.intent_id == b.intent_id, a.intent_id}
      {true, "79f3ebbf01481d37a1451cb64c98a8af5df0b1cd0f5efb3cc6029fa71998b5a2"}
  """
  @spec create(String.t(), map(), String.t(), keyword()) :: t()
  def create(surface_action_id, input, subject_ref, opts \\ []) do
    created_at = Keyword.get(opts, :created_at, DateTime.utc_now())

    intent_id =
      [surface_action_id, input, subject_ref]
      |> Jason.encode!()
      |> sha256_hex()

    %__MODULE__{
      surface_action_id: surface_action_id,
      input: input,
      subject_ref: subject_ref,
      created_at: created_at,
      intent_id: intent_id
    }
  end

  @doc """
  Inspects the intent as a normalized JSON-ready map.

  This is a pure read of every field; it is the only other export besides
  `create/3`. There is no execution, submission, or dispatch path.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = intent) do
    %{
      "surfaceActionId" => intent.surface_action_id,
      "input" => intent.input,
      "subjectRef" => intent.subject_ref,
      "createdAt" => DateTime.to_iso8601(intent.created_at),
      "intentId" => intent.intent_id
    }
  end

  @spec sha256_hex(binary()) :: String.t()
  defp sha256_hex(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end
end
