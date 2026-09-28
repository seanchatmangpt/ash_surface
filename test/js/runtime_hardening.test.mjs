import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  reconcileResultSchema,
  VOCABULARY,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Chicago-school, state-based hardening tests for the shipped JS runtime:
 *
 *   1. prototype-pollution closure of the action/resource namespaces
 *   2. opt-in dispatch deadline + abort signal -> UNKNOWN_AFTER_DISPATCH,
 *      never a cross-transport replay (AGENTS.md transport law)
 *   3. Zod boundary on the adapter's reconcile verdict
 *   4. default commandId entropy (crypto.randomUUID, with never-throw fallbacks)
 *   5. pre-dispatch abort refusal, own-property transports, options admission
 *
 * The only doubles are injected transport adapters (the defined seam); they
 * record call counts and the assertions read that state and the real
 * client's returns.
 */

// Every test carries a timeout so a regression to a hung dispatch fails
// loudly instead of stalling the suite.
const TIMEOUT = { timeout: 5000 };

function actionRow(id, resource, name, profile = {}) {
  return {
    id,
    semanticId: null,
    authorityBoundary: null,
    doAuthority: null,
    receiptRequired: null,
    resource,
    action: name,
    profile,
  };
}

function contract(actions) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions },
  };
}

function countingAdapter(invoke) {
  const calls = { invoke: 0, contexts: [] };
  return {
    calls,
    adapter: {
      invoke(context) {
        calls.invoke += 1;
        calls.contexts.push(context);
        return invoke(context);
      },
    },
  };
}

const typed = (code) => (error) => {
  assert.ok(error instanceof SurfaceRuntimeError, `expected SurfaceRuntimeError, got ${error}`);
  assert.equal(error.code, code);
  return true;
};

// ---------------------------------------------------------------------------
// 1. Prototype pollution
// ---------------------------------------------------------------------------

const HOSTILE_ACTIONS = [
  actionRow("isAdmin", "__proto__", "isAdmin"),
  actionRow("toString", "constructor", "toString"),
  actionRow("constructor", "Todo", "constructor"),
  actionRow("__proto__", "Todo", "__proto__"),
  actionRow("hasOwnProperty", "Todo", "hasOwnProperty"),
];

test("building a client from __proto__/constructor ids leaves Object.prototype untouched", TIMEOUT, () => {
  const protoKeysBefore = Reflect.ownKeys(Object.prototype);

  const client = createClient({
    contract: contract(HOSTILE_ACTIONS),
    transports: { http: { invoke: async () => ({}) } },
  });

  assert.deepEqual(Reflect.ownKeys(Object.prototype), protoKeysBefore);
  assert.equal(({}).isAdmin, undefined);
  assert.equal(Object.prototype.isAdmin, undefined);
  assert.equal(typeof ({}).toString, "function");
  assert.equal(({}).toString(), "[object Object]");

  // Every hostile id is an ordinary own key on the null-prototype record.
  assert.equal(Object.getPrototypeOf(client.actions), null);
  assert.deepEqual(
    Object.keys(client.actions).sort(),
    ["__proto__", "constructor", "hasOwnProperty", "isAdmin", "toString"],
  );
  assert.equal(client.resources.__proto__.isAdmin.id, "isAdmin");
  assert.equal(client.resources.constructor.toString.id, "toString");
  assert.equal(client.resources.Todo.constructor.id, "constructor");
  assert.equal(client.resources.Todo.__proto__.id, "__proto__");
  assert.equal(Object.getPrototypeOf(client.resources.Todo), null);
});

test('a resource named "__proto__" with action "isAdmin" never writes onto Object.prototype', TIMEOUT, () => {
  const protoKeysBefore = Reflect.ownKeys(Object.prototype);
  try {
    const client = createClient({
      contract: contract([actionRow("Evil:isAdmin", "__proto__", "isAdmin")]),
      transports: { http: { invoke: async () => ({}) } },
    });

    assert.equal(({}).isAdmin, undefined);
    assert.equal(Object.hasOwn(Object.prototype, "isAdmin"), false);
    assert.deepEqual(Reflect.ownKeys(Object.prototype), protoKeysBefore);
    assert.equal(client.resources.__proto__.isAdmin.id, "Evil:isAdmin");
  } finally {
    // Keep a regression from cascading into the rest of the process.
    delete Object.prototype.isAdmin;
  }
});

