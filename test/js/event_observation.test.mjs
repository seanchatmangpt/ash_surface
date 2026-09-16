import test from "node:test";
import assert from "node:assert/strict";
import { z } from "zod";
import {
  createClient,
  eventProjectionSchema,
  observationProjectionSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

// State-based tests of event + observation projection consumption invariants.
// Existing suites (runtime.test.mjs, zoela_mx_consumer_fixture.test.mjs) cover
// schema happy-path parsing and a single emit in the MX loop; these tests pin
// the consumption invariants: ordering, gap visibility, no authority from
// observation, subjectRef filtering, and projection purity.

const SUBJECT = "zoe:KingdomNeed#need_42";

function contract() {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: {
      profile: {},
      actions: [
        {
          id: "Zoela.KingdomNeed#select_option",
          // v26.9.16 delegation: semanticId/receiptRequired surface as
          // explicit null when not delegated.
          semanticId: null,
          receiptRequired: null,
          resource: "Zoela.KingdomNeed",
          action: "select_option",
          authorityBoundary: "SELECT",
          doAuthority: false,
          profile: {},
        },
      ],
    },
  };
}

function event(overrides = {}) {
  return {
    eventId: "ev_1",
    sequence: 1,
    subjectRef: SUBJECT,
    eventType: "state_changed",
    stateDigest: "digest_1",
    occurredAt: "2026-09-15T00:00:00.000Z",
    authorityBoundary: "OBSERVE",
    ...overrides,
  };
}

function observation() {
  return {
    observationId: "obs_42",
    exactSubject: SUBJECT,
    observedAt: "2026-09-15T00:00:00.000Z",
    stateDigest: "digest_obs_42",
    facts: { status: "DIVERGED", open_opportunities: 2 },
    evidenceRefs: ["ev_proof_1"],
  };
}

test("events are surfaced to consumers in emission order with sequence preserved", () => {
  const client = createClient({ contract: contract(), transports: {} });
  const received = [];
  client.events.subscribe(SUBJECT, (ev) => received.push(ev));

  client.events.emit(event({ eventId: "ev_a", sequence: 1 }));
  client.events.emit(event({ eventId: "ev_b", sequence: 2 }));
  client.events.emit(event({ eventId: "ev_c", sequence: 3 }));

  assert.deepEqual(
    received.map((ev) => ev.eventId),
    ["ev_a", "ev_b", "ev_c"],
  );
  assert.deepEqual(
    received.map((ev) => ev.sequence),
    [1, 2, 3],
  );
});

test("a sequence gap stays visible: the runtime resequences nothing and synthesizes nothing", () => {
  // Gap detection is not implemented runtime-side; the invariant is that a
  // gap (1 -> 3) and a late lower sequence surface verbatim so consumers can
  // detect gaps from the projected sequence numbers themselves.
  const client = createClient({ contract: contract(), transports: {} });
  const received = [];
  client.events.subscribe(SUBJECT, (ev) => received.push(ev));

  client.events.emit(event({ eventId: "ev_a", sequence: 1 }));
  client.events.emit(event({ eventId: "ev_b", sequence: 3 }));
  client.events.emit(event({ eventId: "ev_c", sequence: 2 }));

  assert.equal(received.length, 3);
  assert.deepEqual(
    received.map((ev) => ev.sequence),
    [1, 3, 2],
  );
  assert.equal(received[1].eventId, "ev_b");
  assert.equal(received[1].sequence, 3);
});

test("an event claiming a non-OBSERVE boundary is refused before dispatch", () => {
  for (const boundary of ["DO", "SELECT", "CONSTRUCT"]) {
    assert.throws(
      () => eventProjectionSchema.parse(event({ authorityBoundary: boundary })),
      (error) => error instanceof z.ZodError,
      `authorityBoundary ${boundary} must be refused`,
    );
  }

  const client = createClient({ contract: contract(), transports: {} });
  const received = [];
  client.events.subscribe(SUBJECT, (ev) => received.push(ev));

  assert.throws(
    () => client.events.emit(event({ authorityBoundary: "DO" })),
    (error) => error instanceof z.ZodError,
  );
  assert.equal(received.length, 0);

  // The events surface exposes no actuation method at all: read-only observation.
  assert.deepEqual(Object.keys(client.events).sort(), ["emit", "subscribe"]);
});

