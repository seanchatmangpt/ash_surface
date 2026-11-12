import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";
import {
  createHttpTransport,
  getPhoenixCSRFToken,
  buildCSRFHeaders,
} from "../../priv/static/ash_surface_http_transport.mjs";

// Chicago-style: a REAL node:http server, the real runtime, no mocks. The
// `document` objects below are minimal real implementations of
// querySelector/getAttribute, not interaction-recording doubles.

const ACTION = "todos:Todo:create";
const contract = {
  surfaceSchemaVersion: "0.1.0",
  ashManifestSchemaVersion: "1.1.0",
  manifest: {},
  surface: {
    profile: {},
    actions: [
      {
        id: ACTION, semanticId: null, authorityBoundary: null, doAuthority: null, receiptRequired: null,
        resource: "Todo", action: "create", evidenceRequired: false, possibleRefusals: [], profile: {},
      },
    ],
  },
};

async function withServer(handler, fn) {
  const seen = [];
  const hung = new Set();
  const server = http.createServer(async (req, res) => {
    let body = "";
    for await (const chunk of req) body += chunk;
    seen.push({ method: req.method, url: req.url, headers: req.headers, body });
    handler(req, res, hung);
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const endpoint = `http://127.0.0.1:${server.address().port}/dispatch`;
  try {
    return await fn({ endpoint, seen });
  } finally {
    for (const res of hung) res.destroy();
    server.closeAllConnections();
    await new Promise((r) => server.close(r));
  }
}

const json = (status, body) => (_req, res) => {
  res.statusCode = status;
  res.setHeader("content-type", "application/json");
  res.end(typeof body === "string" ? body : JSON.stringify(body));
};

const clientFor = (transport) => createClient({ contract, transports: { http: transport }, prefer: "http" });
const action = (c) => c.get(ACTION);

test("2xx JSON passes through; request is a JSON POST with action, input, commandId", async () => {
  await withServer(json(200, { ok: 1 }), async ({ endpoint, seen }) => {
    const c = clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, headers: { "x-app": "a" } }));
    const out = await action(c).invoke({ title: "t" }, { commandId: "cmd_http_1" });
    assert.deepEqual(out, { ok: 1 });
    assert.equal(seen[0].method, "POST");
    assert.equal(seen[0].headers["x-app"], "a");
    assert.deepEqual(JSON.parse(seen[0].body), { action: ACTION, input: { title: "t" }, commandId: "cmd_http_1" });
  });
});

test("non-2xx, non-JSON, and network failure all THROW -> UNKNOWN_AFTER_DISPATCH, never a network_error envelope", async () => {
  for (const handler of [json(500, { error: "x" }), json(200, "not json"), (req) => req.socket.destroy()]) {
    await withServer(handler, async ({ endpoint, seen }) => {
      const c = clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }));
      await assert.rejects(action(c).invoke({}), (e) => {
        assert.equal(e.code, "TRANSPORT_OUTCOME_UNKNOWN");
        return true;
      });
      assert.equal(seen.length, 1, "no retry after dispatch");
    });
  }
});

test("timeoutMs on a hung server is UNKNOWN_AFTER_DISPATCH and the signal reaches the adapter", async () => {
  await withServer((_req, res, hung) => hung.add(res), async ({ endpoint, seen }) => {
    const c = clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }));
    await assert.rejects(action(c).invoke({}, { timeoutMs: 40 }), { code: "TRANSPORT_OUTCOME_UNKNOWN" });
    assert.equal(seen.length, 1);
  });
});

test("reconcile GETs ?commandId= and validates with reconcileResultSchema", async () => {
  await withServer(json(200, { status: "COMPLETED", receipt: { r: 1 } }), async ({ endpoint, seen }) => {
    const transport = createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint });
    const c = clientFor(transport);
    const verdict = await c.reconcile("cmd a&b");
    assert.equal(verdict.status, "COMPLETED");
    assert.equal(seen.at(-1).method, "GET");
    assert.equal(seen.at(-1).url, "/dispatch?commandId=cmd%20a%26b");
    assert.equal(seen.at(-1).body, "");
  });
  await withServer(json(200, { status: "PENDING" }), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).reconcile("c"), { code: "HTTP_INVALID_RECONCILE" });
  });
  await withServer(json(503, { status: "COMPLETED" }), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).reconcile("c"), { code: "HTTP_NON_2XX" });
  });
});

test("CSRF auto reads the meta tag only when a document exists; opt-out and explicit token work", async () => {
  assert.equal(getPhoenixCSRFToken(), null, "no document in node");
  assert.deepEqual(buildCSRFHeaders(), {});
  globalThis.document = {
    querySelector: (sel) => (sel === "meta[name='csrf-token']" ? { getAttribute: (n) => (n === "content" ? "tok123" : null) } : null),
  };
  try {
    assert.equal(getPhoenixCSRFToken(), "tok123");
    await withServer(json(200, {}), async ({ endpoint, seen }) => {
      await action(clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }))).invoke({});
      assert.equal(seen[0].headers["x-csrf-token"], "tok123");
      await action(clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, csrf: false }))).invoke({});
      assert.equal(seen[1].headers["x-csrf-token"], undefined);
      await action(clientFor(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, csrf: "explicit" }))).invoke({});
      assert.equal(seen[2].headers["x-csrf-token"], "explicit");
    });
  } finally {
    delete globalThis.document;
  }
});

test("validateEndpoint, customFetch, beforeRequest and afterRequest hooks", async () => {
  assert.throws(() => createHttpTransport({ endpoint: "" }), { code: "INVALID_ENDPOINT" });
  assert.throws(() => createHttpTransport({ endpoint: "http://x", validateEndpoint: () => false }), { code: "INVALID_ENDPOINT" });

  await withServer(json(200, { v: 1 }), async ({ endpoint, seen }) => {
    let customCalled = 0;
    const transport = createHttpTransport({
      endpoint, allowedOrigins: [new URL(endpoint).origin],
      customFetch: (url, init) => { customCalled += 1; return fetch(url, init); },
      beforeRequest: ({ init }) => ({ init: { ...init, headers: { ...init.headers, "x-before": "1" } } }),
      afterRequest: ({ body }) => ({ ...body, after: true }),
    });
    const out = await action(clientFor(transport)).invoke({});
    assert.deepEqual(out, { v: 1, after: true });
    assert.equal(customCalled, 1);
    assert.equal(seen[0].headers["x-before"], "1");
  });
});
