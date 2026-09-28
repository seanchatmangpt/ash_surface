defmodule AshSurface.BoundaryHardeningTest do
  @moduledoc """
  Boundary-hardening pins: malformed inputs at the public boundaries return
  typed errors/refusals instead of raising, digest binding covers every slot
  that can become an event's `receipt_ref`, and the IR codec round-trips
  `false` leaves.

  State-based on the real modules (TESTING.md §2): no mocks, no env reads,
  no filesystem.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.CanonicalJSON
  alias AshSurface.IR.{Codec, EventProjection}

  @resource AshSurface.BoundaryHardeningTest.Thing
  @read_id "AshSurface.BoundaryHardeningTest.Thing#read"

  defp manifest do
    %Manifest{
      entrypoints: [
        %Entrypoint{resource: @resource, action: %Action{name: :read, type: :read, custom: %{}}}
      ]
    }
  end

  defp with_action_profile(action_profile) do
    AshSurface.from_manifest(manifest(), profile: %{"actions" => %{@read_id => action_profile}})
  end

  describe "from_manifest/2 refuses non-JSON profile data typed" do
    test "structs anywhere in the profile are refused, never enumerated" do
      at = ~U[2026-01-01 00:00:00Z]
      set = MapSet.new([1])

      assert {:error, {:profile_value_not_serializable, ^at}} =
               AshSurface.from_manifest(manifest(), profile: %{"at" => at})

      assert {:error, {:profile_value_not_serializable, ^set}} =
               AshSurface.from_manifest(manifest(), profile: %{"s" => set})

      assert {:error, {:profile_value_not_serializable, ^at}} =
               with_action_profile(%{"nested" => [%{"at" => at}]})
    end

    test "a non-map per-action profile is a typed error" do
      assert {:error, {:action_profile_must_be_a_map, @read_id, "x"}} =
               with_action_profile("x")

      assert {:error, {:action_profile_must_be_a_map, @read_id, [1]}} =
               with_action_profile([1])
    end

    test "evidenceRequired must be a boolean (Zod: z.boolean())" do
      for bad <- ["yes", 1, nil] do
        assert {:error, {:evidence_required_must_be_boolean, @read_id, ^bad}} =
                 with_action_profile(%{"evidenceRequired" => bad})
      end
    end

    test "possibleRefusals must be a list of strings (Zod: z.array(z.string()))" do
      for bad <- ["REFUSED_X", nil, [1], [:ok, 2], %{"a" => "REFUSED_X"}] do
        assert {:error, {:possible_refusals_must_be_strings, @read_id, _}} =
                 with_action_profile(%{"possibleRefusals" => bad})
      end
    end

    test "every declared refusal is a REFUSED_-prefixed code with a named reason (Zod: /^REFUSED_.+/)" do
      for bad <- ["AUTHORITY_REFUSED", "REFUSED", "REFUSED_", "UNKNOWN_AFTER_DISPATCH"] do
        assert {:error, {:possible_refusal_not_a_refusal_code, @read_id, ^bad}} =
                 with_action_profile(%{"possibleRefusals" => ["REFUSED_NO_AUTHORITY", bad]})
      end

      assert {:ok, _surface} =
               with_action_profile(%{
                 "possibleRefusals" => ["REFUSED_NO_AUTHORITY", "REFUSED_EVIDENCE_REQUIRED"]
               })
    end

    test "well-typed action profiles (string or atom spelled) are admitted into the contract" do
      assert {:ok, surface} =
               AshSurface.from_manifest(manifest(),
                 profile: %{
                   actions: %{
                     @read_id => %{
                       evidenceRequired: true,
                       possibleRefusals: [:REFUSED_NO_AUTHORITY]
                     }
                   }
                 }
               )

      assert [action] = surface.contract["surface"]["actions"]
      assert action["evidenceRequired"] == true
      assert action["possibleRefusals"] == ["REFUSED_NO_AUTHORITY"]

      assert {:ok, bare} = with_action_profile(%{})

      assert [%{"evidenceRequired" => false, "possibleRefusals" => []}] =
               bare.contract["surface"]["actions"]
    end
  end

  describe "EventProjection.from_receipt/2 binds every receipt_ref slot" do
    @payload %{
      "actionId" => "Helpdesk.Support.Ticket#open",
      "input" => %{"subject" => "hi"},
      "consequence" => %{"status" => "open"},
      "dispatchState" => "completed",
      "selectedTransport" => "http",
      "timestamp" => "2026-09-28T09:30:00Z"
    }

    defp minted, do: Map.put(@payload, "receiptHash", CanonicalJSON.sha256_hex(@payload))

    defp tampered(receipt),
      do: Map.update!(receipt, "consequence", &Map.put(&1, "status", "tampered"))

    test "a bound digest under receiptRef projects; tampered content under it refuses" do
      hash = CanonicalJSON.sha256_hex(@payload)
      moved = minted() |> Map.delete("receiptHash") |> Map.put("receiptRef", hash)

      assert {:ok, event} = EventProjection.from_receipt(moved)
      assert event.receipt_ref == hash

      assert {:error, refusal} = EventProjection.from_receipt(tampered(moved))
      assert refusal.standing == :REFUSED_RECEIPT_DIGEST_MISMATCH
      assert {:receipt_digest_mismatch, ^hash, actual} = refusal.reason
      assert actual != hash
      assert refusal.authority_boundary == :OBSERVE
    end

    test "a present-but-malformed digest is a refusal, not a skip" do
      hash = CanonicalJSON.sha256_hex(@payload)

      for slot <- ["receiptHash", "receiptRef"],
          bad <- [hash <> "0", hash <> "x", binary_part(hash, 0, 63), String.duplicate("ab", 20)] do
        receipt = @payload |> tampered() |> Map.put(slot, bad)

        assert {:error, refusal} = EventProjection.from_receipt(receipt),
               "#{slot}=#{inspect(bad)} must refuse"

        assert refusal == %{
                 standing: :REFUSED_RECEIPT_DIGEST_MISMATCH,
                 reason: {:malformed_receipt_digest, bad},
                 authority_boundary: :OBSERVE
               }
      end
    end

    test "an opaque receiptHash cannot shelter a tampered digest under receiptRef" do
      receipt =
        minted()
        |> tampered()
        |> Map.put("receiptRef", CanonicalJSON.sha256_hex(@payload))
        |> Map.put("receiptHash", "rcpt_opaque_1")

      assert {:error, %{standing: :REFUSED_RECEIPT_DIGEST_MISMATCH}} =
               EventProjection.from_receipt(receipt)
    end

    test "short opaque references are still carried verbatim" do
      for slot <- ["receiptHash", "receiptRef"] do
        assert {:ok, event} = EventProjection.from_receipt(Map.put(@payload, slot, "rcpt_42"))
        assert event.receipt_ref == "rcpt_42"
      end
    end
  end

  describe "EventProjection.from_receipt/2 refuses malformed IR actions typed" do
    test "a non-map semantic section is REFUSED_INVALID_SUBJECT" do
      for semantic <- ["iri:x", 1, ["zoe:x"]] do
        assert {:error, refusal} =
                 EventProjection.from_receipt(minted(), %{"semantic" => semantic})

        assert refusal == %{
                 standing: :REFUSED_INVALID_SUBJECT,
                 reason: {:malformed_ir_semantic, semantic},
                 authority_boundary: :OBSERVE
               }
      end
    end

    test "a non-map IR action is REFUSED_INVALID_SUBJECT" do
      assert {:error, refusal} = EventProjection.from_receipt(minted(), "Helpdesk#open")
      assert refusal.standing == :REFUSED_INVALID_SUBJECT
      assert refusal.reason == {:malformed_ir_action, "Helpdesk#open"}
    end

    test "nil semantic still falls back to resource#action" do
      assert {:ok, event} =
               EventProjection.from_receipt(minted(), %{
                 "semantic" => nil,
                 "resource" => "R",
                 "action" => "a"
               })

      assert event.subject_ref == "ash:R#a"
    end
  end

  describe "IR.Codec round-trips false leaves" do
    test "to_map(from_map(m)) == m with false field values" do
      map = %{
        "version" => "1",
        "ash" => nil,
        "semantic" => nil,
        "schema" => nil,
        "capability" => %{
          "authority_required" => false,
          "receipt_required" => true,
          "capability_id" => "cap:x",
          "consequence_class" => nil
        },
        "presentation" => %{
          "format" => false,
          "label" => "L",
          "group" => nil,
          "order" => 0,
          "widget" => false
        }
      }

      assert {:ok, ir} = Codec.from_map(map)
      assert ir.presentation.format == false
      assert ir.presentation.widget == false
      assert Codec.to_map(ir) == map
      assert ir.digest == Codec.digest(map)
    end
  end
end