test("consuming events never dispatches a transport: no DO path from an event", () => {
  let invokeCalls = 0;
  const client = createClient({
    contract: contract(),
    transports: {
      http: {
        async invoke() {
          invokeCalls += 1;
          return { success: true };
        },
      },
    },
  });

  const received = [];
  client.events.subscribe(SUBJECT, (ev) => received.push(ev));

  client.events.emit(event({ eventId: "ev_a", sequence: 1, payload: { note: "observed" } }));
  client.events.emit(event({ eventId: "ev_b", sequence: 2, payload: { note: "still_observed" } }));

  assert.equal(received.length, 2);
  assert.equal(invokeCalls, 0);
  for (const ev of received) {
    assert.equal(ev.authorityBoundary, "OBSERVE");
  }
});

test("events are delivered only to listeners subscribed to the exact subjectRef", () => {
  const client = createClient({ contract: contract(), transports: {} });
  const need42 = [];
  const need43 = [];
  client.events.subscribe(SUBJECT, (ev) => need42.push(ev));
  client.events.subscribe("zoe:KingdomNeed#need_43", (ev) => need43.push(ev));

  client.events.emit(event({ eventId: "ev_a", subjectRef: "zoe:KingdomNeed#need_43", sequence: 4 }));
  assert.equal(need43.length, 1);
  assert.equal(need42.length, 0);

  // A subjectRef with no listeners is a no-op, not an error.
  client.events.emit(event({ eventId: "ev_b", subjectRef: "zoe:KingdomNeed#need_none", sequence: 5 }));
  assert.equal(need43.length, 1);
  assert.equal(need42.length, 0);

  // Unsubscribing stops delivery for that consumer only: the unsubscribed
  // callback gets nothing while the still-subscribed consumer keeps receiving.
  let lateCalls = 0;
  const unsubscribe = client.events.subscribe(SUBJECT, () => {
    lateCalls += 1;
  });
  unsubscribe();
  client.events.emit(event({ eventId: "ev_c", sequence: 6 }));
  assert.equal(lateCalls, 0);
  assert.equal(need42.length, 1);
  assert.equal(need43.length, 1);
});

test("event projection is pure: the same event always projects to the same state", () => {
  const raw = event({ payload: { status: "SELECTED" }, evidenceRef: "ev_proof_1" });
  const before = JSON.stringify(raw);

  const first = eventProjectionSchema.parse(raw);
  const second = eventProjectionSchema.parse(raw);

  assert.deepEqual(first, second);
  assert.notEqual(first, second);
  assert.equal(JSON.stringify(raw), before);

  const client = createClient({ contract: contract(), transports: {} });
  const delivered = [];
  client.events.subscribe(SUBJECT, (ev) => delivered.push(ev));
  client.events.emit(raw);
  client.events.emit(raw);

  assert.deepEqual(delivered[0], delivered[1]);
  assert.notEqual(delivered[0], delivered[1]);
  assert.deepEqual(delivered[0], first);
});

test("omitted event fields default deterministically, never to a DO boundary", () => {
  const minimal = {
    eventId: "ev_min",
    sequence: 0,
    subjectRef: SUBJECT,
    eventType: "state_changed",
    stateDigest: "digest_min",
    occurredAt: "2026-09-15T00:00:00.000Z",
  };

  const first = eventProjectionSchema.parse(minimal);
  const second = eventProjectionSchema.parse(minimal);

  assert.deepEqual(first, second);
  assert.equal(first.authorityBoundary, "OBSERVE");
  assert.equal(first.sequence, 0);
  assert.equal(first.evidenceRef, undefined);
  assert.equal(first.payload, undefined);
});

test("observation projection is pure, read-only, and never carries authority", () => {
  const raw = observation();
  const before = JSON.stringify(raw);

  const first = observationProjectionSchema.parse(raw);
  const second = observationProjectionSchema.parse(raw);

  assert.deepEqual(first, second);
  assert.notEqual(first, second);
  assert.equal(JSON.stringify(raw), before);
  assert.equal(first.authorityBoundary, "OBSERVE");
  assert.equal(first.facts.open_opportunities, 2);

  assert.throws(
    () => observationProjectionSchema.parse({ ...raw, authorityBoundary: "DO" }),
    (error) => error instanceof z.ZodError,
  );
});