test("ids named after Object.prototype members are not refused as DUPLICATE_ACTION_ID", TIMEOUT, () => {
  for (const id of ["toString", "constructor", "__proto__", "valueOf"]) {
    const client = createClient({
      contract: contract([actionRow(id, "Todo", "run")]),
      transports: { http: { invoke: async () => ({}) } },
    });
    assert.equal(client.actions[id].id, id);
  }

  // A genuine duplicate is still refused.
  assert.throws(
    () =>
      createClient({
        contract: contract([actionRow("toString", "A", "x"), actionRow("toString", "B", "y")]),
        transports: { http: { invoke: async () => ({}) } },
      }),
    typed("DUPLICATE_ACTION_ID"),
  );
});

test("hostile ids dispatch as ordinary actions with their own identity", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async ({ action }) => ({ ran: action.id }));
  const client = createClient({ contract: contract(HOSTILE_ACTIONS), transports: { http: adapter } });

  assert.deepEqual(await client.actions["__proto__"].invoke({}), { ran: "__proto__" });
  assert.deepEqual(await client.resources.__proto__.isAdmin.invoke({}), { ran: "isAdmin" });
  const { receipt } = await client.get("constructor").invokeWithReceipt({});
  assert.equal(receipt.actionId, "constructor");
  assert.equal(receipt.outcome, "SUCCESS");
  assert.equal(client.inspect("toString").id, "toString");
  assert.equal(calls.invoke, 3);
});

test("get/inspect never resolve inherited Object.prototype names", TIMEOUT, () => {
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: { invoke: async () => ({}) } },
  });

  for (const name of ["constructor", "toString", "hasOwnProperty", "__proto__", "valueOf"]) {
    assert.equal(client.get(name), null, `get(${name})`);
    assert.equal(client.actions[name], undefined, `actions[${name}]`);
    assert.throws(() => client.inspect(name), typed("UNKNOWN_ACTION"), `inspect(${name})`);
  }
  assert.equal(client.resources.constructor, undefined);
  assert.equal(client.resources.Todo.toString, undefined);
});

test("action schemas are looked up by own key only", TIMEOUT, async () => {
  // schemas is a plain object: schemas["constructor"] would be Object.
  const { adapter } = countingAdapter(async () => ({ ok: true }));
  const client = createClient({
    contract: contract([actionRow("constructor", "Todo", "constructor")]),
    transports: { http: adapter },
    schemas: {},
  });
  assert.deepEqual(await client.actions.constructor.invoke({ any: 1 }), { ok: true });
});

// ---------------------------------------------------------------------------
// 2. Dispatch deadline + abort -> UNKNOWN_AFTER_DISPATCH, no replay
// ---------------------------------------------------------------------------

function dualTransportClient(httpInvoke) {
  const http = countingAdapter(httpInvoke);
  const channel = countingAdapter(async () => ({ via: "phoenix_channel" }));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
    prefer: "http",
  });
  return { client, http: http.calls, channel: channel.calls };
}

const neverSettles = () => new Promise(() => {});

function assertUnknownAfterDispatch(causeCode, commandId) {
  return (error) => {
    typed("TRANSPORT_OUTCOME_UNKNOWN")(error);
    assert.equal(error.cause.code, causeCode);
    assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
    assert.equal(error.receipt.outcome, "UNKNOWN_AFTER_DISPATCH");
    assert.equal(error.receipt.selected, "http");
    assert.equal(error.receipt.fallback, "pre_dispatch_only");
    assert.equal(error.receipt.commandId, commandId);
    return true;
  };
}

test("a never-settling adapter under timeoutMs settles UNKNOWN_AFTER_DISPATCH without replay", TIMEOUT, async () => {
  const { client, http, channel } = dualTransportClient(neverSettles);

  await assert.rejects(
    client.actions["todos:Todo:create"].invokeWithReceipt({}, { timeoutMs: 20, commandId: "cmd_deadline" }),
    assertUnknownAfterDispatch("DISPATCH_TIMEOUT", "cmd_deadline"),
  );

  assert.equal(http.invoke, 1);
  assert.equal(channel.invoke, 0);
});

