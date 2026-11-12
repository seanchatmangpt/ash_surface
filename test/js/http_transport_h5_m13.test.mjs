import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createHttpTransport, HttpTransportError } from "../../priv/static/ash_surface_http_transport.mjs";

// Real node:http server, real global fetch; no mocks.
async function withServer(handler, fn) {
  const seen = [];
  const server = http.createServer(async (req, res) => {
    let body = "";
    for await (const c of req) body += c;
    seen.push({ method: req.method, url: req.url, headers: req.headers, body });
    handler(req, res);
  });
  await new Promise((r) => server.listen(0, "127.0.0.1", r));
  const origin = `http://127.0.0.1:${server.address().port}`;
  try {
    return await fn({ origin, endpoint: `${origin}/dispatch`, seen });
  } finally {
    server.closeAllConnections();
    await new Promise((r) => server.close(r));
  }
}
const reply = (status, body, type = "application/json") => (_q, res) => {
  res.statusCode = status;
  if (body !== undefined) res.setHeader("content-type", type);
  res.end(body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body));
};
const ctx = { action: { id: "a:b:c" }, input: { x: 1 }, commandId: "cmd1" };

test("422 JSON body preserved on thrown error", async () => {
  const env = { code: "VALIDATION", fields: ["title"] };
  await withServer(reply(422, env), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), (e) => {
      assert.equal(e.code, "HTTP_NON_2XX");
      assert.equal(e.status, 422);
      assert.deepEqual(e.response.body, env);
      assert.equal(e.phase, "post-dispatch");
      return true;
    });
  });
});

test("403 and 500 text body preserved", async () => {
  await withServer(reply(403, { error: "forbidden" }), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), (e) => e.status === 403 && e.response.body.error === "forbidden");
  });
  await withServer(reply(500, "boom", "text/plain"), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), (e) => e.status === 500 && e.response.body === "boom");
  });
});

test("204 and empty 2xx are typed empty-success (null), not HTTP_INVALID_BODY", async () => {
  await withServer(reply(204), async ({ endpoint }) => {
    assert.equal(await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), null);
  });
  await withServer(reply(200, ""), async ({ endpoint }) => {
    assert.equal(await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), null);
  });
  await withServer(reply(200, "not json", "text/plain"), async ({ endpoint }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx), (e) => e.code === "HTTP_INVALID_BODY" && e.response.body === "not json");
  });
});

test("Headers instance and array-of-pairs Authorization preserved", async () => {
  await withServer(reply(200, { ok: 1 }), async ({ endpoint, seen }) => {
    await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, fetchOptions: { headers: new Headers({ Authorization: "Bearer H" }) } }).invoke(ctx);
    await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, fetchOptions: { headers: [["Authorization", "Bearer P"]] } }).invoke(ctx);
    await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, headers: () => new Headers({ "x-k": "v" }), fetchOptions: { headers: { Authorization: "Bearer O" } } }).invoke(ctx);
    assert.equal(seen[0].headers.authorization, "Bearer H");
    assert.equal(seen[1].headers.authorization, "Bearer P");
    assert.equal(seen[2].headers.authorization, "Bearer O");
    assert.equal(seen[2].headers["x-k"], "v");
  });
});

test("cross-origin endpoint refused unless allowlisted", async () => {
  await withServer(reply(200, { ok: 1 }), async ({ origin, endpoint, seen }) => {
    assert.throws(() => createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, allowedOrigins: ["https://app.example"] }), (e) => e instanceof HttpTransportError && e.code === "CROSS_ORIGIN_ENDPOINT" && e.phase === "pre-dispatch");
    await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, allowedOrigins: [origin] }).invoke(ctx);
    assert.equal(seen.length, 1);
  });
});

test("reconcile with #fragment endpoint puts query before fragment", async () => {
  const reconcileReply = { status: "unknown" };
  await withServer(reply(200, reconcileReply), async ({ endpoint, seen }) => {
    try { await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint: `${endpoint}?a=1#frag` }).reconcile("c 1"); } catch { /* schema outcome irrelevant */ }
    assert.equal(seen.length, 1);
    const u = new URL(seen[0].url, "http://x");
    assert.equal(u.searchParams.get("commandId"), "c 1");
    assert.equal(u.searchParams.get("a"), "1");
  });
});

test("csrf:auto in Node yields no header; csrf:'require' refuses pre-dispatch with zero requests", async () => {
  await withServer(reply(200, { ok: 1 }), async ({ endpoint, seen }) => {
    await createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint }).invoke(ctx);
    assert.equal(seen[0].headers["x-csrf-token"], undefined);
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, csrf: "require" }).invoke(ctx), (e) => e.code === "CSRF_TOKEN_UNAVAILABLE" && e.phase === "pre-dispatch");
    assert.equal(seen.length, 1);
  });
});

test("beforeRequest throw is pre-dispatch (no request); afterRequest throw is post-dispatch", async () => {
  await withServer(reply(200, { ok: 1 }), async ({ endpoint, seen }) => {
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, beforeRequest() { throw new Error("nope"); } }).invoke(ctx), (e) => e.code === "HTTP_BEFORE_REQUEST_FAILED" && e.phase === "pre-dispatch");
    assert.equal(seen.length, 0);
    await assert.rejects(createHttpTransport({ allowedOrigins: [new URL(endpoint).origin], endpoint, afterRequest() { throw new Error("late"); } }).invoke(ctx), (e) => e.code === "HTTP_AFTER_REQUEST_FAILED" && e.phase === "post-dispatch");
    assert.equal(seen.length, 1);
  });
});
