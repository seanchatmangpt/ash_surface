import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for a manufactured `<prefix>.events.mjs`.
// spec: { prefix, goodEvent } - goodEvent is a real Event.to_map/1 wire form.

const [targetDir, specPath] = process.argv.slice(2);
if (!targetDir || !specPath) {
  throw new Error("usage: node generated_expo_events_runner.mjs <targetDir> <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));

// Purity: parsing is the only behaviour. Any I/O, clock or entropy use inside
// the module (at import or at parse time) trips these traps.
const trap = (name) => () => { throw new Error(`events module touched ${name}`); };
globalThis.fetch = trap("fetch");
globalThis.WebSocket = trap("WebSocket");
Math.random = trap("Math.random");
Date.now = trap("Date.now");

const mod = await import(pathToFileURL(join(targetDir, `${spec.prefix}.events.mjs`)).href);

// Observation surface only: a schema and a parser.
assert.deepEqual(Object.keys(mod).sort(), ["eventProjectionSchema", "parseEvent"]);

const good = spec.goodEvent;
const bad = (patch, label) => {
  const event = { ...good, ...patch };
  for (const [k, v] of Object.entries(patch)) if (v === undefined) delete event[k];
  assert.throws(() => mod.parseEvent(event), { name: "ZodError" }, `must reject ${label}`);
};

// Every serialized Event field survives the boundary.
const parsed = mod.parseEvent(good);
for (const [key, value] of Object.entries(good)) assert.deepEqual(parsed[key], value, key);

// Sequencing and identity.
bad({ sequence: -1 }, "negative sequence");
bad({ sequence: 1.5 }, "fractional sequence");
bad({ sequence: "7" }, "string sequence");
assert.equal(mod.parseEvent({ ...good, sequence: 0 }).sequence, 0);
bad({ eventId: "" }, "empty eventId");
bad({ stateDigest: "" }, "empty stateDigest");
bad({ occurredAt: "" }, "empty occurredAt");
bad({ subjectRef: undefined }, "missing subjectRef");
bad({ eventType: undefined }, "missing eventType");

// Authority: OBSERVE is the only admissible boundary, and the default.
for (const boundary of ["SELECT", "CONSTRUCT", "DO"]) bad({ authorityBoundary: boundary }, boundary);
const noBoundary = { ...good };
delete noBoundary.authorityBoundary;
assert.equal(mod.parseEvent(noBoundary).authorityBoundary, "OBSERVE");

// Nullable wire form: unannotated refs and payload are null on the wire.
const nulled = mod.parseEvent({ ...good, evidenceRef: null, receiptRef: null, payload: null });
assert.equal(nulled.evidenceRef, null);
assert.equal(nulled.receiptRef, null);
assert.equal(nulled.payload, null);
const omitted = { ...good };
for (const k of ["evidenceRef", "receiptRef", "payload"]) delete omitted[k];
assert.doesNotThrow(() => mod.parseEvent(omitted));
bad({ evidenceRef: 5 }, "numeric evidenceRef");
bad({ payload: [1] }, "array payload");

// Passthrough: unknown wire keys are preserved, not stripped.
assert.equal(mod.parseEvent({ ...good, extra: "kept" }).extra, "kept");
assert.throws(() => mod.parseEvent(null), { name: "ZodError" });
assert.throws(() => mod.parseEvent("event"), { name: "ZodError" });

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_EVENTS_PASS", fields: Object.keys(good).length }));
