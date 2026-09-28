import test from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import {
  createClient,
  IDEMPOTENCY_PROTOCOL,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Laws pinned: the opt-in onEvent hook.
 *
 *   - events are structured, frozen, and delivered synchronously in the exact
 *     dispatch order (transport.selected -> dispatch.started -> outcome);
 *   - they carry ids, codes, transports and durations ONLY -- never input or
 *     output values, messages, or idempotency keys;
 *   - a throwing (or rejecting) hook can never affect dispatch;
 *   - observing changes nothing: with and without a hook the client returns
 *     identical results.
 */

const TIMEOUT = { timeout: 5000 };
const SECRET = "SECRET-PAYLOAD-VALUE";
const CREATE = "todos:Todo:create";

function contractWith(profile = {}, id = CREATE) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id,
          semanticId: null,
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "Todo",
          action: "create",
          profile,
        },
      ],
    },
  };
}

function recorder() {
  const events = [];
  return { events, onEvent: (event) => events.push(event) };
}

const types = (events) => events.map((e) => e.type);
const strip = (event) => {
  const { durationMs, ...rest } = event;
  if (durationMs !== undefined) assert.ok(Number.isInteger(durationMs) && durationMs >= 0);
  return rest;
};

const okAdapter = (result = { data: { id: 1, note: SECRET } }, extra = {}) => ({
  async invoke() {
    return result;
  },
  ...extra,
});

test("completed path: exact sequence and fields", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  const client = createClient({ contract: contractWith(), transports: { http: okAdapter() }, onEvent });

  await client.actions[CREATE].invoke({ title: SECRET }, { commandId: "cmd_a" });

  assert.deepEqual(types(events), ["transport.selected", "dispatch.started", "dispatch.completed"]);
  assert.deepEqual(strip(events[0]), {
    type: "transport.selected",
    actionId: CREATE,
    commandId: "cmd_a",
    declared: ["http", "phoenix_channel"],
    available: ["http"],
    selected: "http",
    preferred: "http",
    reason: "preferred_available",
    dimensions: "undelegated",
  });
  assert.deepEqual(strip(events[1]), { type: "dispatch.started", actionId: CREATE, commandId: "cmd_a", transport: "http" });
  assert.deepEqual(strip(events[2]), {
    type: "dispatch.completed",
    actionId: CREATE,
    commandId: "cmd_a",
    transport: "http",
    outputValid: true,
  });
  assert.ok(events.every((e) => Object.isFrozen(e)));
});

test("privacy: no input, output, message or key values appear in any event", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  const client = createClient({
    contract: contractWith({ idempotency: { protocol: IDEMPOTENCY_PROTOCOL } }),
    transports: {
      http: {
        async invoke() {
          throw new Error(`leaky message ${SECRET}`);
        },
        async reconcile() {
          return { status: "NOT_OBSERVED", note: SECRET };
        },
      },
    },
    onEvent,
  });
  const error = await client.actions[CREATE]
    .invoke({ title: SECRET }, { idempotencyKey: "secret-key-12345" })
    .catch((e) => e);
  await client.retryUnknown(error, { input: { title: SECRET } }).catch(() => {});

  const wire = JSON.stringify(events);
  assert.ok(events.length > 5);
  assert.equal(wire.includes(SECRET), false);
  assert.equal(wire.includes("leaky message"), false);
  assert.equal(wire.includes("secret-key-12345"), false);
});

test("unknown_after_dispatch: adapter failure classified by code, never by message", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  const client = createClient({
    contract: contractWith(),
    transports: {
      http: {
        async invoke() {
          throw new Error(SECRET);
        },
      },
    },
    onEvent,
  });
  await assert.rejects(client.actions[CREATE].invoke({}, { commandId: "cmd_u" }), (e) => e.code === "TRANSPORT_OUTCOME_UNKNOWN");
  assert.deepEqual(types(events), ["transport.selected", "dispatch.started", "dispatch.unknown_after_dispatch"]);
  assert.deepEqual(strip(events[2]), {
    type: "dispatch.unknown_after_dispatch",
    actionId: CREATE,
    commandId: "cmd_u",
    transport: "http",
    cause: "ADAPTER_ERROR",
  });
});

