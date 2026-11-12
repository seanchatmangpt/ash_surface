import assert from "node:assert/strict";
import http from "node:http";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for the manufactured Expo client's reconcile:
// imports the GENERATED zoela_surface.mjs (relative import of the copied
// ash_surface_runtime.mjs / ash_surface_http_transport.mjs) and drives
// client.reconcile against a REAL node:http server. Reconcile is the
// runtime's: replies are validated by reconcileResultSchema and failures
// throw (law: no network_error envelope, no invented status). Prints one JSON
// receipt line.

const [targetDir, contractPath] = process.argv.slice(2);
if (!targetDir || !contractPath) {
  throw new Error("usage: node generated_client_reconcile_runner.mjs <targetDir> <contractPath>");
}

const { createZoelaClient } = await import(pathToFileURL(join(targetDir, "zoela_surface.mjs")).href);
const contract = JSON.parse(await readFile(contractPath, "utf8"));

const requests = [];
let behaviour = (_req, res) => res.end("{}");
const server = http.createServer((req, res) => {
  requests.push({ method: req.method, url: req.url, hasBody: Number(req.headers["content-length"] ?? 0) > 0 });
  behaviour(req, res);
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const base = `http://127.0.0.1:${server.address().port}/reconcile`;

const reply = (status, body) => (_req, res) => {
  res.statusCode = status;
  res.setHeader("content-type", "application/json");
  res.end(typeof body === "string" ? body : JSON.stringify(body));
};
const client = (extra = {}) => createZoelaClient({ contract, reconcileEndpoint: base, ...extra });

const receipt = {};

try {
  // No endpoint configured: the runtime answers a typed STILL_UNKNOWN with a reason, never COMPLETED.
  const none = await createZoelaClient({ contract }).reconcile("cmd_1");
  assert.equal(none.status, "STILL_UNKNOWN");
  assert.equal(none.reason, "transport_reconciliation_unsupported");

  // Server-observed classifications pass through, over a plain GET bound to the commandId.
  for (const status of ["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]) {
    behaviour = reply(200, { status, commandId: "cmd 1" });
    assert.equal((await client().reconcile("cmd 1")).status, status);
  }
  const last = requests.at(-1);
  assert.equal(last.url, "/reconcile?commandId=cmd%201");
  assert.equal(last.method, "GET");
  assert.equal(last.hasBody, false);
  receipt.passThrough = true;

  // reconcile.result is emitted through the runtime (client.reconcile is not discarded),
  // and onEvent is forwarded to createClient.
  const events = [];
  behaviour = reply(200, { status: "COMPLETED" });
  await client({ onEvent: (e) => events.push(e) }).reconcile("evt");
  assert.ok(events.some((e) => e.type === "reconcile.result" && e.status === "COMPLETED"));
  receipt.runtimeReconcileDelegated = true;

  // Anything unreadable THROWS (UNKNOWN is the caller's classification), never an invented status.
  for (const [status, body] of [[500, { status: "COMPLETED" }], [200, { status: "PENDING" }], [200, "null"], [200, "not json"]]) {
    behaviour = reply(status, body);
    await assert.rejects(client().reconcile("c"));
  }
  behaviour = (req) => req.socket.destroy();
  await assert.rejects(client().reconcile("c"));
  receipt.unreadableThrows = true;

  // A hung endpoint is bounded by reconcileTimeoutMs and throws.
  const hung = new Set();
  behaviour = (_req, res) => hung.add(res);
  const started = Date.now();
  await assert.rejects(client({ reconcileTimeoutMs: 25 }).reconcile("c"));
  assert.ok(Date.now() - started < 2000, "reconcile must settle near the deadline");
  receipt.hungEndpointBounded = true;
  for (const res of hung) res.destroy();
} finally {
  server.closeAllConnections?.();
  await new Promise((resolve) => server.close(resolve));
}

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_RECONCILE_PASS", ...receipt }));
