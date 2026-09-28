import test from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import {
  createClient,
  computeRequestDigest,
  deriveIdempotencyKey,
  IDEMPOTENCY_PROTOCOL,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Laws pinned (AGENTS.md transport law + docs/IDEMPOTENCY.md):
 *
 *   - a post-dispatch retry exists ONLY for an action whose profile admits
 *     ash_surface.idempotency/1, and only through the explicit
 *     client.retryUnknown(...) call -- never automatically;
 *   - the idempotency key is validated/derived, stable across the retry, and
 *     bound (with the canonical request digest) into the receipt;
 *   - retryUnknown reconciles first on the ORIGINAL transport and replays
 *     ONLY on NOT_OBSERVED, on the SAME transport unless the profile admits
 *     crossTransport; COMPLETED / STILL_UNKNOWN never replay.
 *
 * The only doubles are injected transport adapters (the defined seam).
 */

const TIMEOUT = { timeout: 5000 };
const IDEM = { protocol: IDEMPOTENCY_PROTOCOL };

function contractWith(actions) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: actions.map(([id, profile]) => ({
        id,
        semanticId: null,
        authorityBoundary: null,
        doAuthority: null,
        receiptRequired: null,
        resource: "Todo",
        action: id.split(":").pop(),
        profile,
      })),
    },
  };
}

/** Adapter double: scripted invoke outcomes, recorded contexts, scripted reconcile. */
function adapter({ invokes = [], reconcile, available } = {}) {
  const state = { invokes: [], reconciles: [] };
  const a = {
    async invoke(context) {
      state.invokes.push(context);
      const step = invokes[state.invokes.length - 1] ?? { ok: { id: "ok" } };
      if (step.fail) throw step.fail;
      return step.ok;
    },
  };
  if (available !== undefined) a.available = available;
  if (reconcile) {
    a.reconcile = async (commandId) => {
      state.reconciles.push(commandId);
      const verdict = typeof reconcile === "function" ? reconcile(state.reconciles.length) : reconcile;
      return verdict;
    };
  }
  return { adapter: a, state };
}

const CREATE = "todos:Todo:create";
const input = { title: "milk" };

async function unknownReceipt(client, callOptions = {}) {
  try {
    await client.actions[CREATE].invoke(input, callOptions);
  } catch (error) {
    assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
    return error;
  }
  assert.fail("expected TRANSPORT_OUTCOME_UNKNOWN");
}

test("admitted action binds derived key + request digest into completed and unknown receipts", TIMEOUT, async () => {
  const ok = adapter({ invokes: [{ ok: { id: 1 } }, { fail: new Error("boom") }] });
  const client = createClient({
    contract: contractWith([[CREATE, { idempotency: IDEM }]]),
    transports: { http: ok.adapter },
  });

  const { receipt } = await client.actions[CREATE].invokeWithReceipt(input, { commandId: "cmd_one" });
  const key = deriveIdempotencyKey(CREATE, "cmd_one");
  assert.deepEqual(receipt.idempotency, {
    protocol: IDEMPOTENCY_PROTOCOL,
    key,
    requestDigest: computeRequestDigest(CREATE, input),
    crossTransport: false,
    dispatchedTransport: "http",
    attempt: 1,
  });
  assert.deepEqual(ok.state.invokes[0].idempotency, {
    protocol: IDEMPOTENCY_PROTOCOL,
    key,
    keyHeader: null,
    requestDigest: receipt.idempotency.requestDigest,
    attempt: 1,
  });

  const error = await unknownReceipt(client, { commandId: "cmd_two", idempotencyKey: "caller-key-0001" });
  assert.equal(error.receipt.idempotency.key, "caller-key-0001");
  assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
});

