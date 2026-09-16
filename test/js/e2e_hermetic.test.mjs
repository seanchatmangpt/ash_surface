// E2E Hermeticity Proof: the JS suite runs its core closed loop with every
// network-touching surface monkey-patched to throw, and stays deterministic.
//
// Hermetic contract proven here:
//   1. Zero-config audit: no test/js source reads process.env; every URL
//      literal in the suite targets loopback only (127.0.0.1 / localhost).
//   2. With globalThis.fetch, http(s).request/get, net.connect, dns.lookup
//      (and WebSocket/XMLHttpRequest when present) all patched to throw,
//      the core ZOELA MX closed loop (Observation -> Planning -> Admission
//      -> SELECT-boundary dispatch -> Event projection -> Reconciliation
//      -> Replay digest) completes successfully over an in-memory transport.
//   3. Transport Law still holds without sockets: a post-dispatch transport
//      failure surfaces as TRANSPORT_OUTCOME_UNKNOWN, never a retry.
//   4. Determinism: two fresh runs of the closed loop produce identical
//      canonical receipt projections and identical replay digests once the
//      wall-clock receipt timestamp is excluded.
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import http from "node:http";
import https from "node:https";
import net from "node:net";
import dns from "node:dns";
import { fileURLToPath } from "node:url";
import { z } from "zod";
import {
  createClient,
  SurfaceRuntimeError,
  observationProjectionSchema,
  planningEpisodeSchema,
  eventProjectionSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));

