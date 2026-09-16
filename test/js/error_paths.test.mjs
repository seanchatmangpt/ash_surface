import test from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

// Failure-taxonomy tests for the ash_surface runtime. Every async test carries
// a timeout so a hung dispatch/reconcile fails loudly instead of stalling CI.

const TIMEOUT = { timeout: 2000 };

function contract(actions, overrides = {}) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions },
    ...overrides,
  };
}

function action(overrides = {}) {
  return {
    id: "todos:Todo:create",
    resource: "Todo",
    action: "create",
    profile: {},
    ...overrides,
  };
}

function typed(code) {
  return (error) =>
    error instanceof SurfaceRuntimeError &&
    error.name === "SurfaceRuntimeError" &&
    error.code === code;
}

// ---------------------------------------------------------------------------
// Constructor validation: options, contract shape, action descriptors.
// ---------------------------------------------------------------------------

test("refuses createClient with no options", () => {
  assert.throws(() => createClient(), typed("INVALID_OPTIONS"));
});

test("refuses createClient with null options", () => {
  assert.throws(() => createClient(null), typed("INVALID_OPTIONS"));
});

test("refuses a missing contract with typed error and zod issues", () => {
  assert.throws(
    () => createClient({ transports: {} }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "INVALID_SURFACE_CONTRACT" &&
      Array.isArray(error.issues) &&
      error.issues.length > 0,
  );
});

test("refuses a malformed action descriptor (empty id)", () => {
  assert.throws(
    () => createClient({ contract: contract([action({ id: "" })]), transports: {} }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "INVALID_SURFACE_CONTRACT" &&
      Array.isArray(error.issues),
  );
});

test("refuses an action descriptor missing resource and action name", () => {
  assert.throws(
    () => createClient({ contract: contract([{ id: "broken" }]), transports: {} }),
    (error) => error.code === "INVALID_SURFACE_CONTRACT",
  );
});

test("refuses a non-array actions surface", () => {
  assert.throws(
    () =>
      createClient({
        contract: contract([], { surface: { profile: {}, actions: "not-an-array" } }),
        transports: {},
      }),
    (error) => error.code === "INVALID_SURFACE_CONTRACT",
  );
});

test("refuses duplicate action ids", () => {
  assert.throws(
    () => createClient({ contract: contract([action(), action()]), transports: {} }),
    typed("DUPLICATE_ACTION_ID"),
  );
});

test("refuses an unknown preferred transport", () => {
  assert.throws(
    () => createClient({ contract: contract([action()]), transports: {}, prefer: "grpc" }),
    typed("UNKNOWN_TRANSPORT"),
  );
});

test("refuses transports of the wrong type", () => {
  assert.throws(
    () => createClient({ contract: contract([action()]), transports: "nope" }),
    typed("INVALID_TRANSPORTS"),
  );
});

test("refuses unknown transport adapter keys", () => {
  assert.throws(
    () =>
      createClient({
        contract: contract([action()]),
        transports: { grpc: { invoke: async () => ({}) } },
      }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "UNKNOWN_TRANSPORT" &&
      error.message.includes("grpc"),
  );
});

// ---------------------------------------------------------------------------
// Dispatch: missing / unavailable adapters must produce typed pre-dispatch
// errors (never a hang, never a silent success).
// ---------------------------------------------------------------------------

test("invoke with no adapter at all rejects UNSUPPORTED_TRANSPORT with a not_dispatched receipt", TIMEOUT, async () => {
  const client = createClient({ contract: contract([action()]), transports: {} });
  await assert.rejects(
    client.actions["todos:Todo:create"].invokeWithReceipt({ title: "x" }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "UNSUPPORTED_TRANSPORT" &&
      error.receipt.dispatchState === "not_dispatched" &&
      error.receipt.selected === null &&
      error.receipt.reason === "no_available_transport",
  );
});

test("invoke with an adapter lacking an invoke function rejects UNSUPPORTED_TRANSPORT", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: { http: { reconcile: async () => ({ status: "NOT_OBSERVED" }) } },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: "x" }),
    typed("UNSUPPORTED_TRANSPORT"),
  );
});

test("invoke against an adapter reporting available=false rejects UNSUPPORTED_TRANSPORT", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: { http: { invoke: async () => ({}), available: false } },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: "x" }),
    typed("UNSUPPORTED_TRANSPORT"),
  );
});

test("invoke with an unknown transport projection rejects UNKNOWN_TRANSPORT", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action({ profile: { transport: "carrier_pigeon" } })]),
    transports: { http: { invoke: async () => ({}) } },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: "x" }),
    typed("UNKNOWN_TRANSPORT"),
  );
});

// ---------------------------------------------------------------------------
// Dispatch: throwing adapters must surface TRANSPORT_OUTCOME_UNKNOWN with the
// original cause and an unknown_after_dispatch receipt.
// ---------------------------------------------------------------------------

