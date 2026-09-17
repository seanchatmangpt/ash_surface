defmodule AshSurface.MXClosedLoopDeepTest do
  @moduledoc """
  Deep edge-case falsifiers for the MX closed loop, extending the happy paths
  already proven in `mx_closed_loop_episode_test.exs` and `consumer_fixture_test.exs`
  without duplicating them:

  - at-least-once delivery: replaying the full observation -> planning -> admission
    -> DO -> event loop with a duplicate commandId must be idempotent (exactly one
    Ash consequence), while ungated redelivery is proven to duplicate.
  - reconciliation classification: COMPLETED is bound to the real consequence,
    a command the DO gate never observed is NOT_OBSERVED, and a transport without
    reconciliation support classifies as STILL_UNKNOWN.
  - episode verification failure paths: missing receipt, receipt-hash mismatch,
    and wrong subject binding on emitted events are all rejected.
  - provenance lattice on the composed MX receipt: commandId, semanticId,
    authority ceiling, transport decision, and domain consequence binding.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{Event, Observation, PlanningEpisode}
  alias AshSurface.Fixtures.{Server, VolunteerMilestone}

  @repo_root Path.expand("../..", __DIR__)
  @tmp_dir Path.join(@repo_root, "_build/test/mx_closed_loop_deep")
  @runtime_url "file://" <> Path.expand("../../priv/static/ash_surface_runtime.mjs", __DIR__)
  @verifier_script Path.expand(
                     "../../ggen-marketplace/domains/repo-closure/verifier/verify_closure_episode.py",
                     __DIR__
                   )
  @action_id "AshSurface.Fixtures.VolunteerMilestone#record"

  # Mirrors the mx-episode-schema@v26.9.17 required-field law used by
  # verify_closure_episode.py, plus the subject-binding law this repo's episodes
  # must satisfy (every emitted event binds back to the observation's subject).
  @episode_required_fields [
    "episode_id",
    "subject_repo",
    "subject_head",
    "pattern_version",
    "domain_version",
    "hddl_version",
    "fond_version",
    "verifier_version",
    "selected_decomposition",
    "observed_transitions",
    "cost_score",
    "receipt_hash",
    "resulting_standing"
  ]

  @episode_standings ["ALIVE", "PARTIAL_ALIVE", "BLOCKED", "BUILD_BROKEN", "UNSUPPORTED"]

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    {:ok, server_pid} = Server.start_link()
    port = Server.get_port(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Server.stop(server_pid)
    end)

    {:ok, server_pid: server_pid, port: port, tmp_dir: @tmp_dir}
  end

  test "duplicate commandId replay of the observation-planning-admission-DO-event loop is idempotent",
       %{port: port, tmp_dir: tmp_dir} do
    # 1. Observation projection (deterministic replay key)
    facts = %{
      "kingdom_need_id" => "need_deep_replay",
      "open_opportunities" => 1,
      "member_id" => "member_deep_replay_01",
      "milestone_id" => "milestone_deep_01"
    }

    subject = "zoe:KingdomNeed#need_deep_replay"
    obs = Observation.create(subject, facts, standing: :ALIVE)
    assert obs.authority_boundary == :OBSERVE

    # 2. Planning episode projection with a SELECT-only candidate
    episode_opts = [
      planner_identity: "ash_pplan:fond_hddl_solver",
      policy_identity: "zoe:policy:strong_cyclic",
      policy_standing: :VALID_STRONG_CYCLIC,
      candidate_actions: [candidate("member_deep_replay_01", 7, 70)],
      authority_ceiling: :SELECT
    ]

    episode = PlanningEpisode.create(obs.observation_id, episode_opts)
    assert episode.authority_ceiling == :SELECT

    # 3. Admission surface (contract must replay to the same digest)
    manifest = generate_manifest!()
    %{surface: surface, contract_path: contract_path} = admit!(manifest, tmp_dir, "replay")
    assert {:ok, replay_surface} = AshSurface.from_manifest(manifest, profile: surface_profile())
    assert replay_surface.digest == surface.digest

    # 4. DO + replay through the runtime with an idempotency-gated transport
    receipt1_path = Path.join(tmp_dir, "replay_receipt_1.json")
    receipt2_path = Path.join(tmp_dir, "replay_receipt_2.json")
    meta_path = Path.join(tmp_dir, "replay_meta.json")

    run_node!(replay_script(port, contract_path, receipt1_path, receipt2_path, meta_path))

    meta = Jason.decode!(File.read!(meta_path))
    # One gated dispatch + two ungated control dispatches; the replay never hit the wire.
    assert meta["networkHits"] == 3

    # 5. Exactly one consequence for the gated command; the ungated control duplicated.
    [record] = records_for("member_deep_replay_01")
    assert record.status == "completed"
    assert meta["gatedConsequenceId"] == record.id

    control_ids = records_for("member_deep_nodedupe_02") |> Enum.map(& &1.id) |> MapSet.new()
    assert MapSet.size(control_ids) == 2
    assert MapSet.new(meta["controlIds"]) == control_ids

    # 6. Idempotent outcome: both composed receipts carry identical provenance.
    r1 = Jason.decode!(File.read!(receipt1_path))
    r2 = Jason.decode!(File.read!(receipt2_path))

    assert r1["commandId"] == "cmd_deep_replay_001"
    assert r2["commandId"] == "cmd_deep_replay_001"

    for field <- [
          "commandId",
          "dispatchState",
          "outcome",
          "domainReceiptRef",
          "semanticId",
          "authorityBoundary",
          "doAuthority",
          "selected",
          "preferred",
          "reason"
        ] do
      assert r1[field] == r2[field], "replayed receipt diverged on #{field}"
    end

    assert r1["consequenceReceipt"]["id"] == record.id
    assert r2["consequenceReceipt"]["id"] == record.id

    # 7. Projection replay determinism: same inputs replay to same identities.
    obs_replay = Observation.create(subject, facts, standing: :ALIVE)
    assert obs_replay.observation_id == obs.observation_id
    assert obs_replay.state_digest == obs.state_digest

    ep_replay = PlanningEpisode.create(obs.observation_id, episode_opts)
    assert ep_replay.episode_id == episode.episode_id

    event_opts = [
      payload: %{"status" => "completed", "record_id" => record.id},
      receipt_ref: "rcpt_consequence_#{record.id}"
    ]

    ev = Event.create(obs.exact_subject, 1, "state_transition", event_opts)
    ev_replay = Event.create(obs.exact_subject, 1, "state_transition", event_opts)
    assert ev_replay.event_id == ev.event_id
    assert ev_replay.state_digest == ev.state_digest
    assert ev.receipt_ref == "rcpt_consequence_#{record.id}"
  end

  test "reconciliation classification: COMPLETED binds the real consequence, unseen commands are NOT_OBSERVED, unsupported reconciliation is STILL_UNKNOWN",
       %{port: port, tmp_dir: tmp_dir} do
    manifest = generate_manifest!()
    %{contract_path: contract_path} = admit!(manifest, tmp_dir, "reconcile")

    classifications_path = Path.join(tmp_dir, "reconcile_classifications.json")

    run_node!(reconcile_script(port, contract_path, classifications_path))

    classifications = Jason.decode!(File.read!(classifications_path))

    # COMPLETED must name the actual consequence in the Ash data layer.
    [record] = records_for("member_deep_reconcile_01")
    assert classifications["completed"]["status"] == "COMPLETED"
    assert classifications["completed"]["receiptRef"] == record.id
    assert classifications["completed"]["receiptRef"] != nil

    # A command the DO gate never observed is NOT_OBSERVED, carrying no receipt.
    assert classifications["notObserved"] == %{"status" => "NOT_OBSERVED"}

    # A transport without reconciliation support cannot invent certainty.
    assert classifications["stillUnknown"]["status"] == "STILL_UNKNOWN"
    assert classifications["stillUnknown"]["reason"] == "transport_reconciliation_unsupported"
    assert classifications["stillUnknown"]["commandId"] == classifications["dispatchCmd"]
  end

  test "episode verification failure paths: missing receipt, tampered receipt hash, and wrong subject binding are rejected",
       %{port: port, tmp_dir: tmp_dir} do
    subject = "zoe:KingdomNeed#need_deep_verify"

    facts = %{
      "kingdom_need_id" => "need_deep_verify",
      "member_id" => "member_deep_verify_01",
      "milestone_id" => "milestone_deep_01"
    }

    obs = Observation.create(subject, facts, standing: :ALIVE)

    episode =
      PlanningEpisode.create(obs.observation_id,
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:policy:strong_cyclic",
        policy_standing: :VALID_STRONG,
        candidate_actions: [candidate("member_deep_verify_01", 5, 50)],
        authority_ceiling: :SELECT
      )

    assert episode.authority_ceiling == :SELECT

    manifest = generate_manifest!()
    %{contract_path: contract_path} = admit!(manifest, tmp_dir, "verify")

    receipt_path = Path.join(tmp_dir, "verify_receipt.json")
    run_node!(dispatch_and_hash_script(port, contract_path, receipt_path))

    [record] = records_for("member_deep_verify_01")
    receipt = Jason.decode!(File.read!(receipt_path))

    # Binding premise: the composed receipt's hash is reproducible.
    assert recomputed_receipt_hash(receipt) == receipt["receiptHash"]

    event_opts = [
      payload: %{"status" => "completed", "record_id" => record.id},
      receipt_ref: "rcpt_consequence_#{record.id}"
    ]

    ev = Event.create(obs.exact_subject, 1, "state_transition", event_opts)

    valid_episode = build_episode(obs, record, ev, receipt["receiptHash"])
    assert :ok = verify_episode_law(valid_episode, obs.exact_subject, receipt)

    # Failure path 1: episode composed without its consequence receipt.
    missing_receipt = Map.drop(valid_episode, ["receipt_hash"])

    assert {:error, {:missing_fields, ["receipt_hash"]}} =
             verify_episode_law(missing_receipt, obs.exact_subject, receipt)

    # Failure path 2: episode whose receipt_hash does not bind the real receipt.
    tampered = Map.put(valid_episode, "receipt_hash", String.duplicate("ab", 32))

    assert {:error, :receipt_hash_mismatch} =
             verify_episode_law(tampered, obs.exact_subject, receipt)

    # Failure path 3: episode whose emitted event binds the wrong subject.
    wrong_ev =
      Event.create("zoe:KingdomNeed#need_wrong_subject", 1, "state_transition", event_opts)

    wrong_subject = build_episode(obs, record, wrong_ev, receipt["receiptHash"])

    assert {:error, {:subject_binding_violation, "zoe:KingdomNeed#need_wrong_subject"}} =
             verify_episode_law(wrong_subject, obs.exact_subject, receipt)

    # Failure path 4 (standing vocabulary): an unrecognized resulting standing.
    bad_standing = Map.put(valid_episode, "resulting_standing", "PROBABLY_FINE")

    assert {:error, {:invalid_standing, "PROBABLY_FINE"}} =
             verify_episode_law(bad_standing, obs.exact_subject, receipt)

    # Independent verifier agreement where the marketplace checkout is vendored.
    if File.exists?(@verifier_script) do
      missing_path = Path.join(tmp_dir, "verify_episode_missing.json")
      File.write!(missing_path, Jason.encode!(missing_receipt))

      {missing_out, missing_code} = run_python_verifier(missing_path)
      assert missing_code == 1
      assert String.contains?(missing_out, "MISSING_EPISODE_FIELDS")

      calver_drift = Map.put(valid_episode, "pattern_version", "v25.9.12")
      calver_path = Path.join(tmp_dir, "verify_episode_calver.json")
      File.write!(calver_path, Jason.encode!(calver_drift))

      {calver_out, calver_code} = run_python_verifier(calver_path)
      assert calver_code == 1
      assert String.contains?(calver_out, "CALVER_MISMATCH")
    end
  end

  test "composed MX receipt carries the full provenance lattice of the episode",
       %{port: port, tmp_dir: tmp_dir} do
    subject = "zoe:KingdomNeed#need_deep_prov"

    obs =
      Observation.create(subject, %{
        "kingdom_need_id" => "need_deep_prov",
        "member_id" => "member_deep_prov_01",
        "milestone_id" => "milestone_deep_01"
      })

    episode =
      PlanningEpisode.create(obs.observation_id,
        planner_identity: "ash_pplan:fond_hddl_solver",
        policy_identity: "zoe:policy:strong_cyclic",
        policy_standing: :VALID_STRONG,
        candidate_actions: [candidate("member_deep_prov_01", 6, 60)],
        authority_ceiling: :SELECT
      )

    manifest = generate_manifest!()
    %{surface: surface, contract_path: contract_path} = admit!(manifest, tmp_dir, "prov")

    receipt_path = Path.join(tmp_dir, "prov_receipt.json")
    run_node!(provenance_script(port, contract_path, receipt_path))

    [record] = records_for("member_deep_prov_01")
    receipt = Jason.decode!(File.read!(receipt_path))

    # Dispatch provenance: the exact command key the loop dispatched.
    assert receipt["commandId"] == "cmd_deep_prov_001"

    # Planning provenance: the receipt's semanticId binds the admitted candidate.
    assert receipt["semanticId"] == episode.candidate_actions |> hd() |> get_in(["semanticId"])
    contracted = Enum.find(surface.contract["surface"]["actions"], &(&1["id"] == @action_id))
    assert contracted["semanticId"] == receipt["semanticId"]

    # Admission provenance: the SELECT ceiling and non-DO authority carried onto the receipt.
    assert receipt["authorityBoundary"] == "SELECT"
    assert receipt["doAuthority"] == false
    assert receipt["outcome"] == "SUCCESS"
    assert receipt["dispatchState"] == "completed"

    # Transport decision provenance.
    tr = receipt["transportReceipt"]
    assert tr["actionId"] == @action_id
    assert tr["selected"] == "http"
    assert tr["preferred"] == "http"
    assert tr["reason"] == "preferred_available"
    assert tr["fallback"] == "pre_dispatch_only"
    assert tr["dispatchState"] == "completed"
    assert "http" in tr["declared"]
    assert "http" in tr["available"]

    # Domain consequence provenance: bound to the real Ash record.
    assert receipt["domainReceiptRef"] == record.id
    assert receipt["consequenceReceipt"]["id"] == record.id
    assert receipt["consequenceReceipt"]["data"]["member_id"] == "member_deep_prov_01"
    assert receipt["consequenceReceipt"]["data"]["status"] == "completed"

    # Timestamp provenance is a real ISO8601 instant.
    assert {:ok, _, _} = DateTime.from_iso8601(receipt["timestamp"])

    # Contract provenance the receipt is bound to.
    assert surface.contract["generatorIdentity"] == "ash_surface:v26.9.17"
    assert surface.contract["marketplaceIdentity"] == "ggen-marketplace:v26.9.17"
    assert surface.digest =~ ~r/^[0-9a-f]{64}$/
    assert surface.contract["manifestDigest"] =~ ~r/^[0-9a-f]{64}$/
  end

  # ---------------------------------------------------------------------------
  # Elixir-side episode law (test-local mirror of mx-episode-schema@v26.9.17,
  # valid on machines where the marketplace verifier checkout is absent)
  # ---------------------------------------------------------------------------

  defp verify_episode_law(episode, exact_subject, receipt) do
    missing = @episode_required_fields -- Map.keys(episode)

    cond do
      missing != [] ->
        {:error, {:missing_fields, missing}}

      episode["receipt_hash"] != recomputed_receipt_hash(receipt) ->
        {:error, :receipt_hash_mismatch}

      true ->
        with :ok <- verify_subject_bindings(episode["observed_transitions"], exact_subject) do
          if episode["resulting_standing"] in @episode_standings do
            :ok
          else
            {:error, {:invalid_standing, episode["resulting_standing"]}}
          end
        end
    end
  end

  defp verify_subject_bindings(transitions, exact_subject)
       when is_list(transitions) do
    Enum.reduce_while(transitions, :ok, fn transition, :ok ->
      case transition["subject_ref"] do
        nil -> {:cont, :ok}
        ^exact_subject -> {:cont, :ok}
        other -> {:halt, {:error, {:subject_binding_violation, other}}}
      end
    end)
  end

  defp verify_subject_bindings(_transitions, _exact_subject), do: {:error, :invalid_transitions}

  defp build_episode(obs, record, event, receipt_hash) do
    %{
      "episode_id" => "MXEpisode/2026-09-15/deep000001",
      "subject_repo" => "seanchatmangpt/ash_surface",
      "subject_head" => "00f14b1b966900aa129f16a2e51727ef697823ec",
      "pattern_version" => "v26.9.17",
      "domain_version" => "v26.9.17",
      "hddl_version" => "v26.9.17",
      "fond_version" => "v26.9.17",
      "verifier_version" => "v26.9.17",
      "selected_decomposition" => [
        "observe_state",
        "project_candidates",
        "authorize_candidate",
        "actuate_brce",
        "emit_event"
      ],
      "observed_transitions" => [
        %{"step" => "observe", "state_digest" => obs.state_digest},
        %{"step" => "actuate", "outcome" => "pass", "consequence_id" => record.id},
        %{
          "step" => "emit_event",
          "event_id" => event.event_id,
          "subject_ref" => event.subject_ref,
          "state_digest" => event.state_digest
        }
      ],
      "cost_score" => 1.0,
      "receipt_hash" => receipt_hash,
      "resulting_standing" => "ALIVE"
    }
  end

  defp recomputed_receipt_hash(receipt) do
    payload = %{
      "actionId" => receipt["actionId"],
      "input" => receipt["input"],
      "consequence" => receipt["consequence"],
      "dispatchState" => receipt["dispatchState"],
      "selectedTransport" => receipt["selectedTransport"],
      "timestamp" => receipt["timestamp"]
    }

    # finish-replay-020: the repo has ONE canonical-JSON law, lib-owned.
    AshSurface.CanonicalJSON.sha256_hex(payload)
  end

  # ---------------------------------------------------------------------------
  # Loop fixtures
  # ---------------------------------------------------------------------------

  defp candidate(member_id, cost, reward) do
    %{
      "actionId" => @action_id,
      "semanticId" => "zoe:SelectOption",
      "authorityBoundary" => "SELECT",
      "doAuthority" => false,
      "input" => %{
        "member_id" => member_id,
        "milestone_id" => "milestone_deep_01",
        "cost_physical" => cost,
        "reward_spiritual" => reward
      }
    }
  end

  defp surface_profile do
    %{
      audience: :zoe_kingdom,
      actions: %{
        @action_id => %{
          semanticId: "zoe:SelectOption",
          authorityBoundary: "SELECT",
          doAuthority: false,
          receiptRequired: true,
          evidenceRequired: true,
          possibleRefusals: [
            "AUTHORITY_REFUSED",
            "EVIDENCE_REQUIRED",
            "UNKNOWN_AFTER_DISPATCH"
          ]
        }
      }
    }
  end

  defp generate_manifest! do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    manifest
  end

  defp admit!(manifest, tmp_dir, prefix) do
    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: surface_profile())
    contract_path = Path.join(tmp_dir, "#{prefix}_contract.json")
    File.write!(contract_path, Jason.encode!(surface.contract))
    %{surface: surface, contract_path: contract_path}
  end

  defp records_for(member_id) do
    assert {:ok, records} = Ash.read(VolunteerMilestone, domain: AshSurface.Fixtures.Domain)
    Enum.filter(records, &(&1.member_id == member_id))
  end

  # ---------------------------------------------------------------------------
  # Embedded JavaScript consumers (runtime law exercised against the real
  # fixture server and the real Ash data layer)
  # ---------------------------------------------------------------------------

  defp run_node!(script) do
    {output, exit_code} =
      System.cmd("node", ["--input-type=module", "-e", script],
        cd: @repo_root,
        stderr_to_stdout: true
      )

    assert exit_code == 0, "embedded node consumer failed (#{exit_code}): #{output}"
    output
  end

  defp replay_script(port, contract_path, receipt1_path, receipt2_path, meta_path) do
    """
    const runtime = await import("#{@runtime_url}");
    const fs = await import("node:fs");
    const assert = (await import("node:assert/strict")).default;

    const actionId = "#{@action_id}";
    const contract = JSON.parse(fs.readFileSync("#{contract_path}", "utf-8"));

    let networkHits = 0;
    const commandLedger = new Map();

    async function postDispatch(action, input, commandId) {
      const res = await fetch("http://127.0.0.1:#{port}/dispatch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: action.id, input, commandId }),
      });
      if (!res.ok) throw new Error("HTTP " + res.status);
      return await res.json();
    }

    // At-least-once idempotency gate: the commandId ledger short-circuits
    // duplicate delivery before it can reach the DO gate.
    const idempotentHttp = {
      async invoke({ action, input, commandId }) {
        if (commandLedger.has(commandId)) return commandLedger.get(commandId);
        networkHits += 1;
        const body = await postDispatch(action, input, commandId);
        commandLedger.set(commandId, body);
        return body;
      },
    };

    const ungatedHttp = {
      async invoke({ action, input, commandId }) {
        networkHits += 1;
        return await postDispatch(action, input, commandId);
      },
    };

    const gated = runtime.createClient({ contract, transports: { http: idempotentHttp }, prefer: "http" });
    const ungated = runtime.createClient({ contract, transports: { http: ungatedHttp }, prefer: "http" });

    const cmd = "cmd_deep_replay_001";
    const input = {
      member_id: "member_deep_replay_01",
      milestone_id: "milestone_deep_01",
      cost_physical: 7,
      reward_spiritual: 70,
    };

    const first = await gated.get(actionId).invokeWithReceipt(input, { commandId: cmd });
    const replay = await gated.get(actionId).invokeWithReceipt(input, { commandId: cmd });

    assert.equal(first.receipt.commandId, cmd);
    assert.equal(replay.receipt.commandId, cmd);
    assert.equal(first.receipt.dispatchState, "completed");
    assert.equal(replay.receipt.dispatchState, "completed");
    assert.equal(first.receipt.outcome, "SUCCESS");
    assert.equal(replay.receipt.outcome, "SUCCESS");
    assert.equal(replay.receipt.domainReceiptRef, first.receipt.domainReceiptRef);
    assert.equal(replay.receipt.consequenceReceipt.id, first.receipt.consequenceReceipt.id);
    assert.equal(replay.result.data.id, first.result.data.id);

    // Negative control: redelivery without the gate duplicates the consequence.
    const controlInput = {
      member_id: "member_deep_nodedupe_02",
      milestone_id: "milestone_deep_01",
      cost_physical: 3,
      reward_spiritual: 30,
    };
    const controlA = await ungated.get(actionId).invokeWithReceipt(controlInput);
    const controlB = await ungated.get(actionId).invokeWithReceipt(controlInput);
    assert.notEqual(controlA.result.data.id, controlB.result.data.id);

    assert.equal(networkHits, 3);

    fs.writeFileSync("#{receipt1_path}", JSON.stringify(first.receipt, null, 2));
    fs.writeFileSync("#{receipt2_path}", JSON.stringify(replay.receipt, null, 2));
    fs.writeFileSync(
      "#{meta_path}",
      JSON.stringify({
        networkHits,
        gatedConsequenceId: first.result.data.id,
        controlIds: [controlA.result.data.id, controlB.result.data.id],
      })
    );
    """
  end

  defp reconcile_script(port, contract_path, classifications_path) do
    """
    const runtime = await import("#{@runtime_url}");
    const fs = await import("node:fs");
    const assert = (await import("node:assert/strict")).default;

    const actionId = "#{@action_id}";
    const contract = JSON.parse(fs.readFileSync("#{contract_path}", "utf-8"));

    // Command-receipt log backing the DO gate's reconciliation endpoint.
    const commandLedger = new Map();

    const reconcilingHttp = {
      async invoke({ action, input, commandId }) {
        const res = await fetch("http://127.0.0.1:#{port}/dispatch", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: action.id, input, commandId }),
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        const body = await res.json();
        commandLedger.set(commandId, body.data.id);
        return body;
      },
      async reconcile(commandId) {
        if (commandLedger.has(commandId)) {
          return { status: "COMPLETED", receiptRef: commandLedger.get(commandId) };
        }
        return { status: "NOT_OBSERVED" };
      },
    };

    const client = runtime.createClient({
      contract,
      transports: { http: reconcilingHttp },
      prefer: "http",
    });

    const dispatchCmd = "cmd_deep_reconcile_001";
    const input = {
      member_id: "member_deep_reconcile_01",
      milestone_id: "milestone_deep_01",
      cost_physical: 4,
      reward_spiritual: 40,
    };

    const { receipt } = await client.get(actionId).invokeWithReceipt(input, { commandId: dispatchCmd });

    const completed = await client.reconcile(dispatchCmd);
    const notObserved = await client.reconcile("cmd_deep_never_dispatched_999");

    // A transport with no reconciliation support must not invent certainty.
    const blindClient = runtime.createClient({
      contract,
      transports: { http: { async invoke() { throw new Error("never dispatched"); } } },
      prefer: "http",
    });
    const stillUnknown = await blindClient.reconcile(dispatchCmd);

    assert.equal(completed.status, "COMPLETED");
    assert.equal(completed.receiptRef, receipt.domainReceiptRef);
    assert.equal(notObserved.status, "NOT_OBSERVED");
    assert.equal(notObserved.receiptRef, undefined);
    assert.equal(stillUnknown.status, "STILL_UNKNOWN");
    assert.equal(stillUnknown.reason, "transport_reconciliation_unsupported");
    assert.equal(stillUnknown.commandId, dispatchCmd);

    fs.writeFileSync(
      "#{classifications_path}",
      JSON.stringify({ dispatchCmd, completed, notObserved, stillUnknown })
    );
    """
  end

  defp dispatch_and_hash_script(port, contract_path, receipt_path) do
    """
    const runtime = await import("#{@runtime_url}");
    const fs = await import("node:fs");
    const crypto = await import("node:crypto");
    const assert = (await import("node:assert/strict")).default;

    const actionId = "#{@action_id}";
    const contract = JSON.parse(fs.readFileSync("#{contract_path}", "utf-8"));

    const http = {
      async invoke({ action, input, commandId }) {
        const res = await fetch("http://127.0.0.1:#{port}/dispatch", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: action.id, input, commandId }),
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        return await res.json();
      },
    };

    const client = runtime.createClient({ contract, transports: { http }, prefer: "http" });

    const input = {
      member_id: "member_deep_verify_01",
      milestone_id: "milestone_deep_01",
      cost_physical: 5,
      reward_spiritual: 50,
    };

    const { result, receipt } = await client.get(actionId).invokeWithReceipt(input, {
      commandId: "cmd_deep_verify_001",
    });
    assert.equal(receipt.dispatchState, "completed");

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
    const receiptHash = crypto.createHash("sha256").update(canonicalStringify(receiptPayload)).digest("hex");

    fs.writeFileSync("#{receipt_path}", JSON.stringify({ ...receiptPayload, receiptHash }, null, 2));
    """
  end

  defp provenance_script(port, contract_path, receipt_path) do
    """
    const runtime = await import("#{@runtime_url}");
    const fs = await import("node:fs");
    const assert = (await import("node:assert/strict")).default;

    const actionId = "#{@action_id}";
    const contract = JSON.parse(fs.readFileSync("#{contract_path}", "utf-8"));

    const http = {
      async invoke({ action, input, commandId }) {
        const res = await fetch("http://127.0.0.1:#{port}/dispatch", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ action: action.id, input, commandId }),
        });
        if (!res.ok) throw new Error("HTTP " + res.status);
        return await res.json();
      },
    };

    const client = runtime.createClient({ contract, transports: { http }, prefer: "http" });

    const { receipt } = await client.get(actionId).invokeWithReceipt(
      {
        member_id: "member_deep_prov_01",
        milestone_id: "milestone_deep_01",
        cost_physical: 6,
        reward_spiritual: 60,
      },
      { commandId: "cmd_deep_prov_001" }
    );

    assert.equal(receipt.dispatchState, "completed");
    fs.writeFileSync("#{receipt_path}", JSON.stringify(receipt, null, 2));
    """
  end

  defp run_python_verifier(episode_path) do
    verify_cmd = """
    import json, sys
    from verify_closure_episode import verify_episode

    with open('#{episode_path}') as f:
        data = json.load(f)

    res = verify_episode(data)
    print(f'[{res.code}] {res.message}')
    sys.exit(0 if res.valid else 1)
    """

    System.cmd("python3.11", ["-c", verify_cmd], cd: Path.dirname(@verifier_script))
  end
end
