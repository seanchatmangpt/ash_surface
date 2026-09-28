import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  reconcileResultSchema,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Chicago-school, state-based hardening tests for the shipped JS runtime:
 *
 *   1. prototype-pollution closure of the action/resource namespaces
 *   2. opt-in dispatch deadline + abort signal -> UNKNOWN_AFTER_DISPATCH,
 *      never a cross-transport replay (AGENTS.md transport law)
 *   3. Zod boundary on the adapter's reconcile verdict
 *   4. default commandId entropy (crypto.randomUUID)
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

test("an already-aborted signal settles UNKNOWN_AFTER_DISPATCH once dispatched", TIMEOUT, async () => {
  const { client, http, channel } = dualTransportClient(neverSettles);

  await assert.rejects(
    client.actions["todos:Todo:create"].invoke(
      {},
      { signal: AbortSignal.abort(), commandId: "cmd_pre_aborted" },
    ),
    assertUnknownAfterDispatch("DISPATCH_ABORTED", "cmd_pre_aborted"),
  );
  assert.equal(http.invoke, 1);
  assert.equal(channel.invoke, 0);
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
