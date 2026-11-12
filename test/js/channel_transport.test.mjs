import test from "node:test";
import assert from "node:assert/strict";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";
import {
  createChannelTransport,
  createSurfaceChannelEvents,
} from "../../priv/static/ash_surface_channel_transport.mjs";

// Chicago-style. MemoryChannel is a hand-written, REAL in-memory
// Phoenix-channel-shaped implementation of push/receive/on/off (reply policy
// per event is real behaviour, state is asserted) - an implementation of the
// interface, not a mock; no interaction counting stands in for assertions.

class MemoryChannel {
  constructor(replyFor) {
    this.replyFor = replyFor; // (event, payload) => {kind: "ok"|"error"|"timeout"|"never", response}
    this.pushed = [];
    this.handlers = new Map();
    this.nextRef = 1;
  }
  push(event, payload, timeout) {
    this.pushed.push({ event, payload, timeout });
    const callbacks = {};
    const push = {
      receive(kind, cb) { callbacks[kind] = cb; return push; },
    };
    const reply = this.replyFor(event, payload);
    queueMicrotask(() => reply.kind !== "never" && callbacks[reply.kind]?.(reply.response));
    return push;
  }
  on(event, cb) {
    const ref = this.nextRef++;
    if (!this.handlers.has(event)) this.handlers.set(event, new Map());
    this.handlers.get(event).set(ref, cb);
    return ref;
  }
  off(event, ref) { this.handlers.get(event)?.delete(ref); }
  deliver(event, payload) { for (const cb of this.handlers.get(event)?.values() ?? []) cb(payload); }
  listenerCount(event) { return this.handlers.get(event)?.size ?? 0; }
}

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
const clientFor = (channel, opts) =>
  createClient({ contract, transports: { phoenix_channel: createChannelTransport({ channel, ...opts }) }, prefer: "phoenix_channel" });

test("ok reply resolves; payload is {action,input,commandId} pushed on event 'run'", async () => {
  const ch = new MemoryChannel(() => ({ kind: "ok", response: { done: true } }));
  const out = await clientFor(ch, { timeout: 777 }).get(ACTION).invoke({ t: 1 }, { commandId: "cmd_ch_1" });
  assert.deepEqual(out, { done: true });
  assert.deepEqual(ch.pushed, [{ event: "run", payload: { action: ACTION, input: { t: 1 }, commandId: "cmd_ch_1" }, timeout: 777 }]);
});

test("error reply and push timeout THROW -> UNKNOWN_AFTER_DISPATCH, no second push", async () => {
  for (const kind of ["error", "timeout"]) {
    const ch = new MemoryChannel(() => ({ kind, response: { reason: "x" } }));
    await assert.rejects(clientFor(ch).get(ACTION).invoke({}), { code: "TRANSPORT_OUTCOME_UNKNOWN" });
    assert.equal(ch.pushed.length, 1);
  }
});

test("a channel that never answers is bounded by the runtime timeoutMs", async () => {
  const ch = new MemoryChannel(() => ({ kind: "never" }));
  await assert.rejects(clientFor(ch).get(ACTION).invoke({}, { timeoutMs: 30 }), { code: "TRANSPORT_OUTCOME_UNKNOWN" });
});

test("reconcile is pushed as 'reconcile' and validated by reconcileResultSchema", async () => {
  const ch = new MemoryChannel((event) =>
    event === "reconcile" ? { kind: "ok", response: { status: "NOT_OBSERVED" } } : { kind: "ok", response: {} });
  const verdict = await clientFor(ch).reconcile("cmd_r", "phoenix_channel");
  assert.equal(verdict.status, "NOT_OBSERVED");
  assert.deepEqual(ch.pushed[0], { event: "reconcile", payload: { commandId: "cmd_r" }, timeout: 10000 });

  const bad = new MemoryChannel(() => ({ kind: "ok", response: { status: "PENDING" } }));
  await assert.rejects(clientFor(bad).reconcile("c", "phoenix_channel"), { code: "INVALID_RECONCILE_RESULT" });
});

test("beforePush / afterResponse hooks may rewrite payload and reply", async () => {
  const ch = new MemoryChannel(() => ({ kind: "ok", response: { n: 1 } }));
  const out = await clientFor(ch, {
    beforePush: (p) => ({ ...p, extra: true }),
    afterResponse: (r) => ({ ...r, post: true }),
  }).get(ACTION).invoke({}, { commandId: "cmd_h" });
  assert.deepEqual(out, { n: 1, post: true });
  assert.equal(ch.pushed[0].payload.extra, true);
});

test("createSurfaceChannelEvents maps channel events onto client.events and unsubscribes via off", () => {
  const ch = new MemoryChannel(() => ({ kind: "ok", response: {} }));
  const client = clientFor(ch);
  const got = [];
  client.events.subscribe("subj_1", (e) => got.push(e));
  const errors = [];
  const sub = createSurfaceChannelEvents(ch, client.events, { onError: (e) => errors.push(e) });
  assert.equal(sub.refs.length, 1);
  assert.equal(ch.listenerCount("surface_event"), 1);

  const evt = {
    eventId: "e1", sequence: 0, subjectRef: "subj_1", eventType: "x", stateDigest: "d", occurredAt: "2026-01-01T00:00:00Z",
  };
  ch.deliver("surface_event", evt);
  assert.equal(got.length, 1);
  assert.equal(got[0].authorityBoundary, "OBSERVE");

  ch.deliver("surface_event", { eventId: "" });
  assert.equal(got.length, 1, "invalid projection is not emitted");
  assert.equal(errors.length, 1);

  sub.unsubscribe();
  assert.equal(ch.listenerCount("surface_event"), 0);
  ch.deliver("surface_event", evt);
  assert.equal(got.length, 1);
});

test("events.emit throwing is reported via onError and errors, never into dispatch", () => {
  const ch = new MemoryChannel(() => ({ kind: "ok", response: {} }));
  const evt = {
    eventId: "e1", sequence: 0, subjectRef: "subj_1", eventType: "x", stateDigest: "d", occurredAt: "2026-01-01T00:00:00Z",
  };
  const boom = { emit() { throw new Error("emit-boom"); } };
  const seen = [];
  const sub = createSurfaceChannelEvents(ch, boom, { onError: (e) => seen.push(e.message) });
  ch.deliver("surface_event", evt); // must not throw
  assert.deepEqual(seen, ["emit-boom"]);
  assert.equal(sub.errors.length, 1);

  const sub2 = createSurfaceChannelEvents(ch, boom, { eventNames: ["e2"], onError: () => { throw new Error("onerror-boom"); } });
  ch.deliver("e2", evt);
  assert.equal(sub2.errors.length, 2);
  assert.equal(sub2.errors[1].error.message, "onerror-boom");
});
