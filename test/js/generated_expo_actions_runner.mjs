import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for a manufactured `<prefix>.actions.mjs`.
// spec: { prefix, expected: [{ id, resource, action, semanticId,
//   authorityBoundary, doAuthority, receiptRequired }], descriptorKeys: [...] }

const [targetDir, specPath] = process.argv.slice(2);
if (!targetDir || !specPath) {
  throw new Error("usage: node generated_expo_actions_runner.mjs <targetDir> <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));
const mod = await import(pathToFileURL(join(targetDir, `${spec.prefix}.actions.mjs`)).href);

assert.deepEqual(Object.keys(mod).sort(), ["ACTIONS", "getAction", "getAuthorityBoundary", "hasDoAuthority"]);

// Exactly the admitted actions, id-sorted, no duplicates.
const ids = mod.ACTIONS.map((a) => a.id);
assert.deepEqual(ids, spec.expected.map((e) => e.id));
assert.equal(new Set(ids).size, ids.length);

// The admitted set is frozen: a client cannot rewrite boundaries in place.
assert.ok(Object.isFrozen(mod.ACTIONS));
assert.throws(() => mod.ACTIONS.push({ id: "forged" }), TypeError);
assert.throws(() => { mod.ACTIONS.length = 0; }, TypeError);
assert.equal(mod.ACTIONS.length, spec.expected.length);

for (const want of spec.expected) {
  const got = mod.getAction(want.id);
  assert.ok(got, `getAction(${want.id})`);
  for (const key of spec.descriptorKeys) assert.ok(key in got, `${want.id} lacks descriptor key ${key}`);
  for (const key of ["resource", "action", "semanticId", "authorityBoundary", "doAuthority", "receiptRequired"]) {
    assert.deepEqual(got[key] ?? null, want[key] ?? null, `${want.id}.${key}`);
  }
  // Delegated facts are read, never derived: doAuthority only when delegated true.
  assert.equal(mod.hasDoAuthority(want.id), want.doAuthority === true);
  assert.equal(mod.getAuthorityBoundary(want.id), want.authorityBoundary ?? null);
}

// Fail closed on the unknown: null / false, never a fabricated OBSERVE admission.
for (const unknown of ["", "nope", "__proto__", "constructor", "Ghost#read", undefined, null]) {
  assert.equal(mod.getAction(unknown), null);
  assert.equal(mod.hasDoAuthority(unknown), false);
  assert.equal(mod.getAuthorityBoundary(unknown), null);
}

console.log(JSON.stringify({ receipt: "GENERATED_EXPO_ACTIONS_PASS", actions: ids.length }));
