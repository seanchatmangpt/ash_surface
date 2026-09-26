import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

// State-based tests of the runtime's receipt + reconciliation primitives.
// Classification vocabulary as implemented: COMPLETED | NOT_OBSERVED | STILL_UNKNOWN
// (STILL_UNKNOWN is the runtime's pending class). Classification is derived purely
// from observed response states; nothing is upgraded, attached, or invented.

function surfaceContract() {
  return {
    surfaceSchemaVersion: "26.9.17",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id: "Zoela.KingdomNeed#select_option",
          semanticId: "zoe:SelectOption",
          // v26.9.17 delegation: authorityBoundary/doAuthority/receiptRequired
          // surface as explicit null when not delegated.
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "Zoela.KingdomNeed",
          action: "select_option",
          profile: { transport: "http" },
        },
      ],
    },
  };
}

function clientWith(transports, prefer = "http") {
  return createClient({ contract: surfaceContract(), transports, prefer });
}

const ACTION_ID = "Zoela.KingdomNeed#select_option";

// ---------------------------------------------------------------------------
// Reconciliation classification purity
// ---------------------------------------------------------------------------

test("reconcile classifies COMPLETED purely from the transport response state and preserves the source receipt", async () => {
  const adapterReconcileResult = {
    status: "COMPLETED",
    receipt: { receiptRef: "rcpt_src_1", commandId: "cmd_seen", stateDigest: "sd_1" },
  };
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile() {
        return adapterReconcileResult;
      },
    },
  };
  const client = clientWith(transports);

  const result = await client.reconcile("cmd_seen");

  assert.equal(result.status, "COMPLETED");
  assert.equal(result.receipt.receiptRef, "rcpt_src_1");
  assert.equal(result.receipt.stateDigest, "sd_1");
  // Source refs preserved: the adapter's classification object is returned, not rebuilt.
  assert.ok(Object.is(result, adapterReconcileResult));
});

test("reconcile classifies NOT_OBSERVED from the response state without upgrading it or attaching a receipt", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile() {
        return { status: "NOT_OBSERVED" };
      },
    },
  };
  const client = clientWith(transports);

  const result = await client.reconcile("cmd_unseen");

  assert.deepEqual(result, { status: "NOT_OBSERVED" });
  assert.equal("receipt" in result, false);
});

test("reconcile passes the STILL_UNKNOWN (pending) response state through unchanged", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile() {
        return { status: "STILL_UNKNOWN" };
      },
    },
  };
  const client = clientWith(transports);

  const result = await client.reconcile("cmd_pending");

  assert.deepEqual(result, { status: "STILL_UNKNOWN" });
  assert.equal("receipt" in result, false);
});

test("reconcile follows the latest observed response state, not history: NOT_OBSERVED then COMPLETED for the same commandId", async () => {
  const observed = [
    { status: "NOT_OBSERVED" },
    { status: "COMPLETED", receipt: { receiptRef: "rcpt_late_2" } },
  ];
  let call = 0;
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile() {
        return observed[Math.min(call++, observed.length - 1)];
      },
    },
  };
  const client = clientWith(transports);

  const first = await client.reconcile("cmd_x");
  const second = await client.reconcile("cmd_x");

  assert.equal(first.status, "NOT_OBSERVED");
  assert.equal("receipt" in first, false);
  assert.equal(second.status, "COMPLETED");
  assert.equal(second.receipt.receiptRef, "rcpt_late_2");
});

test("reconcile without transport reconciliation support classifies STILL_UNKNOWN and fabricates no receipt", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      // no reconcile(): reconciliation is unsupported on this transport
    },
  };
  const client = clientWith(transports);

  const result = await client.reconcile("cmd_norecon");

  assert.deepEqual(result, {
    commandId: "cmd_norecon",
    status: "STILL_UNKNOWN",
    reason: "transport_reconciliation_unsupported",
  });
  assert.equal("receipt" in result, false);
});

test("reconcile against an unknown transport name classifies STILL_UNKNOWN and echoes the caller commandId", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
      async reconcile() {
        return { status: "COMPLETED", receipt: { receiptRef: "rcpt_http" } };
      },
    },
  };
  const client = clientWith(transports);

  const result = await client.reconcile("cmd_other", "phoenix_channel");

  assert.equal(result.status, "STILL_UNKNOWN");
  assert.equal(result.commandId, "cmd_other");
  assert.equal(result.reason, "transport_reconciliation_unsupported");
  assert.equal("receipt" in result, false);
});

// ---------------------------------------------------------------------------
// MX receipt envelope: read-only exposure of receiptRef / commandId / stateDigest
// ---------------------------------------------------------------------------

test("MX receipt envelope exposes commandId and receiptRef read-only (frozen, nested included)", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true, receiptRef: "rcpt_envelope_3" };
      },
    },
  };
  const client = clientWith(transports);

  const { receipt } = await client.actions[ACTION_ID].invokeWithReceipt(
    { needId: "n1", selectedOption: "o1" },
    { commandId: "cmd_op_42" },
  );

  assert.equal(receipt.commandId, "cmd_op_42");
  assert.equal(receipt.domainReceiptRef, "rcpt_envelope_3");
  assert.ok(Object.isFrozen(receipt));
  assert.ok(Object.isFrozen(receipt.transportReceipt));
  assert.throws(() => {
    receipt.commandId = "cmd_mutated";
  }, TypeError);
  assert.throws(() => {
    receipt.domainReceiptRef = "rcpt_mutated";
  }, TypeError);
  assert.throws(() => {
    receipt.transportReceipt.selected = "phoenix_channel";
  }, TypeError);
  assert.equal(receipt.commandId, "cmd_op_42");
});

