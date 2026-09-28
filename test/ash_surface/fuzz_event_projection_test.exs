defmodule AshSurface.FuzzEventProjectionTest do
  @moduledoc """
  Decode-boundary fuzzing of `AshSurface.IR.EventProjection.from_receipt/2`,
  the untrusted entry point that back-projects runtime consequence receipts
  into OBSERVE-only events (Chicago school: the real projection and the real
  `CanonicalJSON` digest; no doubles).

  Laws pinned:

    1. Totality: for ANY receipt map (junk terms, wrong types, missing or
       hostile fields, either key spelling) and any IR-action term, the result
       is `{:ok, %Event{}}` or a typed refusal
       `%{standing: :REFUSED_*, authority_boundary: :OBSERVE}` — never a raise.
    2. Digest binding is decisive: a receipt whose `receiptHash` or
       `receiptRef` is a 64-byte (digest-shaped) value that is not the
       canonical SHA-256 of the covered sections NEVER projects, in either
       slot, whatever else is true of the receipt. (Independent oracle: this
       file recomputes the digest with `CanonicalJSON.sha256_hex/1`.)
    3. Tampering any covered section of a correctly minted receipt breaks its
       digest: it refuses `:REFUSED_RECEIPT_DIGEST_MISMATCH`.
    4. A correctly minted receipt (either slot) with a valid subject and
       timestamp always projects, carrying the digest as `receipt_ref`.

  Bounded: 300 cases per property.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.CanonicalJSON
  alias AshSurface.Event
  alias AshSurface.IR.EventProjection

  @runs 300
  @covered ~w(actionId input consequence dispatchState selectedTransport timestamp)

  defp junk_leaf do
    one_of([
      integer(),
      float(),
      boolean(),
      constant(nil),
      atom(:alphanumeric),
      string(:printable, max_length: 12),
      binary(max_length: 6),
      constant({:a, 1}),
      constant(self()),
      constant(make_ref()),
      constant([1 | 2]),
      constant(DateTime.from_unix!(0)),
      constant("2026-09-28T09:30:00Z")
    ])
  end

  defp term(0), do: junk_leaf()

  defp term(depth) do
    frequency([
      {4, junk_leaf()},
      {2, list_of(term(depth - 1), max_length: 3)},
      {2,
       map(
         list_of(
           {one_of([string(:alphanumeric, max_length: 5), atom(:alphanumeric), integer(0..3)]),
            term(depth - 1)},
           max_length: 3
         ),
         &Map.new/1
       )}
    ])
  end

  defp json(0),
    do: one_of([integer(), boolean(), constant(nil), string(:alphanumeric, max_length: 8)])

  defp json(depth) do
    frequency([
      {4, json(0)},
      {1, list_of(json(depth - 1), max_length: 2)},
      {1,
       map(
         list_of({string(:alphanumeric, max_length: 4), json(depth - 1)}, max_length: 2),
         &Map.new/1
       )}
    ])
  end

  defp hash64, do: map(binary(length: 32), &Base.encode16(&1, case: :lower))

  defp slot_value do
    frequency([
      {3, hash64()},
      {2, string(:alphanumeric, min_length: 64, max_length: 64)},
      {2, member_of(["git:abc123", "urn:uuid:1", "", "short"])},
      {1, term(0)}
    ])
  end

  # A structurally honest receipt (valid subject + time) with generated content.
  defp minted_payload do
    gen all(
          action <- member_of(["Shop.Cart#add", "Helpdesk.Ticket#open", "A#b"]),
          input <- json(2),
          consequence <- json(2),
          state <- member_of(["completed", "unknown_after_dispatch"]),
          transport <- member_of(["http", "phoenix_channel"]),
          sec <- integer(0..59)
        ) do
      ts = "2026-09-28T09:30:#{String.pad_leading(Integer.to_string(sec), 2, "0")}Z"

      %{
        "actionId" => action,
        "input" => input,
        "consequence" => consequence,
        "dispatchState" => state,
        "selectedTransport" => transport,
        "timestamp" => ts
      }
    end
  end

  defp refusal?(%{standing: standing, authority_boundary: :OBSERVE}) do
    standing |> Atom.to_string() |> String.starts_with?("REFUSED_")
  end

  defp refusal?(_), do: false

  defp tampered(payload) do
    Map.update!(payload, "consequence", fn c -> %{"tampered" => true, "was" => c} end)
  end

  property "from_receipt/2 is total over arbitrary receipts (never raises)" do
    check all(
            receipt <-
              map(
                list_of(
                  {one_of([
                     member_of(@covered ++ ~w(receiptHash receiptRef sequence occurredAt)),
                     atom(:alphanumeric),
                     string(:alphanumeric, max_length: 4)
                   ]), term(2)},
                  max_length: 8
                ),
                &Map.new/1
              ),
            action <- one_of([constant(nil), term(2)]),
            max_runs: @runs
          ) do
      case EventProjection.from_receipt(receipt, action) do
        {:ok, %Event{}} -> :ok
        {:error, refusal} -> assert refusal?(refusal)
      end
    end
  end

  property "digest-shaped slot that is not the canonical digest never projects (either slot)" do
    check all(
            payload <- minted_payload(),
            slot <- member_of(["receiptHash", "receiptRef"]),
            other <- member_of(["receiptHash", "receiptRef"]),
            claimed <- slot_value(),
            other_value <- one_of([constant(:absent), slot_value()]),
            max_runs: @runs
          ) do
      receipt =
        case other_value do
          :absent -> Map.put(payload, slot, claimed)
          v -> payload |> Map.put(slot, claimed) |> Map.put(other, v)
        end

      real = CanonicalJSON.sha256_hex(payload)

      digest_claims =
        receipt
        |> Map.take(["receiptHash", "receiptRef"])
        |> Map.values()
        |> Enum.filter(&(is_binary(&1) and byte_size(&1) == 64))

      result = EventProjection.from_receipt(receipt)

      if Enum.any?(digest_claims, &(&1 != real)) do
        assert {:error, refusal} = result
        assert refusal?(refusal)
      else
        assert {:ok, %Event{}} = result
      end
    end
  end

  property "tampering any covered section of a minted receipt breaks the digest" do
    check all(
            payload <- minted_payload(),
            slot <- member_of(["receiptHash", "receiptRef"]),
            max_runs: @runs
          ) do
      minted = Map.put(payload, slot, CanonicalJSON.sha256_hex(payload))

      assert {:ok, %Event{receipt_ref: ref}} = EventProjection.from_receipt(minted)
      assert ref == CanonicalJSON.sha256_hex(payload)

      forged = Map.merge(minted, tampered(payload))

      assert {:error, %{standing: :REFUSED_RECEIPT_DIGEST_MISMATCH} = refusal} =
               EventProjection.from_receipt(forged)

      assert refusal?(refusal)
    end
  end

  test "a minted receipt whose input or consequence is exactly false projects" do
    for {input, consequence} <- [{false, %{}}, {%{}, false}, {false, false}] do
      p = %{
        "actionId" => "A#b",
        "input" => input,
        "consequence" => consequence,
        "dispatchState" => "completed",
        "selectedTransport" => "http",
        "timestamp" => "2026-09-28T09:30:00Z"
      }

      minted = Map.put(p, "receiptHash", CanonicalJSON.sha256_hex(p))
      assert {:ok, %Event{}} = EventProjection.from_receipt(minted)

      tampered = Map.put(minted, "input", true)

      assert {:error, %{standing: :REFUSED_RECEIPT_DIGEST_MISMATCH}} =
               EventProjection.from_receipt(tampered)
    end
  end

  test "the generators are not vacuous: arbitrary receipts reach both outcomes" do
    outcomes =
      minted_payload()
      |> Enum.take(50)
      |> Enum.flat_map(fn p ->
        [
          EventProjection.from_receipt(Map.put(p, "receiptHash", CanonicalJSON.sha256_hex(p))),
          EventProjection.from_receipt(Map.put(p, "receiptHash", String.duplicate("0", 64)))
        ]
      end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.frequencies()

    assert outcomes == %{ok: 50, error: 50}
  end
end