test("action without the protocol: no idempotency member, key refused pre-dispatch, retry refused", TIMEOUT, async () => {
  const a = adapter({ invokes: [{ ok: { id: 1 } }, { fail: new Error("x") }] });
  const client = createClient({ contract: contractWith([[CREATE, {}]]), transports: { http: a.adapter } });

  const { receipt } = await client.actions[CREATE].invokeWithReceipt(input);
  assert.equal("idempotency" in receipt, false);
  assert.equal("idempotency" in a.state.invokes[0], false);

  await assert.rejects(
    client.actions[CREATE].invoke(input, { idempotencyKey: "caller-key-0001" }),
    (e) => e.code === "IDEMPOTENCY_NOT_ADMITTED",
  );
  assert.equal(a.state.invokes.length, 1, "refused pre-dispatch: no second adapter call");

  const unknown = await unknownReceipt(client);
  await assert.rejects(
    client.retryUnknown(unknown, { input }),
    (e) => e instanceof SurfaceRuntimeError && e.code === "IDEMPOTENCY_NOT_ADMITTED",
  );
  assert.equal(a.state.invokes.length, 2, "no replay for a non-admitting action");
});

test("pre-dispatch refusals: bad key, bad profile, non-portable input", TIMEOUT, async () => {
  const a = adapter();
  const client = createClient({
    contract: contractWith([
      [CREATE, { idempotency: IDEM }],
      ["todos:Todo:badprofile", { idempotency: { protocol: "other/1" } }],
      ["todos:Todo:extra", { idempotency: { ...IDEM, unknown: true } }],
    ]),
    transports: { http: a.adapter },
  });

  await assert.rejects(client.actions[CREATE].invoke(input, { idempotencyKey: "short" }), (e) => e.code === "INVALID_IDEMPOTENCY_KEY");
  await assert.rejects(client.actions[CREATE].invoke({ n: 1.5 }), (e) => e.code === "IDEMPOTENCY_INPUT_NOT_PORTABLE");
  await assert.rejects(client.actions["todos:Todo:badprofile"].invoke(input), (e) => e.code === "INVALID_IDEMPOTENCY_PROFILE");
  await assert.rejects(client.actions["todos:Todo:extra"].invoke(input), (e) => e.code === "INVALID_IDEMPOTENCY_PROFILE");
  assert.equal(a.state.invokes.length, 0);
});

test("no auto-retry: a failed dispatch is attempted exactly once and never reconciled", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("net") }], reconcile: { status: "NOT_OBSERVED" } });
  const chan = adapter();
  const client = createClient({
    contract: contractWith([[CREATE, { idempotency: { ...IDEM, crossTransport: true } }]]),
    transports: { http: http.adapter, phoenix_channel: chan.adapter },
  });
  await unknownReceipt(client);
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(http.state.invokes.length, 1);
  assert.equal(http.state.reconciles.length, 0);
  assert.equal(chan.state.invokes.length, 0);
});

test("NOT_OBSERVED: reconcile on the original transport, then replay with the same command, key and transport", TIMEOUT, async () => {
  const http = adapter({
    invokes: [{ fail: new Error("net") }, { ok: { id: 9 } }],
    reconcile: { status: "NOT_OBSERVED" },
  });
  const chan = adapter();
  const client = createClient({
    contract: contractWith([[CREATE, { idempotency: IDEM }]]),
    transports: { http: http.adapter, phoenix_channel: chan.adapter },
  });

  const unknown = await unknownReceipt(client, { commandId: "cmd_stable" });
  const outcome = await client.retryUnknown(unknown, { input });

  assert.equal(outcome.status, "REPLAYED");
  assert.equal(outcome.replayed, true);
  assert.deepEqual(outcome.result, { id: 9 });
  assert.deepEqual(http.state.reconciles, ["cmd_stable"]);
  assert.equal(http.state.invokes.length, 2);
  assert.equal(http.state.invokes[1].commandId, "cmd_stable");
  assert.equal(http.state.invokes[1].idempotency.key, unknown.receipt.idempotency.key);
  assert.equal(http.state.invokes[1].idempotency.requestDigest, unknown.receipt.idempotency.requestDigest);
  assert.equal(chan.state.invokes.length, 0, "never replayed over another transport");
  assert.equal(outcome.receipt.idempotency.attempt, 2);
  assert.equal(outcome.receipt.idempotency.key, unknown.receipt.idempotency.key);
  assert.equal(outcome.receipt.commandId, "cmd_stable");
  assert.equal(outcome.receipt.dispatchState, "completed");
  assert.equal(outcome.receipt.reason, "retry_pinned_transport");
});

