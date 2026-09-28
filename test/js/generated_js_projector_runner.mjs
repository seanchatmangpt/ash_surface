import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for the JSDoc + Zod artifact manufactured by
// AshSurface.Projectors.JS.project_ir/2. The GENERATED module is imported and
// driven against the fixture truth sidecar:
//   { prefix, actions: [{ id, resource, action, actionType, authorityBoundary,
//     receiptRequired, descriptorKind, zod, validInput, invalidInput }] }

const [targetDir, fixturePath] = process.argv.slice(2);
if (!targetDir || !fixturePath) {
  throw new Error("usage: node generated_js_projector_runner.mjs <targetDir> <fixturePath>");
}

const fixture = JSON.parse(await readFile(fixturePath, "utf8"));
const truths = fixture.actions;

// The DO boundary is dispatch-INTENT only: any I/O or transport use trips here.
const trap = (name) => () => { throw new Error(`projected module touched ${name}`); };
globalThis.fetch = trap("fetch");
globalThis.WebSocket = trap("WebSocket");

const mod = await import(pathToFileURL(join(targetDir, `${fixture.prefix}.mjs`)).href);
const { ACTIONS, SCHEMAS, NAMESPACES, getAction, dispatchIntent } = mod;

// Descriptors: id-sorted, complete, frozen, truthful (incl. nil boundary stays null).
assert.deepEqual(ACTIONS.map((a) => a.id), truths.map((t) => t.id).sort());
for (const t of truths) {
  const d = getAction(t.id);
  assert.ok(Object.isFrozen(d));
  for (const key of ["resource", "action", "actionType", "authorityBoundary", "receiptRequired", "descriptorKind"]) {
    assert.deepEqual(d[key] ?? null, t[key] ?? null, `${t.id}.${key}`);
  }
}
assert.equal(ACTIONS.filter((a) => a.descriptorKind === "DISPATCH_INTENT").length, 1);

// Namespaces group the very same descriptors by resource.
assert.deepEqual(Object.keys(NAMESPACES).sort(), [...new Set(truths.map((t) => t.resource))].sort());
for (const t of truths) assert.equal(NAMESPACES[t.resource][t.action], getAction(t.id));

// Zod schemas from IR.Schema.zod: exactly the delegated ones; parse/reject.
const withZod = truths.filter((t) => t.zod !== null);
assert.deepEqual(Object.keys(SCHEMAS).sort(), withZod.map((t) => t.id).sort());
for (const t of withZod) {
  assert.deepEqual(SCHEMAS[t.id].parse(t.validInput), t.validInput);
  assert.throws(() => SCHEMAS[t.id].parse(t.invalidInput), { name: "ZodError" });
}

// DO-boundary law: only the DO action mints a frozen intent; all else refuse.
for (const t of truths) {
  if (t.descriptorKind === "DISPATCH_INTENT") {
    const intent = dispatchIntent(t.id, t.validInput ?? {});
    assert.deepEqual(intent, { kind: "DISPATCH_INTENT", actionId: t.id, input: SCHEMAS[t.id].parse(t.validInput ?? {}) });
    assert.ok(Object.isFrozen(intent));
    assert.throws(() => dispatchIntent(t.id, t.invalidInput), { name: "ZodError" });
  } else {
    assert.throws(() => dispatchIntent(t.id, t.validInput ?? {}), /REFUSED_NOT_DO_BOUNDARY/);
  }
}
assert.throws(() => dispatchIntent("Nope.missing", {}), /REFUSED_UNKNOWN_ACTION/);

console.log(JSON.stringify({ receipt: "GENERATED_JS_PROJECTOR_PASS", actions: truths.length }));