test("timeout and post-dispatch abort carry the runtime cause code", TIMEOUT, async () => {
  const hang = { invoke: () => new Promise(() => {}) };

  const t = recorder();
  const c1 = createClient({ contract: contractWith(), transports: { http: hang }, onEvent: t.onEvent });
  await assert.rejects(c1.actions[CREATE].invoke({}, { timeoutMs: 10 }));
  assert.deepEqual(types(t.events), ["transport.selected", "dispatch.started", "dispatch.unknown_after_dispatch"]);
  assert.equal(t.events[2].cause, "DISPATCH_TIMEOUT");

  const a = recorder();
  const c2 = createClient({ contract: contractWith(), transports: { http: hang }, onEvent: a.onEvent });
  const controller = new AbortController();
  const pending = c2.actions[CREATE].invoke({}, { signal: controller.signal });
  controller.abort();
  await assert.rejects(pending);
  assert.equal(a.events.at(-1).cause, "DISPATCH_ABORTED");
});

test("pre-dispatch refusals emit exactly one refused event and no selection/dispatch", TIMEOUT, async () => {
  const cases = [
    ["INVALID_OPTIONS", (c) => c.actions[CREATE].invoke({}, { timeoutMs: -1 })],
    ["INVALID_OPTIONS", (c) => c.actions[CREATE].invoke({}, { commandId: "" })],
    ["DISPATCH_ABORTED_PRE_DISPATCH", (c) => c.actions[CREATE].invoke({}, { signal: AbortSignal.abort() })],
    ["INPUT_VALIDATION_FAILED", (c) => c.actions[CREATE].invoke({ title: 1 })],
    ["IDEMPOTENCY_NOT_ADMITTED", (c) => c.actions[CREATE].invoke({}, { idempotencyKey: "abcd-12345" })],
  ];
  for (const [code, run] of cases) {
    const { events, onEvent } = recorder();
    const client = createClient({
      contract: contractWith(),
      transports: { http: okAdapter() },
      schemas: { [CREATE]: { input: z.object({ title: z.string().optional() }) } },
      onEvent,
    });
    await assert.rejects(run(client), (e) => e.code === code);
    assert.deepEqual(events.map(strip), [{ type: "dispatch.refused_pre_dispatch", actionId: CREATE, code }]);
  }
});

test("no available transport is a pre-dispatch refusal", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  const client = createClient({ contract: contractWith(), transports: {}, onEvent });
  await assert.rejects(client.actions[CREATE].invoke({}), (e) => e.code === "UNSUPPORTED_TRANSPORT");
  assert.deepEqual(events.map(strip), [
    { type: "dispatch.refused_pre_dispatch", actionId: CREATE, code: "UNSUPPORTED_TRANSPORT" },
  ]);
});

test("transport.selected reports fallback and dimension weighing", TIMEOUT, async () => {
  const fallback = recorder();
  const c1 = createClient({
    contract: contractWith(),
    transports: { phoenix_channel: okAdapter() },
    onEvent: fallback.onEvent,
  });
  await c1.actions[CREATE].invoke({});
  assert.equal(fallback.events[0].selected, "phoenix_channel");
  assert.equal(fallback.events[0].preferred, "http");
  assert.equal(fallback.events[0].reason, "preferred_unavailable");
  assert.deepEqual(fallback.events[0].available, ["phoenix_channel"]);

  const weighed = recorder();
  const facts = { http: { cost: "high", latency: "high" }, phoenix_channel: { cost: "low", latency: "low" } };
  const c2 = createClient({
    contract: contractWith({ transportFacts: facts }),
    transports: { http: okAdapter(), phoenix_channel: okAdapter() },
    onEvent: weighed.onEvent,
  });
  await c2.actions[CREATE].invoke({});
  assert.equal(weighed.events[0].selected, "phoenix_channel");
  assert.equal(weighed.events[0].reason, "dimension_weighed");
  assert.equal(weighed.events[0].dimensions, "declared");
});