test("accepts the bare receipt as well as the error carrying it", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("n") }, { ok: 1 }], reconcile: { status: "NOT_OBSERVED" } });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
  const unknown = await unknownReceipt(client);
  const outcome = await client.retryUnknown(unknown.receipt, { input });
  assert.equal(outcome.status, "REPLAYED");
});

test("COMPLETED and STILL_UNKNOWN never replay", TIMEOUT, async () => {
  for (const verdict of [{ status: "COMPLETED", receipt: { id: 5 } }, { status: "STILL_UNKNOWN" }]) {
    const http = adapter({ invokes: [{ fail: new Error("n") }], reconcile: verdict });
    const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
    const unknown = await unknownReceipt(client);
    const outcome = await client.retryUnknown(unknown, { input });
    assert.equal(outcome.status, verdict.status);
    assert.equal(outcome.replayed, false);
    assert.equal(outcome.reconcile.status, verdict.status);
    assert.equal(http.state.invokes.length, 1, `${verdict.status}: no replay`);
  }
});

test("an adapter that cannot reconcile yields STILL_UNKNOWN and no replay", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("n") }] });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
  const unknown = await unknownReceipt(client);
  const outcome = await client.retryUnknown(unknown, { input });
  assert.equal(outcome.status, "STILL_UNKNOWN");
  assert.equal(outcome.reconcile.reason, "transport_reconciliation_unsupported");
  assert.equal(http.state.invokes.length, 1);
});

test("malformed reconcile reply refuses the retry (INVALID_RECONCILE_RESULT) without replay", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("n") }], reconcile: { status: "MAYBE" } });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
  const unknown = await unknownReceipt(client);
  await assert.rejects(client.retryUnknown(unknown, { input }), (e) => e.code === "INVALID_RECONCILE_RESULT");
  assert.equal(http.state.invokes.length, 1);
});

test("replay is pinned to the original transport unless crossTransport is admitted", TIMEOUT, async () => {
  // Original dispatch went over http; http then becomes unavailable.
  let httpUp = true;
  const http = adapter({
    invokes: [{ fail: new Error("n") }],
    reconcile: { status: "NOT_OBSERVED" },
    available: () => httpUp,
  });

  for (const [cross, expected] of [[false, "refused"], [true, "phoenix_channel"]]) {
    httpUp = true;
    const chan = adapter({ invokes: [{ ok: { via: "chan" } }] });
    const h = adapter({ invokes: [{ fail: new Error("n") }], reconcile: { status: "NOT_OBSERVED" }, available: () => httpUp });
    const client = createClient({
      contract: contractWith([[CREATE, { idempotency: { ...IDEM, crossTransport: cross } }]]),
      transports: { http: h.adapter, phoenix_channel: chan.adapter },
    });
    const unknown = await unknownReceipt(client);
    httpUp = false;

    if (expected === "refused") {
      await assert.rejects(client.retryUnknown(unknown, { input }), (e) => e.code === "RETRY_TRANSPORT_UNAVAILABLE");
      assert.equal(chan.state.invokes.length, 0, "cross-transport replay not admitted");
      assert.equal(h.state.reconciles.length, 0, "refused pre-dispatch, before reconcile");
    } else {
      const outcome = await client.retryUnknown(unknown, { input });
      assert.equal(outcome.status, "REPLAYED");
      assert.equal(outcome.receipt.selected, "phoenix_channel");
      assert.equal(outcome.receipt.idempotency.dispatchedTransport, "phoenix_channel");
      assert.equal(outcome.receipt.idempotency.crossTransport, true);
      assert.deepEqual(h.state.reconciles, [unknown.receipt.commandId], "reconcile is on the ORIGINAL transport");
      assert.equal(chan.state.invokes[0].idempotency.key, unknown.receipt.idempotency.key);
    }
  }
  assert.equal(http.state.invokes.length, 0);
});

test("input bound to the receipt: a different input is refused before reconcile", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("n") }], reconcile: { status: "NOT_OBSERVED" } });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
  const unknown = await unknownReceipt(client);
  await assert.rejects(client.retryUnknown(unknown, { input: { title: "OTHER" } }), (e) => e.code === "IDEMPOTENCY_DIGEST_MISMATCH");
  assert.equal(http.state.reconciles.length, 0);
  assert.equal(http.state.invokes.length, 1);
});

