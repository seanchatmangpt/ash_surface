import test from "node:test";
import assert from "node:assert/strict";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";
import { createHttpTransport, getPhoenixCSRFToken, buildCSRFHeaders } from "../../priv/static/ash_surface_http_transport.mjs";
import { createChannelTransport, createSurfaceChannelEvents } from "../../priv/static/ash_surface_channel_transport.mjs";

// Chicago-style: real exported functions; the channel is a hand-written real in-memory
// Phoenix-channel-shaped implementation (state asserted), not an interaction-counting mock.

class MemoryChannel {
  constructor() { this.handlers = new Map(); this.n = 1; }
  push() { const p = { receive() { return p; } }; return p; }
  on(event, cb) { const ref = this.n++; const l = this.handlers.get(event) ?? new Map(); l.set(ref, cb); this.handlers.set(event, l); return ref; }
  off(event, ref) { this.handlers.get(event)?.delete(ref); }
  size(event) { return this.handlers.get(event)?.size ?? 0; }
  deliver(event, payload) { for (const cb of [...(this.handlers.get(event)?.values() ?? [])]) cb(payload); }
}

const contract = { surfaceSchemaVersion: "0.1.0", ashManifestSchemaVersion: "1.1.0", manifest: {}, surface: { profile: {}, actions: [] } };
const evt = { eventId: "e1", sequence: 0, subjectRef: "s1", eventType: "x", stateDigest: "d", occurredAt: "2026-01-01T00:00:00Z" };

test("tstype buildCSRFHeaders: token yields x-csrf-token header, absent token yields empty record", () => {
  assert.deepEqual(buildCSRFHeaders("abc"), { "x-csrf-token": "abc" });
  assert.deepEqual(buildCSRFHeaders(null), {});
  assert.deepEqual(buildCSRFHeaders(""), {});
});

test("tstype getPhoenixCSRFToken: null without a document, meta content with one", () => {
  assert.equal(getPhoenixCSRFToken(), null);
  globalThis.document = {
    querySelector: (sel) => (sel === "meta[name='csrf-token']" ? { getAttribute: (n) => (n === "content" ? "tok9" : null) } : null),
  };
  try {
    assert.equal(getPhoenixCSRFToken(), "tok9");
  } finally {
    delete globalThis.document;
  }
});

test("tstype create: createClient, createHttpTransport and createChannelTransport build usable instances", () => {
  const http = createHttpTransport({ endpoint: "http://127.0.0.1:1/x" });
  const chan = createChannelTransport({ channel: new MemoryChannel() });
  assert.equal(typeof http.invoke, "function");
  assert.equal(typeof chan.invoke, "function");
  const client = createClient({ contract, transports: { http }, prefer: "http" });
  assert.equal(typeof client.get, "function");
  assert.equal(typeof client.events.subscribe, "function");
});

test("tstype on: createSurfaceChannelEvents registers one listener per event name and delivers valid projections", () => {
  const ch = new MemoryChannel();
  const got = [];
  const sub = createSurfaceChannelEvents(ch, { emit: (e) => got.push(e) });
  assert.equal(sub.refs.length, 1);
  assert.equal(ch.size("surface_event"), 1);
  ch.deliver("surface_event", evt);
  assert.equal(got.length, 1);
  assert.equal(got[0].eventId, "e1");
});

test("tstype unsubscribe: removes every registered listener and stops delivery", () => {
  const ch = new MemoryChannel();
  const got = [];
  const sub = createSurfaceChannelEvents(ch, { emit: (e) => got.push(e) });
  sub.unsubscribe();
  assert.equal(ch.size("surface_event"), 0);
  ch.deliver("surface_event", evt);
  assert.equal(got.length, 0);
});
