import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * JS twin parity table for the v26.9.17 selection calculus
 * (chicago-select-frontier-030) — each row mirrors a row of
 * test/ash_surface/transport_calculus_tables_test.exs state-for-state:
 * same declared/available/preferred/facts inputs, same observable decision
 * (selected, reason, dimensions, frontier).
 *
 * The real runtime is exercised through the public client surface only
 * (inspect / invokeWithReceipt); fake adapters are the injected seam the
 * law itself defines (environment availability), never doubles of the
 * unit under test.
 */

function parityContract(transportFacts) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id: "todos:Todo:create",
          semanticId: null,
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "Todo",
          action: "create",
          // "auto" declares ["http", "phoenix_channel"] in that order — the
          // declared order the tie-break falls back to.
          profile: transportFacts ? { transportFacts } : {},
        },
      ],
    },
  };
}

function fakeTransport() {
  return {
    adapter: {
      async invoke() {
        return { success: true, data: { id: "row_1" } };
      },
    },
    calls: { invoke: 0 },
  };
}

function bothAdapters() {
  const http = fakeTransport();
  const channel = fakeTransport();
  return {
    http,
    channel,
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
  };
}

function decisionFor(transportFacts, { prefer, transports } = {}) {
  const client = createClient({
    contract: parityContract(transportFacts),
    transports: transports ?? bothAdapters().transports,
    prefer,
  });

  return client.inspect("todos:Todo:create").decision;
}

test("C1/C2 parity: absent facts are undelegated, the frontier mirrors availability, legacy preference wins", () => {
  const decision = decisionFor(undefined);

  assert.equal(decision.dimensions, "undelegated");
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_available");
  assert.deepEqual(decision.frontier, ["http", "phoenix_channel"]);
  assert.deepEqual(decision.available, ["http", "phoenix_channel"]);
});

test("C3 parity: empty-map facts fold to declared order exactly as legacy", () => {
  const { transports } = bothAdapters();
  const decision = decisionFor({}, { prefer: "phoenix_channel", transports: { http: transports.http } });

  assert.equal(decision.dimensions, "undelegated");
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_unavailable");
  assert.deepEqual(decision.frontier, ["http"]);
});

test("C4 parity: null-valued facts are not delegation — the legacy law runs unchanged", () => {
  const decision = decisionFor({ http: { cost: null }, phoenix_channel: { latency: null } });

  assert.equal(decision.dimensions, "undelegated");
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_available");
  assert.deepEqual(decision.frontier, ["http", "phoenix_channel"]);
});

test("A1 parity: a preference tied on the only declared axis stays on the frontier and wins", () => {
  const decision = decisionFor(
    { http: { cost: "low" }, phoenix_channel: { cost: "low" } },
    { prefer: "phoenix_channel" },
  );

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "preferred_available");
  assert.deepEqual(decision.frontier, ["http", "phoenix_channel"]);
});

test("B1 parity: cost decides first — the low-cost rival dominates the preferred high cost (falsifier anchor)", () => {
  const decision = decisionFor(
    {
      http: { cost: "high", latency: "low" },
      phoenix_channel: { cost: "low", latency: "low" },
    },
    { prefer: "http" },
  );

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "dimension_weighed");
  assert.deepEqual(decision.frontier, ["phoenix_channel"]);
});

test("B2 parity: cost ties, latency decides next — falsifier anchor", () => {
  const decision = decisionFor({
    http: { cost: "low", latency: "high" },
    phoenix_channel: { cost: "low", latency: "low" },
  });

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "dimension_weighed");
  assert.deepEqual(decision.frontier, ["phoenix_channel"]);
});

test("B3 parity: cost and latency tie, privacy decides (higher is better) — falsifier anchor", () => {
  const decision = decisionFor({
    http: { cost: "low", latency: "low", privacy: "medium" },
    phoenix_channel: { cost: "low", latency: "low", privacy: "high" },
  });

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "dimension_weighed");
  assert.deepEqual(decision.frontier, ["phoenix_channel"]);
});

test("B7 parity: medium classes rank between low and high — a medium rival dominates a high-declared preference", () => {
  const decision = decisionFor({
    http: { cost: "high", latency: "high" },
    phoenix_channel: { cost: "medium", latency: "medium" },
  });

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "dimension_weighed");
  assert.deepEqual(decision.frontier, ["phoenix_channel"]);
});

test("B8 parity: a maximal tradeoff leaves every rival non-dominated and the available preference standing", () => {
  const decision = decisionFor({
    http: { cost: "low", latency: "high", privacy: "low" },
    phoenix_channel: { cost: "medium", latency: "low", privacy: "high" },
  });

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_available");
  assert.deepEqual(decision.frontier, ["http", "phoenix_channel"]);
});

test("A3 parity: a dominated preference is overridden and the receipts carry the calculus", async () => {
  const { transports, http } = bothAdapters();
  const client = createClient({
    contract: parityContract({
      http: { cost: "high", latency: "high", privacy: "low" },
      phoenix_channel: { cost: "low", latency: "low", privacy: "high" },
    }),
    transports,
    prefer: "http",
  });

  const decision = client.inspect("todos:Todo:create").decision;
  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.reason, "dimension_weighed");
  assert.deepEqual(decision.frontier, ["phoenix_channel"]);

  const { receipt } = await client.get("todos:Todo:create").invokeWithReceipt({ title: "x" });
  assert.equal(receipt.selected, "phoenix_channel");
  assert.equal(receipt.reason, "dimension_weighed");
  assert.equal(receipt.dimensions, "declared");
  assert.deepEqual(receipt.frontier, ["phoenix_channel"]);
  assert.deepEqual(receipt.transportReceipt.frontier, ["phoenix_channel"]);
  assert.equal(receipt.transportReceipt.dimensions, "declared");
  // The overridden preference was never dispatched.
  assert.equal(http.calls.invoke, 0);
});

test("B6 parity: privacy-high on a solely-declared axis dominates and prunes", () => {
  const decision = decisionFor({ http: { privacy: "high" }, phoenix_channel: { privacy: "low" } });

  assert.equal(decision.dimensions, "declared");
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_available");
  assert.deepEqual(decision.frontier, ["http"]);
});

test("D6 parity: a wrongly-cased class is a typed pre-dispatch refusal, never a dispatch", async () => {
  const http = fakeTransport();
  const badClass = createClient({
    contract: parityContract({ http: { cost: "Low" } }),
    transports: { http: http.adapter },
  });

  assert.throws(
    () => badClass.inspect("todos:Todo:create"),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNKNOWN_DIMENSION_CLASS",
  );

  await assert.rejects(
    () => badClass.get("todos:Todo:create").invoke({ title: "x" }),
    (error) => error.code === "UNKNOWN_DIMENSION_CLASS",
  );

  // The refusal happened before any dispatch.
  assert.equal(http.calls.invoke, 0);
});