test("invalid output still reports the completed dispatch, flagged outputValid:false", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  const client = createClient({
    contract: contractWith(),
    transports: { http: okAdapter({ wrong: true }) },
    schemas: { [CREATE]: { output: z.object({ data: z.object({}) }) } },
    onEvent,
  });
  await assert.rejects(client.actions[CREATE].invoke({}), (e) => e.code === "OUTPUT_VALIDATION_FAILED");
  assert.deepEqual(types(events), ["transport.selected", "dispatch.started", "dispatch.completed"]);
  assert.equal(events[2].outputValid, false);
});

test("reconcile.result and reconcile.invalid_result", TIMEOUT, async () => {
  const { events, onEvent } = recorder();
  let reply = { status: "COMPLETED" };
  const client = createClient({
    contract: contractWith(),
    transports: { http: { ...okAdapter(), reconcile: async () => reply } },
    onEvent,
  });
  await client.reconcile("cmd_r");
  reply = { status: "MAYBE" };
  await assert.rejects(client.reconcile("cmd_r"), (e) => e.code === "INVALID_RECONCILE_RESULT");
  await client.reconcile("cmd_r", "phoenix_channel");

  assert.deepEqual(events, [
    { type: "reconcile.result", commandId: "cmd_r", transport: "http", status: "COMPLETED" },
    { type: "reconcile.invalid_result", commandId: "cmd_r", transport: "http" },
    {
      type: "reconcile.result",
      commandId: "cmd_r",
      transport: "phoenix_channel",
      status: "STILL_UNKNOWN",
      reason: "transport_reconciliation_unsupported",
    },
  ]);
});

const IDEM_PROFILE = { idempotency: { protocol: IDEMPOTENCY_PROTOCOL } };

function retryClient(verdict, invokes) {
  const { events, onEvent } = recorder();
  let n = 0;
  const client = createClient({
    contract: contractWith(IDEM_PROFILE),
    transports: {
      http: {
        async invoke() {
          const step = invokes[n];
          n += 1;
          if (step === "fail") throw new Error("net");
          return { ok: n };
        },
        async reconcile() {
          return verdict;
        },
      },
    },
    onEvent,
  });
  return { client, events };
}

test("retry path (NOT_OBSERVED): exact event sequence", TIMEOUT, async () => {
  const { client, events } = retryClient({ status: "NOT_OBSERVED" }, ["fail", "ok"]);
  const error = await client.actions[CREATE].invoke({}, { commandId: "cmd_t" }).catch((e) => e);
  events.length = 0;
  await client.retryUnknown(error, { input: {} });

  assert.deepEqual(types(events), [
    "retry.requested",
    "reconcile.result",
    "retry.replaying",
    "transport.selected",
    "dispatch.started",
    "dispatch.completed",
  ]);
  assert.deepEqual(events[0], { type: "retry.requested", actionId: CREATE, commandId: "cmd_t", transport: "http", attempt: 2 });
  assert.equal(events[1].status, "NOT_OBSERVED");
  assert.deepEqual(events[2], { type: "retry.replaying", actionId: CREATE, commandId: "cmd_t", transport: "http", attempt: 2 });
  assert.equal(events[3].reason, "retry_pinned_transport");
  assert.equal(events[4].attempt, 2);
});

test("retry path (COMPLETED / STILL_UNKNOWN): skipped, nothing dispatched", TIMEOUT, async () => {
  for (const status of ["COMPLETED", "STILL_UNKNOWN"]) {
    const { client, events } = retryClient({ status }, ["fail"]);
    const error = await client.actions[CREATE].invoke({}, { commandId: "cmd_s" }).catch((e) => e);
    events.length = 0;
    await client.retryUnknown(error, { input: {} });
    assert.deepEqual(types(events), ["retry.requested", "reconcile.result", "retry.skipped"]);
    assert.deepEqual(events[2], { type: "retry.skipped", actionId: CREATE, commandId: "cmd_s", reason: status });
  }
});

