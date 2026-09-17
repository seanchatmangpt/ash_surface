defmodule AshSurface.EventReplayStateTest do
  @moduledoc """
  chicago-replay-state-028 — Chicago-school replay STATE TABLE over REAL
  runtime receipts.

  Receipts are minted by the real node runtime (`priv/static/
  ash_surface_runtime.mjs`) over live HTTP against the real fixture Ash data
  layer (the consumer_fixture pattern), then each table row drives the
  receipt into an explicit state and replays it TWICE through the production
  route `AshSurface.Event.from_receipt/2` — never through any other path.

  Observable outcomes only:

    * OK rows assert the replay pair yields identical structs, identical wire
      forms, and identical digests (`state_digest` + `event_id`), plus the
      row's own law — never mock/bookkeeping internals;
    * refusal rows assert the EXACT typed refusal struct, identically on
      both replays (the projection invents nothing, including refusals);
    * the falsifier row perturbs ONE covered receipt field and shows the
      outcome flip ok -> typed refusal -> ok on lawful re-mint, without ever
      touching the subject module (the subject-level RED/GREEN falsifier is
      executed and recorded in the ticket History).

  No test doubles: the unit under test is the real `AshSurface.Event` /
  `AshSurface.IR.EventProjection` code path; the only injected seam is the
  live HTTP port, which the transport law itself demands.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Event
  alias AshSurface.Fixtures.{Server, VolunteerMilestone}

  @repo_root Path.expand("../..", __DIR__)
  @tmp_dir Path.join(@repo_root, "_build/test/event_replay_state")
  @runtime_url "file://" <> Path.expand("../../priv/static/ash_surface_runtime.mjs", __DIR__)
  @action_id "AshSurface.Fixtures.VolunteerMilestone#record"

  # The exact section set the consumer runtime covers when minting
  # `receiptHash` (test/js/consumer_e2e_runner.mjs `receiptPayload`).
  @digest_keys [
    "actionId",
    "input",
    "consequence",
    "dispatchState",
    "selectedTransport",
    "timestamp"
  ]

  @ir_action %{
    "resource" => "AshSurface.Fixtures.VolunteerMilestone",
    "action" => "record",
    "semantic" => %{"subject_iri" => "zoe:KingdomNeed#need_state_table"}
  }

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    # The Ash ETS data layer is shared across the run; observe only this
    # suite's own consequences (consumer_fixture pattern).
    if :ets.whereis(VolunteerMilestone) != :undefined do
      :ets.delete_all_objects(VolunteerMilestone)
    end

    {:ok, server_pid} = Server.start_link()
    port = Server.get_port(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Server.stop(server_pid)
    end)

    {:ok, port: port}
  end

  test "OK rows: every receipt state replays twice to identical structs, wire forms, and digests",
       %{port: port} do
    pristine = mint_receipt!(port, "member_state_ok_01", "ok")

    # Row premise: the pristine runtime receipt projects through the
    # production route with every section landing verbatim.
    assert {:ok, base} = Event.from_receipt(pristine, @ir_action)
    assert base.subject_ref == "zoe:KingdomNeed#need_state_table"
    assert base.payload == pristine["consequence"]
    assert base.receipt_ref == pristine["receiptHash"]
    assert {:ok, ts, 0} = DateTime.from_iso8601(pristine["timestamp"])
    assert base.occurred_at == ts
    assert base.event_type == "state_transition"

    rebind = fn receipt ->
      Map.put(
        receipt,
        "receiptHash",
        AshSurface.CanonicalJSON.sha256_hex(Map.take(receipt, @digest_keys))
      )
    end

    permuted_consequence = fn receipt ->
      Map.update!(receipt, "consequence", fn c ->
        c |> Map.to_list() |> Enum.reverse() |> Map.new()
      end)
    end

    atom_transcript = fn receipt ->
      %{
        action_id: receipt["actionId"],
        input: receipt["input"],
        consequence: receipt["consequence"],
        dispatch_state: receipt["dispatchState"],
        selected_transport: receipt["selectedTransport"],
        timestamp: receipt["timestamp"],
        receipt_hash: receipt["receiptHash"]
      }
    end

    ok_rows = [
      # The receipt exactly as the runtime minted it: identity row.
      {:pristine, & &1, fn ev, base -> assert ev == base end},
      # A receipt-carried sequence is carried verbatim, never invented.
      {:carried_sequence, &Map.put(&1, "sequence", 7),
       fn ev, base ->
         assert ev.sequence == 7
         assert ev.event_id != base.event_id
         assert ev.state_digest != base.state_digest
       end},
      # DO-marked receipt content cannot widen the observation boundary.
      {:do_authority_smuggle,
       &Map.merge(&1, %{"authorityBoundary" => "DO", "doAuthority" => true}),
       fn ev, _base ->
         assert ev.authority_boundary == :OBSERVE
         assert Event.to_map(ev)["authorityBoundary"] == "OBSERVE"
       end},
      # UNKNOWN after dispatch, lawfully re-minted: still a real observation.
      {:unknown_after_dispatch_rebound,
       fn receipt ->
         receipt |> Map.put("dispatchState", "unknown_after_dispatch") |> rebind.()
       end,
       fn ev, base ->
         # dispatchState is not an observation-identity input: the event
         # digest is unchanged even though the receipt (and its binding
         # digest) differ.
         assert ev.state_digest == base.state_digest
         assert ev.receipt_ref != base.receipt_ref
       end},
      # Consequence map rebuilt in reverse construction order + re-minted
      # digest: canonical bytes are identical, so the re-mint reproduces the
      # ORIGINAL receiptHash and the ORIGINAL event, byte for byte.
      {:permuted_consequence, &(&1 |> permuted_consequence.() |> rebind.()),
       fn ev, base -> assert ev == base end},
      # The same receipt transcribed to atom keys projects to the SAME event:
      # key spelling never leaks into the observation.
      {:atom_keyed_transcript, atom_transcript, fn ev, base -> assert ev == base end},
      # A real consequence change, lawfully re-minted: new observation
      # identity (contrast with the tampered-digest refusal row below).
      {:rebound_consequence,
       fn receipt ->
         receipt
         |> Map.update!("consequence", &Map.put(&1, "status", "rolled_back"))
         |> rebind.()
       end,
       fn ev, base ->
         assert ev.payload["status"] == "rolled_back"
         assert ev.event_id != base.event_id
         assert ev.state_digest != base.state_digest
       end}
    ]

    for {row_name, mutate, checks} <- ok_rows do
      receipt = mutate.(pristine)

      assert {:ok, first} = Event.from_receipt(receipt, @ir_action),
             "row #{row_name}: first replay must project"

      assert {:ok, second} = Event.from_receipt(receipt, @ir_action),
             "row #{row_name}: second replay must project"

      # Replay pair: identical struct, wire form, and digests.
      assert first == second, "row #{row_name}: replayed structs diverge"
      assert Event.to_map(first) == Event.to_map(second), "row #{row_name}: wire forms diverge"
      assert first.state_digest == second.state_digest, "row #{row_name}: digests diverge"
      assert first.event_id == second.event_id, "row #{row_name}: identities diverge"

      # Universal observation law on every OK row.
      assert first.authority_boundary == :OBSERVE

      checks.(first, base)
    end
  end

  test "refusal rows: tampered digest, missing timestamp, unparseable timestamp, and foreign subject each assert the exact typed refusal",
       %{port: port} do
    pristine = mint_receipt!(port, "member_state_refusal_01", "refusal")

    tampered_hash = String.duplicate("ab", 32)

    # No IR action at all: subject must come from the receipt's actionId, or
    # (foreign-subject row) from nowhere at all.
    refusal_rows = [
      {:tampered_digest, Map.put(pristine, "receiptHash", tampered_hash),
       %{
         standing: :REFUSED_RECEIPT_DIGEST_MISMATCH,
         reason:
           {:receipt_digest_mismatch, tampered_hash,
            AshSurface.CanonicalJSON.sha256_hex(Map.take(pristine, @digest_keys))},
         authority_boundary: :OBSERVE
       }},
      {:missing_timestamp, Map.delete(pristine, "timestamp"),
       %{
         standing: :REFUSED_MISSING_TIMESTAMP,
         reason: {:no_parseable_receipt_timestamp, nil},
         authority_boundary: :OBSERVE
       }},
      {:unparseable_timestamp, Map.put(pristine, "timestamp", "not-a-timestamp"),
       %{
         standing: :REFUSED_MISSING_TIMESTAMP,
         reason: {:no_parseable_receipt_timestamp, "not-a-timestamp"},
         authority_boundary: :OBSERVE
       }},
      {:foreign_subject, Map.delete(pristine, "actionId"),
       %{
         standing: :REFUSED_INVALID_SUBJECT,
         reason: :unresolvable_subject_ref,
         authority_boundary: :OBSERVE
       }}
    ]

    for {row_name, receipt, expected_refusal} <- refusal_rows do
      assert {:error, first} = Event.from_receipt(receipt, %{}),
             "row #{row_name}: must refuse typed"

      assert {:error, second} = Event.from_receipt(receipt, %{}),
             "row #{row_name}: second replay must refuse identically"

      assert first == expected_refusal,
             "row #{row_name}: refusal is #{inspect(first)}, expected #{inspect(expected_refusal)}"

      assert first == second, "row #{row_name}: refusals diverge across replay"
      assert first.authority_boundary == :OBSERVE
    end
  end

  test "falsifier row: perturbing ONE covered receipt field flips ok -> typed refusal; lawful re-mint flips it back",
       %{port: port} do
    pristine = mint_receipt!(port, "member_state_flip_01", "flip")

    # Before perturbation: the pristine receipt projects to a real event.
    assert {:ok, before} = Event.from_receipt(pristine, @ir_action)

    # Perturb ONE covered field (the consequence status) leaving the minted
    # digest untouched: the receipt no longer binds its own content, so the
    # observation refuses typed instead of projecting the tampered state.
    perturbed =
      Map.update!(pristine, "consequence", &Map.put(&1, "status", "tampered_in_transit"))

    assert {:error, refusal} = Event.from_receipt(perturbed, @ir_action)

    minted_hash = pristine["receiptHash"]

    assert %{
             standing: :REFUSED_RECEIPT_DIGEST_MISMATCH,
             reason: {:receipt_digest_mismatch, ^minted_hash, actual},
             authority_boundary: :OBSERVE
           } = refusal

    assert actual != minted_hash
    assert byte_size(actual) == 64

    # The refusal itself replays identically: no invented passing observation.
    assert {:error, refusal_again} = Event.from_receipt(perturbed, @ir_action)
    assert refusal_again == refusal

    # Lawful re-mint over the perturbed state flips the outcome back to ok,
    # with a NEW observation identity: the state change is real, the binding
    # is honest.
    rebound =
      Map.put(
        perturbed,
        "receiptHash",
        AshSurface.CanonicalJSON.sha256_hex(Map.take(perturbed, @digest_keys))
      )

    assert {:ok, after_rebind} = Event.from_receipt(rebound, @ir_action)
    assert after_rebind.payload["status"] == "tampered_in_transit"
    assert after_rebind.state_digest != before.state_digest
    assert after_rebind.event_id != before.event_id
    assert Event.to_map(after_rebind)["authorityBoundary"] == "OBSERVE"
  end

  # ---------------------------------------------------------------------------
  # Receipt minting: the real node runtime over live HTTP (consumer_fixture
  # pattern), writing the JSON receipt to disk for the Elixir-side table.
  # ---------------------------------------------------------------------------

  defp mint_receipt!(port, member_id, tag) do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      audience: :public,
      actions: %{
        @action_id => %{
          consumer: :mobile,
          transport: :http
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    contract_path = Path.join(@tmp_dir, "#{tag}_contract.json")
    receipt_path = Path.join(@tmp_dir, "#{tag}_receipt.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    script = """
    const runtime = await import("#{@runtime_url}");
    const fs = await import("node:fs");
    const crypto = await import("node:crypto");
    const assert = (await import("node:assert/strict")).default;

    const actionId = "#{@action_id}";
    const contract = JSON.parse(fs.readFileSync("#{contract_path}", "utf-8"));

    const http = {
      async invoke({ action, input }) {
        const res = await fetch("http://127.0.0.1:#{port}/dispatch", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: action.id, input }),
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        return await res.json();
      },
    };

    const client = runtime.createClient({ contract, transports: { http }, prefer: "http" });

    const input = {
      member_id: "#{member_id}",
      milestone_id: "milestone_state_table",
      cost_physical: 2,
      reward_spiritual: 20,
    };

    const { result, receipt } = await client.get(actionId).invokeWithReceipt(input);
    assert.equal(receipt.dispatchState, "completed");
    assert.equal(result.data.status, "completed");

    function canonicalStringify(obj) {
      if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
      if (Array.isArray(obj)) return "[" + obj.map(canonicalStringify).join(",") + "]";
      const keys = Object.keys(obj).sort();
      return "{" + keys.map((k) => JSON.stringify(k) + ":" + canonicalStringify(obj[k])).join(",") + "}";
    }

    const receiptPayload = {
      actionId,
      input,
      consequence: result.data,
      dispatchState: receipt.dispatchState,
      selectedTransport: receipt.selected,
      timestamp: new Date().toISOString(),
    };
    const receiptHash = crypto.createHash("sha256")
      .update(canonicalStringify(receiptPayload)).digest("hex");
    fs.writeFileSync("#{receipt_path}", JSON.stringify({ ...receiptPayload, receiptHash }, null, 2));
    """

    {output, exit_code} =
      System.cmd("node", ["--input-type=module", "-e", script],
        cd: @repo_root,
        stderr_to_stdout: true
      )

    assert exit_code == 0, "node runtime receipt mint failed (#{exit_code}): #{output}"

    receipt =
      receipt_path
      |> File.read!()
      |> Jason.decode!()

    # Mint premise: the runtime receipt carries a digest-shaped receiptHash
    # that binds its covered sections under the one canonical-JSON law.
    assert receipt["receiptHash"] =~ ~r/^[0-9a-f]{64}$/

    assert AshSurface.CanonicalJSON.sha256_hex(Map.take(receipt, @digest_keys)) ==
             receipt["receiptHash"]

    receipt
  end
end