test("aborting the signal after dispatch settles UNKNOWN_AFTER_DISPATCH without replay", TIMEOUT, async () => {
  const { client, http, channel } = dualTransportClient(neverSettles);
  const controller = new AbortController();

  const pending = client.actions["todos:Todo:create"].invoke(
    {},
    { signal: controller.signal, commandId: "cmd_abort" },
  );
  controller.abort(new Error("operator cancelled"));

  await assert.rejects(pending, (error) => {
    assertUnknownAfterDispatch("DISPATCH_ABORTED", "cmd_abort")(error);
    assert.equal(error.cause.cause.message, "operator cancelled");
    return true;
  });
  assert.equal(http.invoke, 1);
  assert.equal(http.contexts[0].signal, controller.signal);
  assert.equal(channel.invoke, 0);
});

test("an already-aborted signal is a typed pre-dispatch refusal with no adapter call", TIMEOUT, async () => {
  const { client, http, channel } = dualTransportClient(neverSettles);

  await assert.rejects(
    client.actions["todos:Todo:create"].invoke(
      {},
      { signal: AbortSignal.abort(new Error("early")), commandId: "cmd_pre_aborted" },
    ),
    (error) => {
      typed("DISPATCH_ABORTED_PRE_DISPATCH")(error);
      assert.equal(error.receipt, null);
      assert.notEqual(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.cause.message, "early");
      return true;
    },
  );
  assert.equal(http.invoke, 0);
  assert.equal(channel.invoke, 0);
});

test("an already-aborted signal makes no adapter call on any transport", TIMEOUT, async () => {
  for (const prefer of ["http", "phoenix_channel"]) {
    const http = countingAdapter(async () => ({}));
    const channel = countingAdapter(async () => ({}));
    const client = createClient({
      contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
      transports: { http: http.adapter, phoenix_channel: channel.adapter },
      prefer,
    });
    await assert.rejects(
      client.actions["todos:Todo:create"].invokeWithReceipt({}, { signal: AbortSignal.abort() }),
      typed("DISPATCH_ABORTED_PRE_DISPATCH"),
    );
    assert.equal(http.calls.invoke, 0, prefer);
    assert.equal(channel.calls.invoke, 0, prefer);
  }
});

test("a fast adapter under a timeout succeeds and leaves no pending timer or listener", TIMEOUT, async () => {
  const { client, http, channel } = dualTransportClient(async () => ({ data: { id: "todo_1" } }));
  const controller = new AbortController();
  const handlesBefore = process.getActiveResourcesInfo().filter((kind) => kind === "Timeout").length;

  const { result, receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt(
    {},
    { timeoutMs: 60_000, signal: controller.signal },
  );

  assert.deepEqual(result, { data: { id: "todo_1" } });
  assert.equal(receipt.outcome, "SUCCESS");
  assert.equal(receipt.dispatchState, "completed");
  const handlesAfter = process.getActiveResourcesInfo().filter((kind) => kind === "Timeout").length;
  assert.equal(handlesAfter, handlesBefore, "the 60s dispatch timer must be cleared on settlement");

  // A late abort after settlement changes nothing (listener was removed).
  controller.abort();
  assert.equal(http.invoke, 1);
  assert.equal(channel.invoke, 0);
});

test("an adapter rejection under a timeout keeps its own cause and clears the timer", TIMEOUT, async () => {
  const boom = new Error("socket closed");
  const { client, channel } = dualTransportClient(async () => {
    throw boom;
  });
  const handlesBefore = process.getActiveResourcesInfo().filter((kind) => kind === "Timeout").length;

  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({}, { timeoutMs: 60_000 }),
    (error) => {
      typed("TRANSPORT_OUTCOME_UNKNOWN")(error);
      assert.equal(error.cause, boom);
      return true;
    },
  );
  const handlesAfter = process.getActiveResourcesInfo().filter((kind) => kind === "Timeout").length;
  assert.equal(handlesAfter, handlesBefore);
  assert.equal(channel.invoke, 0);
});

test("an invalid timeoutMs is refused before dispatch", TIMEOUT, async () => {
  for (const timeoutMs of [0, -5, Number.NaN, Infinity, "100"]) {
    const { client, http, channel } = dualTransportClient(async () => ({}));
    await assert.rejects(
      client.actions["todos:Todo:create"].invoke({}, { timeoutMs }),
      typed("INVALID_OPTIONS"),
    );
    assert.equal(http.invoke, 0, `timeoutMs=${String(timeoutMs)} must not dispatch`);
    assert.equal(channel.invoke, 0);
  }
});