test("the dispatched commandId is the envelope commandId; generated ids never leak into the receiptRef slot", async () => {
  let dispatchedCommandId = null;
  const transports = {
    http: {
      async invoke({ commandId }) {
        dispatchedCommandId = commandId;
        return { success: true };
      },
    },
  };
  const client = clientWith(transports);

  const { receipt } = await client.actions[ACTION_ID].invokeWithReceipt({ needId: "n1" });

  assert.equal(receipt.commandId, dispatchedCommandId);
  assert.match(dispatchedCommandId, /^cmd_/);
  assert.notEqual(receipt.domainReceiptRef, receipt.commandId);
});

test("event projection channel preserves observed stateDigest and receiptRef source refs", () => {
  const transports = { http: { async invoke() { return { success: true }; } } };
  const client = clientWith(transports);

  const received = [];
  client.events.subscribe("Zoela.KingdomNeed:need_1", (event) => received.push(event));

  const emitted = {
    eventId: "evt_1",
    sequence: 0,
    subjectRef: "Zoela.KingdomNeed:need_1",
    eventType: "option_selected",
    stateDigest: "sd_evt_9",
    receiptRef: "rcpt_evt_1",
    occurredAt: "2026-09-15T00:00:00.000Z",
  };
  client.events.emit(emitted);

  assert.equal(received.length, 1);
  assert.equal(received[0].stateDigest, "sd_evt_9");
  assert.equal(received[0].receiptRef, "rcpt_evt_1");

  // An event without an observed stateDigest is refused, not defaulted.
  assert.throws(
    () => {
      client.events.emit({
        eventId: "evt_2",
        sequence: 1,
        subjectRef: "Zoela.KingdomNeed:need_1",
        eventType: "option_selected",
        occurredAt: "2026-09-15T00:00:01.000Z",
      });
    },
    (error) => error instanceof Error,
  );
  assert.equal(received.length, 1);
});

// ---------------------------------------------------------------------------
// No primitive fabricates a receiptRef
// ---------------------------------------------------------------------------

test("a response carrying no receiptRef, receipt hash, or data id yields a null domainReceiptRef, never an invented ref", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true };
      },
    },
  };
  const client = clientWith(transports);

  const { receipt } = await client.actions[ACTION_ID].invokeWithReceipt(
    { needId: "n1" },
    { commandId: "cmd_bare_7" },
  );

  assert.equal(receipt.domainReceiptRef, null);
  assert.notEqual(receipt.domainReceiptRef, receipt.commandId);
  assert.equal(receipt.dispatchState, "completed");
  assert.equal(receipt.outcome, "SUCCESS");
});

test("domainReceiptRef follows source precedence receiptRef > receipt.hash > data.id, all witnessed", async () => {
  const responses = [
    { receiptRef: "rcpt_A", receipt: { hash: "rcpt_B" }, data: { id: "id_C" } },
    { receipt: { hash: "rcpt_B" }, data: { id: "id_C" } },
    { data: { id: "id_C" } },
  ];
  const expected = ["rcpt_A", "rcpt_B", "id_C"];
  const transports = {
    http: {
      async invoke() {
        return responses.shift();
      },
    },
  };
  const client = clientWith(transports);
  const actionClient = client.actions[ACTION_ID];

  for (const expectedRef of expected) {
    const { receipt } = await actionClient.invokeWithReceipt({ needId: "n1" });
    assert.equal(receipt.domainReceiptRef, expectedRef);
  }
});

test("a dispatch that fails after send yields an UNKNOWN_AFTER_DISPATCH receipt with a null receiptRef (no fabrication on failure)", async () => {
  const transports = {
    http: {
      async invoke() {
        throw new Error("connection reset after dispatch");
      },
    },
  };
  const client = clientWith(transports);

  await assert.rejects(
    () =>
      client.actions[ACTION_ID].invokeWithReceipt(
        { needId: "n1" },
        { commandId: "cmd_lost_5" },
      ),
    (error) => {
      assert.ok(error instanceof SurfaceRuntimeError);
      assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.receipt.commandId, "cmd_lost_5");
      assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
      assert.equal(error.receipt.outcome, "UNKNOWN_AFTER_DISPATCH");
      assert.equal(error.receipt.domainReceiptRef, null);
      assert.equal("domainReceiptRef" in error.receipt, true);
      return true;
    },
  );
});

// ---------------------------------------------------------------------------
// Composed provenance preserves source refs
// ---------------------------------------------------------------------------

test("a response-provided consequenceReceipt is preserved by reference, not rebuilt or re-identified", async () => {
  const consequenceReceipt = {
    id: "cons_7",
    sourceCommandId: "cmd_upstream",
    stateDigest: "sd_cons_7",
  };
  const transports = {
    http: {
      async invoke() {
        return { success: true, receiptRef: "rcpt_comp_1", consequenceReceipt };
      },
    },
  };
  const client = clientWith(transports);

  const { receipt } = await client.actions[ACTION_ID].invokeWithReceipt({ needId: "n1" });

  assert.deepEqual(receipt.consequenceReceipt, {
    id: "cons_7",
    sourceCommandId: "cmd_upstream",
    stateDigest: "sd_cons_7",
  });
  // Composed provenance: the source object reference itself is carried through.
  assert.ok(Object.is(receipt.consequenceReceipt, consequenceReceipt));
});

test("a response with no consequenceReceipt and no data yields a null consequenceReceipt, not a composed stand-in", async () => {
  const transports = {
    http: {
      async invoke() {
        return { success: true, receiptRef: "rcpt_nocomp_2" };
      },
    },
  };
  const client = clientWith(transports);

  const { receipt } = await client.actions[ACTION_ID].invokeWithReceipt({ needId: "n1" });

  assert.equal(receipt.consequenceReceipt, null);
  assert.equal(receipt.domainReceiptRef, "rcpt_nocomp_2");
});
