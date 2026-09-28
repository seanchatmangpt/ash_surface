import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for the manufactured Expo client's reconcile:
// imports the GENERATED zoela_surface.mjs (its "ash_surface" import resolves
// through the node_modules shim the ExUnit caller installs) and drives
// reconcile() against stubbed fetch behaviours. Prints one JSON receipt line.

const [targetDir, contractPath] = process.argv.slice(2);
if (!targetDir || !contractPath) {
  throw new Error("usage: node generated_client_reconcile_runner.mjs <targetDir> <contractPath>");
}

const { createZoelaClient } = await import(pathToFileURL(join(targetDir, "zoela_surface.mjs")).href);
const contract = JSON.parse(await readFile(contractPath, "utf8"));
const realFetch = globalThis.fetch;

const calls = [];
function stubFetch(behaviour) {
  globalThis.fetch = (url, init) => {
    calls.push({ url: String(url), init });
    return behaviour(init);
  };
}

const json = (status, body) => Promise.resolve({ ok: status < 400, status, json: async () => body });
const client = (extra = {}) =>
  createZoelaClient({ contract, reconcileEndpoint: "http://127.0.0.1/reconcile", ...extra });

const receipt = {};

try {
  // No endpoint configured: refused, never a silent unknown.
  await assert.rejects(createZoelaClient({ contract }).reconcile("cmd_1"), /No reconcileEndpoint/);

  // Server-observed classifications pass through untouched, and the request is
  // a plain GET bound to the commandId (no method, no body, no re-dispatch).
  for (const status of ["COMPLETED", "NOT_OBSERVED", "STILL_UNKNOWN"]) {
    stubFetch(() => json(200, { status, commandId: "cmd 1" }));
    assert.equal((await client().reconcile("cmd 1")).status, status);
  }
  assert.equal(calls.at(-1).url, "http://127.0.0.1/reconcile?commandId=cmd%201");
  assert.equal(calls.at(-1).init.method, undefined);
  assert.equal(calls.at(-1).init.body, undefined);
  receipt.passThrough = true;

  // Anything the client cannot read as an admitted status stays STILL_UNKNOWN.
  const unknown = { status: "STILL_UNKNOWN" };
  stubFetch(() => json(500, { status: "COMPLETED" }));
  assert.deepEqual(await client().reconcile("c"), unknown);
  stubFetch(() => json(200, { status: "PENDING" }));
  assert.deepEqual(await client().reconcile("c"), unknown);
  stubFetch(() => json(200, null));
  assert.deepEqual(await client().reconcile("c"), unknown);
  stubFetch(() => Promise.resolve({ ok: true, status: 200, json: async () => { throw new SyntaxError("not json"); } }));
  assert.deepEqual(await client().reconcile("c"), unknown);
  stubFetch(() => Promise.reject(new TypeError("network down")));
  assert.deepEqual(await client().reconcile("c"), unknown);
  receipt.unreadableIsUnknown = true;

  // A hung endpoint is bounded by reconcileTimeoutMs (fetch honours the abort
  // signal, as real fetch does) instead of hanging the caller.
  stubFetch((init) => new Promise((_resolve, reject) => {
    init.signal.addEventListener("abort", () => reject(new DOMException("aborted", "AbortError")));
  }));
  const started = Date.now();
  assert.deepEqual(await client({ reconcileTimeoutMs: 25 }).reconcile("c"), unknown);
  assert.ok(Date.now() - started < 2000, "reconcile must settle near the deadline");
  receipt.hungEndpointBounded = true;
} finally {
  globalThis.fetch = realFetch;
}

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_RECONCILE_PASS", ...receipt }));
