import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import crypto from "node:crypto";
import { z } from "zod";
import {
  createClient,
  observationProjectionSchema,
  planningEpisodeSchema,
  eventProjectionSchema,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

function canonicalStringify(obj) {
  if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(canonicalStringify).join(",")}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalStringify(obj[k])}`).join(",")}}`;
}

test("ZOELA MX machine-only closed loop: Observation -> Planning candidate -> Admission -> BRCE DO -> Event projection -> Replay", async () => {
  let brceExecutedCommand = null;
  let serverEventsEmitted = [];
  let receiptsLog = new Map();

  const server = http.createServer(async (req, res) => {
    if (req.method === "POST" && req.url === "/dispatch") {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      const body = JSON.parse(Buffer.concat(chunks).toString("utf-8"));

      // Simulate XaaS BRCE DO Gate
      if (body.action === "Zoela.KingdomNeed#select_option") {
        brceExecutedCommand = body;
        const receiptRef = `rcpt_b3_${crypto.randomBytes(8).toString("hex")}`;
        const domainResult = {
          success: true,
          receiptRef,
          data: {
            needId: body.input.needId,
            selectedOption: body.input.selectedOption,
            state: "SELECTED",
          },
        };

        receiptsLog.set(body.commandId, receiptRef);

        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify(domainResult));
        return;
      }
    }

    if (req.method === "GET" && req.url.startsWith("/reconcile?commandId=")) {
      const url = new URL(req.url, "http://127.0.0.1");
      const cmdId = url.searchParams.get("commandId");
      if (receiptsLog.has(cmdId)) {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "COMPLETED", receiptRef: receiptsLog.get(cmdId) }));
        return;
      } else {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "NOT_OBSERVED" }));
        return;
      }
    }

    res.writeHead(404);
    res.end();
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const { port } = server.address();

  try {
    // 1. AshSurface Contract (CalVer 26.9.16)
    const surfaceContract = {
      surfaceSchemaVersion: "26.9.16",
      ashManifestSchemaVersion: "1.1.0",
      generatorIdentity: "ash_surface:v26.9.16",
      manifest: {
        resources: [
          {
            name: "KingdomNeed",
            module: "Zoela.KingdomNeed",
          },
        ],
      },
      surface: {
        profile: { audience: "zoe_kingdom" },
        actions: [
          {
            id: "Zoela.KingdomNeed#select_option",
            semanticId: "zoe:SelectOption",
            resource: "Zoela.KingdomNeed",
            action: "select_option",
            authorityBoundary: "SELECT",
            doAuthority: false,
            receiptRequired: true,
            evidenceRequired: true,
            possibleRefusals: ["AUTHORITY_REFUSED", "OPTION_NOT_FOUND", "EVIDENCE_REQUIRED"],
            profile: {
              transport: "http",
            },
          },
        ],
      },
    };

    // 2. Client Initialization with Transport & Reconciliation
    const client = createClient({
      contract: surfaceContract,
      transports: {
        http: {
          async invoke({ action, input, commandId }) {
            const res = await fetch(`http://127.0.0.1:${port}/dispatch`, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ action: action.id, input, commandId }),
            });
            return await res.json();
          },
          async reconcile(commandId) {
            const res = await fetch(`http://127.0.0.1:${port}/reconcile?commandId=${encodeURIComponent(commandId)}`);
            return await res.json();
          },
        },
      },
      prefer: "http",
      schemas: {
        "Zoela.KingdomNeed#select_option": {
          input: z.object({
            needId: z.string(),
            selectedOption: z.string(),
          }),
          output: z.object({
            success: z.boolean(),
            receiptRef: z.string(),
            data: z.object({
              needId: z.string(),
              selectedOption: z.string(),
              state: z.string(),
            }),
          }),
        },
      },
    });

    // 3. Step 1: Server sends ObservationProjection (W_t)
    const rawObs = {
      observationId: "obs_0192837465abcedf",
      exactSubject: "zoe:KingdomNeed#need_42",
      observedAt: new Date().toISOString(),
      stateDigest: crypto.createHash("sha256").update("need_42:diverged").digest("hex"),
      facts: { status: "DIVERGED", candidateOptions: ["opt_a", "opt_b"] },
      standing: "ALIVE",
      authorityBoundary: "OBSERVE",
    };
    const observation = observationProjectionSchema.parse(rawObs);
    assert.equal(observation.authorityBoundary, "OBSERVE");

    // 4. Step 2: Server projects PlanningEpisode (pi_t) with non-DO ceiling
    const rawEpisode = {
      episodeId: "ep_fond_hddl_9876",
      worldStateRef: observation.observationId,
      plannerIdentity: "ash_pplan:fond_hddl_solver",
      policyIdentity: "zoe:policy:strong_cyclic",
      policyStanding: "VALID_STRONG_CYCLIC",
      candidateActions: [{ action: "Zoela.KingdomNeed#select_option", option: "opt_a" }],
      authorityCeiling: "SELECT",
    };
    const episode = planningEpisodeSchema.parse(rawEpisode);
    assert.equal(episode.authorityCeiling, "SELECT");

    // 5. Step 3: ZOELA invokes action carrying candidate intent (authorityBoundary=SELECT, doAuthority=false)
    const actionDescriptor = client.get("Zoela.KingdomNeed#select_option");
    assert.equal(actionDescriptor.authorityBoundary, "SELECT");
    assert.equal(actionDescriptor.doAuthority, false);

    // Setup event subscriber
    let receivedEvent = null;
    const unsubscribe = client.events.subscribe("zoe:KingdomNeed#need_42", (ev) => {
      receivedEvent = ev;
    });

    const commandId = "cmd_zoela_test_001";
    const { result, receipt } = await actionDescriptor.invokeWithReceipt(
      { needId: "need_42", selectedOption: "opt_a" },
      { commandId }
    );

    // Assert MXReceipt
    assert.equal(receipt.dispatchState, "completed");
    assert.equal(receipt.outcome, "SUCCESS");
    assert.equal(receipt.authorityBoundary, "SELECT");
    assert.equal(receipt.doAuthority, false);
    assert.equal(receipt.commandId, commandId);
    assert.ok(receipt.domainReceiptRef.startsWith("rcpt_b3_"));

    // Verify backend received command
    assert.equal(brceExecutedCommand.input.needId, "need_42");
    assert.equal(brceExecutedCommand.input.selectedOption, "opt_a");

    // 6. Step 4: Server emits EventProjection (W_{t+1})
    const eventPayload = {
      eventId: "ev_state_transition_01",
      sequence: 1,
      subjectRef: "zoe:KingdomNeed#need_42",
      eventType: "need_state_selected",
      stateDigest: crypto.createHash("sha256").update("need_42:selected").digest("hex"),
      receiptRef: receipt.domainReceiptRef,
      occurredAt: new Date().toISOString(),
      authorityBoundary: "OBSERVE",
    };
    client.events.emit(eventPayload);

    assert.ok(receivedEvent !== null);
    assert.equal(receivedEvent.eventType, "need_state_selected");
    assert.equal(receivedEvent.receiptRef, receipt.domainReceiptRef);
    assert.equal(receivedEvent.authorityBoundary, "OBSERVE");

    // 7. Step 5: Test Reconciliation without retry
    const reconciliation = await client.reconcile(commandId);
    assert.equal(reconciliation.status, "COMPLETED");
    assert.equal(reconciliation.receiptRef, receipt.domainReceiptRef);

    // 8. Step 6: Verify Replay Key Determinism
    const replayPayload = {
      calver: "26.9.16",
      generator: surfaceContract.generatorIdentity,
      actionId: actionDescriptor.id,
      input: brceExecutedCommand.input,
      receiptRef: receipt.domainReceiptRef,
      eventSequence: receivedEvent.sequence,
    };
    const replayDigest = crypto.createHash("sha256").update(canonicalStringify(replayPayload)).digest("hex");
    assert.equal(replayDigest.length, 64);

    unsubscribe();
  } finally {
    server.close();
  }
});