// ---------------------------------------------------------------------------
// 3. reconcile verdict boundary
// ---------------------------------------------------------------------------

function reconcilingClient(verdict) {
  return createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: {
      http: { invoke: async () => ({}), reconcile: async () => verdict },
    },
  });
}

test("reconcile admits each documented status and returns the adapter's object", TIMEOUT, async () => {
  for (const status of ["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]) {
    const verdict = { status, receipt: { receiptRef: "rcpt_1" } };
    assert.ok(Object.is(await reconcilingClient(verdict).reconcile("cmd_r"), verdict));
  }
});

test("reconcile turns a malformed adapter reply into INVALID_RECONCILE_RESULT", TIMEOUT, async () => {
  for (const verdict of [undefined, null, "COMPLETED", {}, { status: "DONE" }, { status: 1 }]) {
    await assert.rejects(reconcilingClient(verdict).reconcile("cmd_bad"), (error) => {
      typed("INVALID_RECONCILE_RESULT")(error);
      assert.ok(Array.isArray(error.issues) && error.issues.length > 0);
      return true;
    });
  }
  assert.equal(reconcileResultSchema.safeParse({ status: "SUCCESS" }).success, false);
});

test("reconcile with an inherited transport name reports unsupported, not a crash", TIMEOUT, async () => {
  const client = reconcilingClient({ status: "COMPLETED" });
  const verdict = await client.reconcile("cmd_proto", "constructor");
  assert.deepEqual(verdict, {
    commandId: "cmd_proto",
    status: "STILL_UNKNOWN",
    reason: "transport_reconciliation_unsupported",
  });
});

// ---------------------------------------------------------------------------
// 4. default commandId
// ---------------------------------------------------------------------------

test("default commandIds are cmd_-prefixed UUIDs and unique across calls", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async () => ({}));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: adapter },
  });

  const ids = new Set();
  for (let i = 0; i < 200; i += 1) {
    const { receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt({});
    assert.match(
      receipt.commandId,
      /^cmd_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    assert.equal(calls.contexts[i].commandId, receipt.commandId);
    ids.add(receipt.commandId);
  }
  assert.equal(ids.size, 200);
});

test("a caller-supplied commandId is preserved verbatim", TIMEOUT, async () => {
  const { adapter } = countingAdapter(async () => ({}));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: adapter },
  });
  const { receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt(
    {},
    { commandId: "cmd_caller" },
  );
  assert.equal(receipt.commandId, "cmd_caller");
});

// ---------------------------------------------------------------------------
// 5. commandId generation across runtimes (never throws)
// ---------------------------------------------------------------------------

async function withCrypto(replacement, fn) {
  const original = Object.getOwnPropertyDescriptor(globalThis, "crypto");
  Object.defineProperty(globalThis, "crypto", {
    value: replacement,
    configurable: true,
    writable: true,
    enumerable: original ? original.enumerable : false,
  });
  try {
    return await fn();
  } finally {
    if (original) Object.defineProperty(globalThis, "crypto", original);
    else delete globalThis.crypto;
  }
}

async function collectIds(n) {
  const { adapter } = countingAdapter(async () => ({}));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: adapter },
  });
  const ids = new Set();
  for (let i = 0; i < n; i += 1) {
    const { receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt({});
    assert.match(receipt.commandId, /^cmd_/);
    ids.add(receipt.commandId);
  }
  return ids;
}