function canonicalStringify(obj) {
  if (obj === null || typeof obj !== "object") return JSON.stringify(obj);
  if (Array.isArray(obj)) return `[${obj.map(canonicalStringify).join(",")}]`;
  const keys = Object.keys(obj).sort();
  return `{${keys.map((k) => `${JSON.stringify(k)}:${canonicalStringify(obj[k])}`).join(",")}`;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

// ---------------------------------------------------------------------------
// 1. Zero-config static audit of the suite's own sources
// ---------------------------------------------------------------------------

test("suite audit: no environment-variable reads and loopback-only URLs in test/js sources", () => {
  const self = path.basename(fileURLToPath(import.meta.url));
  const sources = fs
    .readdirSync(HERE)
    .filter((name) => name.endsWith(".mjs") && name !== self)
    .map((name) => ({ name, content: fs.readFileSync(path.join(HERE, name), "utf-8") }));

  assert.ok(sources.length >= 4, "expected runner + at least three fixture tests to audit");

  for (const { name, content } of sources) {
    assert.equal(
      content.includes("process.env"),
      false,
      `${name} must not read environment variables (zero-config)`,
    );

    const hosts = [...content.matchAll(/https?:\/\/([^/"'\s]+)/g)].map((m) =>
      m[1].replace(/\$\{[^}]*\}/g, "").replace(/:$/, ""),
    );
    for (const host of hosts) {
      assert.ok(
        host === "127.0.0.1" || host === "localhost",
        `${name} references non-loopback host ${host}; hermetic suite permits loopback only`,
      );
    }
  }
});

// ---------------------------------------------------------------------------
// 2. Core closed loop under network quarantine
// ---------------------------------------------------------------------------

function quarantineNetworkSurfaces() {
  const deny = (surface) => {
    throw new Error(`HERMETIC VIOLATION: ${surface} was invoked; the suite must not touch the network`);
  };
  const originals = new Map();
  const replace = (holder, key, surface) => {
    originals.set([holder, key], holder[key]);
    holder[key] = () => deny(surface);
  };

  replace(globalThis, "fetch", "globalThis.fetch");
  replace(http, "request", "http.request");
  replace(http, "get", "http.get");
  replace(https, "request", "https.request");
  replace(https, "get", "https.get");
  replace(net, "connect", "net.connect");
  replace(dns, "lookup", "dns.lookup");
  if ("WebSocket" in globalThis) replace(globalThis, "WebSocket", "WebSocket");
  if ("XMLHttpRequest" in globalThis) replace(globalThis, "XMLHttpRequest", "XMLHttpRequest");

  return () => {
    for (const [[holder, key], value] of originals) holder[key] = value;
  };
}

function makeSurfaceContract() {
  return {
    surfaceSchemaVersion: "26.9.13",
    ashManifestSchemaVersion: "1.1.0",
    generatorIdentity: "ash_surface:v26.9.13",
    manifest: {
      resources: [{ name: "KingdomNeed", module: "Zoela.KingdomNeed" }],
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
          profile: { transport: "http" },
        },
      ],
    },
  };
}

// In-memory BRCE stub: the same consequence semantics as the loopback fixture
// server, with zero sockets and zero randomness (deterministic receiptRef).
function makeInMemoryBackend() {
  const receipts = new Map();
  return {
    receipts,
    transport: {
      async invoke({ input, commandId }) {
        const receiptRef = `rcpt_hermetic_${commandId}`;
        receipts.set(commandId, receiptRef);
        return {
          success: true,
          receiptRef,
          data: {
            needId: input.needId,
            selectedOption: input.selectedOption,
            state: "SELECTED",
          },
        };
      },
      async reconcile(commandId) {
        return receipts.has(commandId)
          ? { status: "COMPLETED", receiptRef: receipts.get(commandId) }
          : { status: "NOT_OBSERVED" };
      },
    },
  };
}

// Runs the full closed loop and returns a canonical (wall-clock-free)
// projection of what happened, plus the runtime receipt.
async function runCoreClosedLoop({ commandId }) {
  const contract = makeSurfaceContract();
  const backend = makeInMemoryBackend();

  // Step 1: Observation projection (W_t) — read-only world state.
  const observation = observationProjectionSchema.parse({
    observationId: "obs_hermetic_01",
    exactSubject: "zoe:KingdomNeed#need_42",
    observedAt: new Date(0).toISOString(),
    stateDigest: sha256("need_42:diverged"),
    facts: { status: "DIVERGED", candidateOptions: ["opt_a", "opt_b"] },
    standing: "ALIVE",
    authorityBoundary: "OBSERVE",
  });
  assert.equal(observation.authorityBoundary, "OBSERVE");

  // Step 2: Planning episode (pi_t) — non-DO ceiling, DO is refused.
  const episode = planningEpisodeSchema.parse({
    episodeId: "ep_hermetic_01",
    worldStateRef: observation.observationId,
    plannerIdentity: "ash_pplan:fond_hddl_solver",
    policyIdentity: "zoe:policy:strong_cyclic",
    policyStanding: "VALID_STRONG_CYCLIC",
    candidateActions: [{ action: "Zoela.KingdomNeed#select_option", option: "opt_a" }],
    authorityCeiling: "SELECT",
  });
  assert.throws(() =>
    planningEpisodeSchema.parse({ ...episode, authorityCeiling: "DO" }),
  );

  // Step 3: Admission + dispatch over the in-memory transport.
  const client = createClient({
    contract,
    transports: { http: backend.transport },
    prefer: "http",
    schemas: {
      "Zoela.KingdomNeed#select_option": {
        input: z.object({ needId: z.string(), selectedOption: z.string() }),
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

  const actionDescriptor = client.get("Zoela.KingdomNeed#select_option");
  assert.equal(actionDescriptor.authorityBoundary, "SELECT");
  assert.equal(actionDescriptor.doAuthority, false);

  let receivedEvent = null;
  const unsubscribe = client.events.subscribe("zoe:KingdomNeed#need_42", (ev) => {
    receivedEvent = ev;
  });

  const input = { needId: "need_42", selectedOption: "opt_a" };
  const { result, receipt } = await actionDescriptor.invokeWithReceipt(input, { commandId });

  assert.equal(receipt.dispatchState, "completed");
  assert.equal(receipt.outcome, "SUCCESS");
  assert.equal(receipt.selected, "http");
  assert.equal(receipt.authorityBoundary, "SELECT");
  assert.equal(receipt.doAuthority, false);
  assert.equal(receipt.commandId, commandId);
  assert.equal(receipt.domainReceiptRef, `rcpt_hermetic_${commandId}`);
  assert.equal(result.data.state, "SELECTED");

  // Step 4: Event projection (W_{t+1}) delivered to the subscriber.
  client.events.emit({
    eventId: "ev_hermetic_01",
    sequence: 1,
    subjectRef: "zoe:KingdomNeed#need_42",
    eventType: "need_state_selected",
    stateDigest: sha256("need_42:selected"),
    receiptRef: receipt.domainReceiptRef,
    occurredAt: new Date(0).toISOString(),
    authorityBoundary: "OBSERVE",
  });
  assert.equal(receivedEvent.receiptRef, receipt.domainReceiptRef);
  assert.equal(receivedEvent.authorityBoundary, "OBSERVE");
  unsubscribe();

  // Step 5: Reconciliation without re-actuation.
  const reconciliation = await client.reconcile(commandId);
  assert.equal(reconciliation.status, "COMPLETED");
  assert.equal(reconciliation.receiptRef, receipt.domainReceiptRef);

  // Step 6: Replay key digest (canonical, wall-clock-free).
  const { timestamp: _wallClock, ...receiptProjection } = receipt;
  const replayDigest = sha256(
    canonicalStringify({
      calver: contract.surfaceSchemaVersion,
      generator: contract.generatorIdentity,
      actionId: actionDescriptor.id,
      input,
      receiptRef: receipt.domainReceiptRef,
      eventSequence: receivedEvent.sequence,
    }),
  );

  return { receiptProjection, replayDigest };
}

test("core closed loop completes with every network surface patched to throw", async (t) => {
  const restore = quarantineNetworkSurfaces();
  t.after(restore);

  // Sanity: the quarantine is active, not silently bypassed.
  let fetchDenied = false;
  try {
    await fetch("http://127.0.0.1:9/");
  } catch {
    fetchDenied = true;
  }
  assert.ok(fetchDenied, "patched fetch must throw when invoked");
  assert.throws(() => http.get("http://127.0.0.1:9/"), /HERMETIC VIOLATION/);

  const { receiptProjection, replayDigest } = await runCoreClosedLoop({
    commandId: "cmd_hermetic_001",
  });

  assert.equal(receiptProjection.dispatchState, "completed");
  assert.equal(receiptProjection.outcome, "SUCCESS");
  assert.equal(replayDigest.length, 64);
});

test("closed loop is deterministic: two runs yield identical canonical receipts and replay digests", async (t) => {
  const restore = quarantineNetworkSurfaces();
  t.after(restore);

  const first = await runCoreClosedLoop({ commandId: "cmd_hermetic_determinism" });
  const second = await runCoreClosedLoop({ commandId: "cmd_hermetic_determinism" });

  assert.equal(
    canonicalStringify(first.receiptProjection),
    canonicalStringify(second.receiptProjection),
  );
  assert.equal(first.replayDigest, second.replayDigest);
});

test("transport law holds without sockets: post-dispatch failure is TRANSPORT_OUTCOME_UNKNOWN, never retried", async (t) => {
  const restore = quarantineNetworkSurfaces();
  t.after(restore);

  let invocations = 0;
  const client = createClient({
    contract: makeSurfaceContract(),
    transports: {
      http: {
        async invoke() {
          invocations += 1;
          throw new Error("simulated disconnect after dispatch");
        },
      },
    },
    prefer: "http",
  });

  await assert.rejects(
    () =>
      client.get("Zoela.KingdomNeed#select_option").invoke({
        needId: "need_42",
        selectedOption: "opt_a",
      }),
    (error) => {
      assert.ok(error instanceof SurfaceRuntimeError);
      assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
      assert.equal(error.receipt.fallback, "pre_dispatch_only");
      return true;
    },
  );

  assert.equal(invocations, 1, "no automatic cross-transport retry may occur");
});