test("digest is over the Zod-admitted input, so the same raw input retries cleanly", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ fail: new Error("n") }, { ok: 1 }], reconcile: { status: "NOT_OBSERVED" } });
  const client = createClient({
    contract: contractWith([[CREATE, { idempotency: IDEM }]]),
    transports: { http: http.adapter },
    schemas: { [CREATE]: { input: z.object({ title: z.string().transform((s) => s.trim()) }) } },
  });
  const raw = { title: "  milk  " };
  let unknown;
  try {
    await client.actions[CREATE].invoke(raw);
  } catch (e) {
    unknown = e;
  }
  assert.equal(unknown.receipt.idempotency.requestDigest, computeRequestDigest(CREATE, { title: "milk" }));
  const outcome = await client.retryUnknown(unknown, { input: raw });
  assert.equal(outcome.status, "REPLAYED");
  assert.deepEqual(http.state.invokes[1].input, { title: "milk" });
});

test("receipt admission is fail-closed", TIMEOUT, async () => {
  const http = adapter({ invokes: [{ ok: 1 }, { fail: new Error("n") }], reconcile: { status: "NOT_OBSERVED" } });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });

  const { receipt: completed } = await client.actions[CREATE].invokeWithReceipt(input);
  const unknown = await unknownReceipt(client);
  const good = unknown.receipt;
  const refuses = async (arg, opts, code) =>
    assert.rejects(client.retryUnknown(arg, opts), (e) => e instanceof SurfaceRuntimeError && e.code === code, code);

  await refuses(good.commandId, { input }, "RETRY_REQUIRES_RECEIPT");
  await refuses(undefined, { input }, "RETRY_REQUIRES_RECEIPT");
  await refuses(completed, { input }, "RETRY_NOT_UNKNOWN");
  await refuses({ ...good, actionId: "nope" }, { input }, "UNKNOWN_ACTION");
  await refuses({ ...good, idempotency: { ...good.idempotency, key: "x" } }, { input }, "RETRY_RECEIPT_INVALID");
  await refuses({ ...good, idempotency: { ...good.idempotency, requestDigest: "ab" } }, { input }, "RETRY_RECEIPT_INVALID");
  await refuses({ ...good, idempotency: { ...good.idempotency, protocol: "x/1" } }, { input }, "RETRY_RECEIPT_INVALID");
  await refuses({ ...good, idempotency: undefined }, { input }, "RETRY_RECEIPT_INVALID");
  await refuses({ ...good, selected: "smoke_signal" }, { input }, "RETRY_RECEIPT_INVALID");
  await refuses(good, {}, "INVALID_OPTIONS");
  await refuses(good, { input, commandId: "cmd_other" }, "INVALID_OPTIONS");
  await refuses(good, { input, idempotencyKey: "another-key-1" }, "INVALID_OPTIONS");
  assert.equal(http.state.reconciles.length, 0);
  assert.equal(http.state.invokes.length, 2);
});

test("a replay that fails again is UNKNOWN again with the next attempt and stays explicit", TIMEOUT, async () => {
  const http = adapter({
    invokes: [{ fail: new Error("1") }, { fail: new Error("2") }, { ok: 3 }],
    reconcile: { status: "NOT_OBSERVED" },
  });
  const client = createClient({ contract: contractWith([[CREATE, { idempotency: IDEM }]]), transports: { http: http.adapter } });
  const first = await unknownReceipt(client, { commandId: "cmd_x" });
  const second = await client.retryUnknown(first, { input }).catch((e) => e);
  assert.equal(second.code, "TRANSPORT_OUTCOME_UNKNOWN");
  assert.equal(second.receipt.idempotency.attempt, 2);
  assert.equal(second.receipt.idempotency.key, first.receipt.idempotency.key);
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(http.state.invokes.length, 2, "no automatic third attempt");

  const third = await client.retryUnknown(second, { input });
  assert.equal(third.receipt.idempotency.attempt, 3);
  assert.equal(http.state.invokes.length, 3);
});