test("commandId works without crypto.randomUUID (getRandomValues v4 path)", TIMEOUT, async () => {
  const real = globalThis.crypto;
  const ids = await withCrypto({ getRandomValues: (a) => real.getRandomValues(a) }, () => collectIds(200));
  assert.equal(ids.size, 200);
  for (const id of ids) {
    assert.match(id, /^cmd_[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  }
});

test("commandId works with no crypto at all (Hermes / RN fallback)", TIMEOUT, async () => {
  for (const replacement of [undefined, {}]) {
    const ids = await withCrypto(replacement, () => collectIds(200));
    assert.equal(ids.size, 200);
  }
});

test("commandId survives a throwing crypto", TIMEOUT, async () => {
  const boom = () => {
    throw new Error("no entropy");
  };
  const ids = await withCrypto({ randomUUID: boom, getRandomValues: boom }, () => collectIds(200));
  assert.equal(ids.size, 200);
});

test("commandId works with native randomUUID (unchanged path) and restores crypto", TIMEOUT, async () => {
  const before = Object.getOwnPropertyDescriptor(globalThis, "crypto");
  assert.equal((await collectIds(200)).size, 200);
  await withCrypto(undefined, () => collectIds(1));
  const after = Object.getOwnPropertyDescriptor(globalThis, "crypto");
  assert.equal(after?.get, before?.get);
  assert.equal(after?.value, before?.value);
});

// ---------------------------------------------------------------------------
// 6. own-property transport lookup, one rule everywhere
// ---------------------------------------------------------------------------

test("an inherited-only transport is absent for inspect, invoke and reconcile", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async () => ({}));
  adapter.reconcile = async () => ({ status: "COMPLETED" });
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: Object.create({ http: adapter }),
  });

  assert.throws(() => client.inspect("todos:Todo:create"), typed("UNSUPPORTED_TRANSPORT"));
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({}),
    typed("UNSUPPORTED_TRANSPORT"),
  );
  assert.equal(calls.invoke, 0);
  assert.deepEqual(await client.reconcile("cmd_x", "http"), {
    commandId: "cmd_x",
    status: "STILL_UNKNOWN",
    reason: "transport_reconciliation_unsupported",
  });
});

test("an own transport on a prototype-bearing object still works", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async () => ({ ok: 1 }));
  const transports = Object.create({ inherited: true });
  transports.http = adapter;
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports,
  });
  assert.deepEqual(await client.actions["todos:Todo:create"].invoke({}), { ok: 1 });
  assert.equal(calls.invoke, 1);
});

// ---------------------------------------------------------------------------
// 7. call options normalization
// ---------------------------------------------------------------------------

test("invoke(input, null) behaves like no options", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async () => ({ ok: 1 }));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: adapter },
  });
  assert.deepEqual(await client.actions["todos:Todo:create"].invoke({}, null), { ok: 1 });
  const { receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt({}, null);
  assert.match(receipt.commandId, /^cmd_/);
  assert.equal(calls.invoke, 2);
});

test("invalid commandId is INVALID_OPTIONS before dispatch", TIMEOUT, async () => {
  const { adapter, calls } = countingAdapter(async () => ({}));
  const client = createClient({
    contract: contract([actionRow("todos:Todo:create", "Todo", "create")]),
    transports: { http: adapter },
  });
  for (const commandId of ["", 0, 42, {}, false, []]) {
    await assert.rejects(
      client.actions["todos:Todo:create"].invoke({}, { commandId }),
      typed("INVALID_OPTIONS"),
      String(commandId),
    );
  }
  assert.equal(calls.invoke, 0);
  // undefined/null mean "generate".
  for (const commandId of [undefined, null]) {
    const { receipt } = await client.actions["todos:Todo:create"].invokeWithReceipt({}, { commandId });
    assert.match(receipt.commandId, /^cmd_/);
  }
});

test("VOCABULARY is one frozen record built from the runtime's own constants", TIMEOUT, () => {
  assert.equal(Object.isFrozen(VOCABULARY), true);
  assert.equal(VOCABULARY.refusalPrefix, "REFUSED_");
  assert.deepEqual(VOCABULARY.reconcileStatuses, ["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]);
  assert.deepEqual(VOCABULARY.knownTransports, ["http", "phoenix_channel"]);
  assert.deepEqual(VOCABULARY.dimensionClasses, ["low", "medium", "high"]);
  assert.deepEqual(VOCABULARY.dimensions, ["cost", "latency", "privacy"]);
  assert.equal(VOCABULARY.digestHexLength, 64);
  assert.deepEqual(VOCABULARY.dispatchOutcomes, ["SUCCESS", "UNKNOWN_AFTER_DISPATCH"]);
  assert.deepEqual(VOCABULARY.dispatchStates, ["not_dispatched", "completed", "unknown_after_dispatch"]);
  assert.equal(VOCABULARY.idempotencyProtocol, "ash_surface.idempotency/1");
  for (const value of Object.values(VOCABULARY)) {
    if (Array.isArray(value)) assert.equal(Object.isFrozen(value), true);
  }
  // The exported vocabulary IS the boundary: reconcile status enum follows it.
  for (const status of VOCABULARY.reconcileStatuses) {
    assert.equal(reconcileResultSchema.safeParse({ status }).success, true);
  }
  assert.equal(reconcileResultSchema.safeParse({ status: "MAYBE" }).success, false);
});