test("sync-throwing adapter rejects TRANSPORT_OUTCOME_UNKNOWN preserving cause and commandId", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: {
      http: {
        invoke() {
          throw new Error("sync boom");
        },
      },
    },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invokeWithReceipt({ title: "x" }, { commandId: "cmd_fixed" }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "TRANSPORT_OUTCOME_UNKNOWN" &&
      error.cause instanceof Error &&
      error.cause.message === "sync boom" &&
      error.receipt.commandId === "cmd_fixed" &&
      error.receipt.dispatchState === "unknown_after_dispatch" &&
      error.receipt.outcome === "UNKNOWN_AFTER_DISPATCH" &&
      error.receipt.transportReceipt.selected === "http",
  );
});

test("async-rejecting adapter rejects TRANSPORT_OUTCOME_UNKNOWN reachable via plain await", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: {
      http: {
        invoke: async () => {
          throw new Error("async boom");
        },
      },
    },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: "x" }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "TRANSPORT_OUTCOME_UNKNOWN" &&
      error.cause.message === "async boom",
  );
});

// ---------------------------------------------------------------------------
// Schema admission failures propagate with typed shapes and skip/keep receipts.
// ---------------------------------------------------------------------------

test("input schema failure rejects INPUT_VALIDATION_FAILED without dispatching", TIMEOUT, async () => {
  let dispatched = 0;
  const client = createClient({
    contract: contract([action()]),
    transports: {
      http: {
        invoke: async () => {
          dispatched += 1;
          return {};
        },
      },
    },
    schemas: { "todos:Todo:create": { input: z.object({ title: z.string() }) } },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invoke({ title: 42 }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "INPUT_VALIDATION_FAILED" &&
      error.cause instanceof z.ZodError,
  );
  assert.equal(dispatched, 0);
});

test("output schema failure rejects OUTPUT_VALIDATION_FAILED with a completed dispatch receipt", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: { http: { invoke: async () => ({ nope: true }) } },
    schemas: { "todos:Todo:create": { output: z.object({ data: z.unknown() }) } },
  });
  await assert.rejects(
    client.actions["todos:Todo:create"].invokeWithReceipt({ title: "x" }, { commandId: "cmd_out" }),
    (error) =>
      error instanceof SurfaceRuntimeError &&
      error.code === "OUTPUT_VALIDATION_FAILED" &&
      error.cause instanceof z.ZodError &&
      error.receipt.commandId === "cmd_out" &&
      error.receipt.dispatchState === "completed",
  );
});

// ---------------------------------------------------------------------------
// Reconcile on unknown commands per the runtime contract: no reconciling
// adapter resolves STILL_UNKNOWN/transport_reconciliation_unsupported; a
// reconciling adapter's NOT_OBSERVED verdict (or typed rejection) is surfaced
// verbatim to the awaiting caller.
// ---------------------------------------------------------------------------

test("reconcile without adapter support resolves STILL_UNKNOWN with transport_reconciliation_unsupported", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: { http: { invoke: async () => ({}) } },
  });
  const verdict = await client.reconcile("cmd_never_seen");
  assert.deepEqual(verdict, {
    commandId: "cmd_never_seen",
    status: "STILL_UNKNOWN",
    reason: "transport_reconciliation_unsupported",
  });
});

test("reconcile with no transports at all still resolves STILL_UNKNOWN instead of throwing", TIMEOUT, async () => {
  const client = createClient({ contract: contract([action()]), transports: {} });
  const verdict = await client.reconcile("cmd_orphan", "phoenix_channel");
  assert.equal(verdict.status, "STILL_UNKNOWN");
  assert.equal(verdict.reason, "transport_reconciliation_unsupported");
});

test("reconcile surfaces the adapter's NOT_OBSERVED verdict for an unknown command", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: {
      http: {
        invoke: async () => ({}),
        reconcile: async (commandId) => ({ status: "NOT_OBSERVED", commandId }),
      },
    },
  });
  const verdict = await client.reconcile("cmd_gone");
  assert.equal(verdict.status, "NOT_OBSERVED");
  assert.equal(verdict.commandId, "cmd_gone");
});

test("reconcile propagates a typed adapter rejection to the awaiting caller", TIMEOUT, async () => {
  const client = createClient({
    contract: contract([action()]),
    transports: {
      http: {
        invoke: async () => ({}),
        reconcile: async () => {
          throw new SurfaceRuntimeError(
            "RECONCILE_REFUSED_NO_AUTHORITY",
            "no valid authority presented",
          );
        },
      },
    },
  });
  await assert.rejects(client.reconcile("cmd_auth"), typed("RECONCILE_REFUSED_NO_AUTHORITY"));
});