test("retry refusals emit retry.refused with the code only", TIMEOUT, async () => {
  const { client, events } = retryClient({ status: "NOT_OBSERVED" }, ["fail"]);
  const error = await client.actions[CREATE].invoke({}).catch((e) => e);
  events.length = 0;

  await assert.rejects(client.retryUnknown(error, { input: { other: 1 } }), (e) => e.code === "IDEMPOTENCY_DIGEST_MISMATCH");
  await assert.rejects(client.retryUnknown("cmd_x", { input: {} }), (e) => e.code === "RETRY_REQUIRES_RECEIPT");
  assert.deepEqual(types(events), ["retry.requested", "retry.refused", "retry.refused"]);
  assert.equal(events[1].code, "IDEMPOTENCY_DIGEST_MISMATCH");
  assert.equal(events[1].commandId, error.receipt.commandId);
  assert.deepEqual(events[2], { type: "retry.refused", actionId: null, commandId: null, code: "RETRY_REQUIRES_RECEIPT" });
});

test("a replay that fails again ends in dispatch.unknown_after_dispatch", TIMEOUT, async () => {
  const { client, events } = retryClient({ status: "NOT_OBSERVED" }, ["fail", "fail"]);
  const error = await client.actions[CREATE].invoke({}).catch((e) => e);
  events.length = 0;
  await assert.rejects(client.retryUnknown(error, { input: {} }), (e) => e.code === "TRANSPORT_OUTCOME_UNKNOWN");
  assert.deepEqual(types(events).slice(-2), ["dispatch.started", "dispatch.unknown_after_dispatch"]);
});

test("hook exceptions and rejections never affect dispatch", TIMEOUT, async () => {
  const throwing = createClient({
    contract: contractWith(),
    transports: { http: okAdapter({ data: { id: 3 } }) },
    onEvent() {
      throw new Error("hook bug");
    },
  });
  const rejecting = createClient({
    contract: contractWith(),
    transports: { http: okAdapter({ data: { id: 3 } }) },
    onEvent: async () => {
      throw new Error("async hook bug");
    },
  });
  const plain = createClient({ contract: contractWith(), transports: { http: okAdapter({ data: { id: 3 } }) } });

  const a = await throwing.actions[CREATE].invoke({});
  const b = await rejecting.actions[CREATE].invoke({});
  const c = await plain.actions[CREATE].invoke({});
  assert.deepEqual(a, c);
  assert.deepEqual(b, c);

  // Also on failure paths: the original typed error is preserved.
  const failing = createClient({
    contract: contractWith(),
    transports: {
      http: {
        async invoke() {
          throw new Error("net");
        },
      },
    },
    onEvent() {
      throw new Error("hook bug");
    },
  });
  await assert.rejects(failing.actions[CREATE].invoke({}), (e) => e.code === "TRANSPORT_OUTCOME_UNKNOWN");
  await assert.rejects(failing.actions[CREATE].invoke({}, { timeoutMs: -1 }), (e) => e.code === "INVALID_OPTIONS");
});

test("events are synchronous: the hook has seen dispatch.started before the adapter settles", TIMEOUT, async () => {
  const seen = [];
  let release;
  const client = createClient({
    contract: contractWith(),
    transports: {
      http: {
        invoke: () => new Promise((resolve) => (release = () => resolve({ ok: true }))),
      },
    },
    onEvent: (e) => seen.push(e.type),
  });
  const pending = client.actions[CREATE].invoke({});
  await Promise.resolve();
  assert.deepEqual(seen, ["transport.selected", "dispatch.started"]);
  release();
  await pending;
  assert.deepEqual(seen, ["transport.selected", "dispatch.started", "dispatch.completed"]);
});

test("onEvent must be a function", () => {
  assert.throws(
    () => createClient({ contract: contractWith(), transports: {}, onEvent: "log" }),
    (e) => e instanceof SurfaceRuntimeError && e.code === "INVALID_OPTIONS",
  );
  createClient({ contract: contractWith(), transports: {}, onEvent: null });
});
