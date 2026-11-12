import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import net from "node:net";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";
import { createHttpTransport } from "../../priv/static/ash_surface_http_transport.mjs";

// Transport law, executed against a REAL node:http server and the REAL http
// adapter: an adapter-proven pre-dispatch failure (phase "pre-dispatch") is a
// typed not-dispatched refusal and zero requests reach the server; every other
// failure after dispatch is UNKNOWN_AFTER_DISPATCH.

const ID = "todos:Todo:create";
const contract = {
  surfaceSchemaVersion: "0.1.0",
  ashManifestSchemaVersion: "1.1.0",
  manifest: {},
  surface: {
    profile: {},
    actions: [
      { id: ID, semanticId: null, authorityBoundary: null, doAuthority: null, receiptRequired: null, resource: "Todo", action: "create", profile: {} },
    ],
  },
};

async function withServer(handler, fn) {
  const hits = [];
  const server = http.createServer((req, res) => {
    hits.push(req.url);
    handler(req, res);
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    return await fn(origin, hits);
  } finally {
    server.closeAllConnections?.();
    await new Promise((r) => server.close(r));
  }
}

const ok = (_req, res) => {
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify({ ok: true }));
};

function clientFor(httpOpts) {
  return createClient({ contract, transports: { http: createHttpTransport(httpOpts) }, prefer: "http" });
}

async function outcome(promise) {
  try {
    await promise;
    return { code: null };
  } catch (error) {
    return { code: error.code, state: error.receipt?.dispatchState, error };
  }
}

test("each pre-dispatch tag -> not_dispatched, zero requests reached the server", async () => {
  await withServer(ok, async (origin, hits) => {
    const endpoint = `${origin}/rpc`;
    const cases = {
      INVALID_REQUEST_BODY: [{ endpoint, allowedOrigins: [origin] }, { n: 1n }],
      HEADERS_RESOLVE_FAILED: [{ endpoint, allowedOrigins: [origin], headers: () => { throw new Error("nope"); } }, {}],
      CSRF_TOKEN_UNAVAILABLE: [{ endpoint, allowedOrigins: [origin], csrf: "require" }, {}],
      HTTP_BEFORE_REQUEST_FAILED: [{ endpoint, allowedOrigins: [origin], beforeRequest: () => { throw new Error("no"); } }, {}],
      CROSS_ORIGIN_ENDPOINT: [{ endpoint, allowedOrigins: [origin], beforeRequest: () => ({ url: "http://127.0.0.1:1/x" }) }, {}],
    };
    for (const [tag, [opts, input]] of Object.entries(cases)) {
      const out = await outcome(clientFor(opts).actions[ID].invoke(input));
      assert.equal(out.code, "TRANSPORT_REFUSED_PRE_DISPATCH", tag);
      assert.equal(out.state, "not_dispatched", tag);
      assert.equal(out.error.cause.code, tag);
    }
    assert.equal(hits.length, 0);
  });
});

test("network failure after dispatch -> unknown_after_dispatch", async () => {
  const server = net.createServer((sock) => sock.destroy());
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    const out = await outcome(clientFor({ endpoint: `${origin}/rpc`, allowedOrigins: [origin] }).actions[ID].invoke({}));
    assert.equal(out.code, "TRANSPORT_OUTCOME_UNKNOWN");
    assert.equal(out.state, "unknown_after_dispatch");
    assert.equal(out.error.cause.code, "HTTP_NETWORK_FAILURE");
  } finally {
    await new Promise((r) => server.close(r));
  }
});

test("throwing afterRequest after a good response -> unknown_after_dispatch", async () => {
  await withServer(ok, async (origin, hits) => {
    const out = await outcome(
      clientFor({ endpoint: `${origin}/rpc`, allowedOrigins: [origin], afterRequest: () => { throw new Error("late"); } }).actions[ID].invoke({}),
    );
    assert.equal(out.code, "TRANSPORT_OUTCOME_UNKNOWN");
    assert.equal(out.state, "unknown_after_dispatch");
    assert.equal(hits.length, 1);
  });
});

test("untagged adapter error stays unknown_after_dispatch; forged non-tag phase does too", async () => {
  for (const failure of [new Error("boom"), Object.assign(new Error("x"), { phase: "post-dispatch" })]) {
    const c = createClient({ contract, transports: { http: { available: true, invoke: async () => { throw failure; } } }, prefer: "http" });
    const out = await outcome(c.actions[ID].invoke({}));
    assert.equal(out.code, "TRANSPORT_OUTCOME_UNKNOWN");
  }
});
