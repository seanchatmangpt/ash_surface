import test from "node:test";
import assert from "node:assert/strict";
import {
  createSurface,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

function manifest(actions) {
  return { version: "1.1", actions, resources: {}, files: {} };
}

function action(overrides = {}) {
  return {
    functionName: "createTodo",
    actionType: "create",
    namespace: "todos",
    resource: "Todo",
    variants: { channel: true },
    variantNames: { channel: "createTodoChannel" },
    ...overrides,
  };
}

test("refuses incompatible AshTypescript manifest majors", () => {
  assert.throws(
    () => createSurface({ manifest: { version: "2.0", actions: [] }, rpc: {} }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNSUPPORTED_MANIFEST_VERSION",
  );
});

test("falls back only before dispatch when preferred channel is unavailable", async () => {
  let httpCalls = 0;
  const rpc = {
    async createTodo(config) {
      httpCalls += 1;
      return { success: true, data: { id: "1", ...config.input } };
    },
    createTodoChannel() {
      assert.fail("channel implementation must not run without a joined channel");
    },
  };

  const surface = createSurface({
    manifest: manifest([action()]),
    rpc,
    prefer: "phoenix_channel",
  });

  const descriptor = surface.get("todos:Todo:createTodo");
  const inspected = descriptor.inspect();
  assert.equal(inspected.decision.selected, "http");
  assert.equal(inspected.decision.reason, "preferred_unavailable");
  assert.deepEqual(inspected.declared, ["http", "phoenix_channel"]);
  assert.deepEqual(inspected.available, ["http"]);

  const { result, receipt } = await descriptor.invokeWithReceipt({ input: { title: "x" } });
  assert.equal(httpCalls, 1);
  assert.equal(result.success, true);
  assert.equal(receipt.selected, "http");
  assert.equal(receipt.dispatchState, "completed");
});

test("uses the channel variant when it is selected and available", async () => {
  let httpCalls = 0;
  const joinedChannel = { topic: "ash_typescript_rpc:test" };

  const rpc = {
    async createTodo() {
      httpCalls += 1;
      return { success: true };
    },
    createTodoChannel(config) {
      assert.equal(config.channel, joinedChannel);
      config.resultHandler({ success: true, data: { id: "2" } });
    },
  };

  const surface = createSurface({
    manifest: manifest([action()]),
    rpc,
    channel: joinedChannel,
    prefer: "phoenix_channel",
  });

  const { result, receipt } =
    await surface.actions["todos:Todo:createTodo"].invokeWithReceipt({ input: { title: "x" } });

  assert.equal(httpCalls, 0);
  assert.equal(result.data.id, "2");
  assert.equal(receipt.selected, "phoenix_channel");
  assert.equal(receipt.dispatchState, "completed");
});

test("channel timeout is UNKNOWN after dispatch and never retries over HTTP", async () => {
  let httpCalls = 0;
  const rpc = {
    async createTodo() {
      httpCalls += 1;
      return { success: true };
    },
    createTodoChannel(config) {
      config.timeoutHandler();
    },
  };

  const surface = createSurface({
    manifest: manifest([action()]),
    rpc,
    channel: {},
    prefer: "phoenix_channel",
  });

  await assert.rejects(
    () => surface.actions["todos:Todo:createTodo"].invoke({ input: { title: "x" } }),
    (error) => {
      assert.equal(error.code, "TRANSPORT_OUTCOME_UNKNOWN");
      assert.equal(error.receipt.dispatchState, "unknown_after_dispatch");
      assert.equal(error.receipt.fallback, "pre_dispatch_only");
      return true;
    },
  );

  assert.equal(httpCalls, 0);
});

test("namespaces preserve equal function names without collapsing identity", () => {
  const actions = [
    action({ namespace: "admin", resource: "Todo" }),
    action({ namespace: "public", resource: "Todo" }),
  ];

  const surface = createSurface({
    manifest: manifest(actions),
    rpc: { createTodo: async () => ({ success: true }) },
  });

  assert.ok(surface.namespaces.admin.createTodo);
  assert.ok(surface.namespaces.public.createTodo);
  assert.notEqual(surface.namespaces.admin.createTodo.id, surface.namespaces.public.createTodo.id);
});

test("refuses a manifest action with no executable transport implementation", async () => {
  const surface = createSurface({ manifest: manifest([action()]), rpc: {}, prefer: "http" });

  await assert.rejects(
    () => surface.actions["todos:Todo:createTodo"].invoke(),
    (error) => error.code === "UNSUPPORTED_TRANSPORT" && error.receipt.dispatchState === "not_dispatched",
  );
});
