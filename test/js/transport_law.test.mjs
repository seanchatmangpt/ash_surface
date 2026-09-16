import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Chicago-school, state-based mirror of the Elixir transport law
 * (lib/ash_surface/transport.ex):
 *
 *   - selection is pure and pre-dispatch; preferred wins when available,
 *     otherwise the first declared-and-available transport is selected
 *   - fallback is legal ONLY while dispatch_state is :not_dispatched
 *     (fallback: :pre_dispatch_only)
 *   - after dispatch, a timeout/disconnect surfaces an unknown outcome and
 *     NEVER authorizes an automatic cross-transport retry
 *   - no available transport is a typed refusal, not an exception in flight
 *
 * Adapter doubles are the injected dependency (fake adapters only; no network,
 * no config, no fixtures).
 */

function lawContract() {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id: "todos:Todo:create",
          // v26.9.16 delegation: delegated facts surface as explicit null
          // when not delegated.
          semanticId: null,
          authorityBoundary: null,
          doAuthority: null,
          receiptRequired: null,
          resource: "Todo",
          action: "create",
          profile: {},
        },
      ],
    },
  };
}

/**
 * Fake transport adapter double. Records observable call state; the runtime
 * under test is exercised through the real client surface only.
 */
function fakeTransport(behavior = {}) {
  const calls = { invoke: 0, availableChecks: 0, contexts: [] };

  const adapter = {
    async invoke(context) {
      calls.invoke += 1;
      calls.contexts.push(context);
      if (behavior.failWith) throw behavior.failWith;
      return behavior.result ?? { success: true, data: { id: "row_1" } };
    },
  };

  if (typeof behavior.available === "function") {
    adapter.available = (action, contract) => {
      calls.availableChecks += 1;
      calls.availableArguments = { actionId: action.id, hasContract: Boolean(contract) };
      return behavior.available(action, contract);
    };
  } else if (behavior.available !== undefined) {
    adapter.available = behavior.available;
  }

  return { adapter, calls };
}

const timeoutError = () => new Error("transport timed out after 5000ms awaiting server reply");

test("prefers phoenix_channel when its adapter is present (preferred_available)", async () => {
  const http = fakeTransport();
  const channel = fakeTransport();

  const client = createClient({
    contract: lawContract(),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
    prefer: "phoenix_channel",
  });

  const decision = client.inspect("todos:Todo:create").decision;
  assert.equal(decision.selected, "phoenix_channel");
  assert.equal(decision.preferred, "phoenix_channel");
  assert.equal(decision.reason, "preferred_available");
  assert.equal(decision.fallback, "pre_dispatch_only");
  assert.equal(decision.dispatchState, "not_dispatched");
  assert.deepEqual(decision.declared, ["http", "phoenix_channel"]);
  assert.deepEqual(decision.available, ["http", "phoenix_channel"]);

  const { result, receipt } = await client.get("todos:Todo:create").invokeWithReceipt({ title: "x" });

  assert.equal(channel.calls.invoke, 1);
  assert.equal(http.calls.invoke, 0);
  assert.equal(result.data.id, "row_1");
  assert.equal(receipt.selected, "phoenix_channel");
  assert.equal(receipt.dispatchState, "completed");
  assert.equal(typeof channel.calls.contexts[0].commandId, "string");
});

test("falls back to http before dispatch when no phoenix_channel adapter exists", async () => {
  const http = fakeTransport();

  const client = createClient({
    contract: lawContract(),
    transports: { http: http.adapter },
    prefer: "phoenix_channel",
  });

  const decision = client.inspect("todos:Todo:create").decision;
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_unavailable");
  assert.deepEqual(decision.available, ["http"]);

  const { receipt } = await client.get("todos:Todo:create").invokeWithReceipt({ title: "x" });

  assert.equal(http.calls.invoke, 1);
  assert.equal(receipt.selected, "http");
  assert.equal(receipt.dispatchState, "completed");
});

test("fallback is decided from availability pre-dispatch, never by trial dispatch", async () => {
  const http = fakeTransport();
  // Channel adapter is present and dispatchable, but reports itself unavailable.
  // If the runtime tried the channel first, this counter would betray it.
  const channel = fakeTransport({ available: (action) => action.id === "todos:Todo:destroy" });

  const client = createClient({
    contract: lawContract(),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
    prefer: "phoenix_channel",
  });

  const decision = client.inspect("todos:Todo:create").decision;
  assert.deepEqual(decision.available, ["http"]);
  assert.equal(decision.selected, "http");
  assert.equal(decision.reason, "preferred_unavailable");

  await client.get("todos:Todo:create").invokeWithReceipt({ title: "x" });

  assert.equal(channel.calls.invoke, 0);
  assert.equal(channel.calls.availableChecks >= 1, true);
  assert.equal(channel.calls.availableArguments.actionId, "todos:Todo:create");
  assert.equal(http.calls.invoke, 1);
});

test("post-dispatch timeout on the selected channel surfaces TRANSPORT_OUTCOME_UNKNOWN and never calls http", async () => {
  const http = fakeTransport();
  const boom = timeoutError();
  const channel = fakeTransport({ failWith: boom });

  const client = createClient({
    contract: lawContract(),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
    prefer: "phoenix_channel",
  });

  await assert.rejects(
    () => client.get("todos:Todo:create").invokeWithReceipt({ title: "x" }),
    (error) => {
      assert.ok(error instanceof SurfaceRuntimeError);
      assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.cause, boom);

      const receipt = error.receipt;
      assert.equal(receipt.selected, "phoenix_channel");
      assert.equal(receipt.dispatchState, "unknown_after_dispatch");
      assert.equal(receipt.outcome, "UNKNOWN_AFTER_DISPATCH");
      assert.equal(receipt.fallback, "pre_dispatch_only");
      assert.equal(receipt.transportReceipt.dispatchState, "unknown_after_dispatch");
      assert.equal(typeof receipt.commandId, "string");
      return true;
    },
  );

  // The one lawful dispatch happened on the channel; http was never touched.
  assert.equal(channel.calls.invoke, 1);
  assert.equal(http.calls.invoke, 0);
});

test("post-dispatch timeout on http (default prefer) never spills over to phoenix_channel", async () => {
  const channel = fakeTransport();
  const http = fakeTransport({ failWith: timeoutError() });

  const client = createClient({
    contract: lawContract(),
    transports: { http: http.adapter, phoenix_channel: channel.adapter },
  });

  await assert.rejects(
    () => client.get("todos:Todo:create").invoke({ title: "x" }),
    (error) => error.code === "TRANSPORT_OUTCOME_UNKNOWN",
  );

  assert.equal(http.calls.invoke, 1);
  assert.equal(channel.calls.invoke, 0);
});

test("no adapter at all is a typed pre-dispatch refusal, not a dispatch", async () => {
  const client = createClient({
    contract: lawContract(),
    transports: {},
    prefer: "http",
  });

  assert.throws(
    () => client.inspect("todos:Todo:create"),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNSUPPORTED_TRANSPORT",
  );

  await assert.rejects(
    () => client.get("todos:Todo:create").invoke({ title: "x" }),
    (error) => {
      assert.ok(error instanceof SurfaceRuntimeError);
      assert.equal(error.code, "UNSUPPORTED_TRANSPORT");
      assert.equal(error.receipt.selected, null);
      assert.equal(error.receipt.reason, "no_available_transport");
      assert.equal(error.receipt.dispatchState, "not_dispatched");
      assert.deepEqual(error.receipt.declared, ["http", "phoenix_channel"]);
      assert.deepEqual(error.receipt.available, []);
      return true;
    },
  );
});
