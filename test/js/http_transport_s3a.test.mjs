import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createHttpTransport, HttpTransportError } from "../../priv/static/ash_surface_http_transport.mjs";
import { createClient, SurfaceRuntimeError } from "../../priv/static/ash_surface_runtime.mjs";

// Real node:http servers + real fetch; no mocks.
async function server() {
  const seen = [];
  const s = http.createServer(async (req, res) => {
    for await (const _ of req);
    seen.push(req.url);
    res.setHeader("content-type", "application/json");
    res.end("{}");
  });
  await new Promise((r) => s.listen(0, "127.0.0.1", r));
  const origin = `http://127.0.0.1:${s.address().port}`;
  return { origin, seen, close: async () => { s.closeAllConnections(); await new Promise((r) => s.close(r)); } };
}
const ctx = { action: { id: "a:b:c" }, input: { x: 1 }, commandId: "c1" };
const BYPASS = ["\\\\evil.com/x", "/\\evil.com/x", " //evil.com", "\t//evil.com", "/\t/evil.com"];

test("WHATWG-parse bypass endpoints refused with zero requests (no allowlist, with baseUrl, with allowlist)", async () => {
  const evil = await server();
  const good = await server();
  try {
    for (const raw of BYPASS) {
      // point the bypass at the real evil server via a host rewrite where it parses cross-origin
      const ep = raw.replace("evil.com", evil.origin.replace("http://", ""));
      for (const opts of [{}, { baseUrl: good.origin }, { allowedOrigins: [good.origin] }, { baseUrl: good.origin, allowedOrigins: [good.origin] }]) {
        let threw = null, t;
        try { t = createHttpTransport({ endpoint: ep, ...opts }); await t.invoke(ctx); } catch (e) { threw = e; }
        assert.ok(threw instanceof HttpTransportError, `${JSON.stringify(raw)} ${JSON.stringify(opts)} must be refused`);
        assert.equal(threw.phase, "pre-dispatch");
      }
    }
    assert.equal(evil.seen.length, 0);
    assert.equal(good.seen.length, 0);
  } finally { await evil.close(); await good.close(); }
});

test("Node policy: absolute needs allowedOrigins; relative needs baseUrl", async () => {
  const s = await server();
  try {
    assert.throws(() => createHttpTransport({ endpoint: `${s.origin}/d` }), (e) => e.code === "CROSS_ORIGIN_ENDPOINT");
    assert.throws(() => createHttpTransport({ endpoint: "/d" }), (e) => e.code === "RELATIVE_ENDPOINT_NO_BASE");
    assert.throws(() => createHttpTransport({ endpoint: "not a url" }), (e) => e.phase === "pre-dispatch");
    assert.throws(() => createHttpTransport({ endpoint: "file:///etc/passwd", allowedOrigins: ["null"] }), (e) => e.code === "INVALID_ENDPOINT");
    await createHttpTransport({ endpoint: `${s.origin}/d`, allowedOrigins: [s.origin] }).invoke(ctx);
    await createHttpTransport({ endpoint: "/rel", baseUrl: s.origin }).invoke(ctx);
    await createHttpTransport({ endpoint: "/rel", baseUrl: s.origin }).reconcile("c1").catch(() => {});
    assert.deepEqual(s.seen.slice(0, 2), ["/d", "/rel"]);
    assert.match(s.seen[2], /^\/rel\?commandId=c1$/);
  } finally { await s.close(); }
});

test("beforeRequest url swap to a foreign origin refused before fetch", async () => {
  const good = await server();
  const evil = await server();
  try {
    const t = createHttpTransport({
      endpoint: `${good.origin}/d`, allowedOrigins: [good.origin], csrf: "auto",
      beforeRequest: ({ init }) => ({ url: `${evil.origin}/steal`, init }),
    });
    await assert.rejects(t.invoke(ctx), (e) => e.code === "CROSS_ORIGIN_ENDPOINT" && e.phase === "pre-dispatch");
    const t2 = createHttpTransport({
      endpoint: `${good.origin}/d`, allowedOrigins: [good.origin],
      beforeRequest: () => ({ url: "\\\\" + evil.origin.replace("http://", "") }),
    });
    await assert.rejects(t2.invoke(ctx), (e) => e.phase === "pre-dispatch");
    assert.equal(evil.seen.length, 0);
    assert.equal(good.seen.length, 0);
  } finally { await good.close(); await evil.close(); }
});

test("pre-dispatch failures are HttpTransportError phase pre-dispatch with stable codes", async () => {
  const s = await server();
  try {
    const t = createHttpTransport({ endpoint: `${s.origin}/d`, allowedOrigins: [s.origin] });
    await assert.rejects(t.invoke({ ...ctx, input: { n: 1n } }), (e) => e instanceof HttpTransportError && e.code === "INVALID_REQUEST_BODY" && e.phase === "pre-dispatch");
    const circ = {}; circ.self = circ;
    await assert.rejects(t.invoke({ ...ctx, input: circ }), (e) => e.code === "INVALID_REQUEST_BODY" && e.phase === "pre-dispatch");
    const h = createHttpTransport({ endpoint: `${s.origin}/d`, allowedOrigins: [s.origin], headers: () => { throw new Error("nope"); } });
    await assert.rejects(h.invoke(ctx), (e) => e instanceof HttpTransportError && e.code === "HEADERS_RESOLVE_FAILED" && e.phase === "pre-dispatch");
    await assert.rejects(h.reconcile("c1"), (e) => e.code === "HEADERS_RESOLVE_FAILED" && e.phase === "pre-dispatch");
    assert.equal(s.seen.length, 0);
  } finally { await s.close(); }
});

const contract = () => ({
  surfaceSchemaVersion: "0.1.0", ashManifestSchemaVersion: "1.1.0", manifest: {},
  surface: { profile: {}, actions: [{ id: "todos:Todo:create", semanticId: null, authorityBoundary: null, doAuthority: null, receiptRequired: null, resource: "Todo", action: "create", profile: {} }] },
});

test("runtime classification via createClient: network failure => TRANSPORT_OUTCOME_UNKNOWN/unknown_after_dispatch; pre-dispatch tagged error classification recorded", async () => {
  const s = await server();
  const dead = s.origin;
  await s.close();
  const mk = (opts) => createClient({ contract: contract(), transports: { http: createHttpTransport({ endpoint: `${dead}/d`, allowedOrigins: [dead], ...opts }) } });

  await assert.rejects(mk({}).get("todos:Todo:create").invokeWithReceipt({ title: "x" }), (e) => {
    assert.ok(e instanceof SurfaceRuntimeError);
    assert.equal(e.code, "TRANSPORT_OUTCOME_UNKNOWN");
    assert.equal(e.receipt.dispatchState, "unknown_after_dispatch");
    assert.equal(e.cause.phase, "post-dispatch");
    return true;
  });

  // Pre-dispatch tagged failure (headers resolver): record how the runtime classifies it today.
  await assert.rejects(mk({ headers: () => { throw new Error("x"); } }).get("todos:Todo:create").invokeWithReceipt({ title: "x" }), (e) => {
    assert.equal(e.cause.phase, "pre-dispatch");
    assert.equal(e.cause.code, "HEADERS_RESOLVE_FAILED");
    // KNOWN RUNTIME GAP (follow-up for runtime owner): runtime ignores `phase` and reports
    // unknown_after_dispatch for pre-dispatch-tagged throws.
    console.log("runtime classification of pre-dispatch-tagged throw:", e.code, e.receipt?.dispatchState);
    return true;
  });
});
