import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// Consumer execution receipt for a manufactured `<prefix>.schemas.mjs`.
// Imports the GENERATED module and drives its Zod schemas with the spec the
// ExUnit caller supplies:
//   { prefix, expectedIds, cases: [{ id, safeName, valid: [...], invalid: [...] }],
//     outputValid: [...], outputInvalid: [...] }
// Prints one JSON receipt line. Behaviour only: parse accepts/rejects.

const [targetDir, specPath] = process.argv.slice(2);
if (!targetDir || !specPath) {
  throw new Error("usage: node generated_expo_schemas_runner.mjs <targetDir> <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));
const mod = await import(pathToFileURL(join(targetDir, `${spec.prefix}.schemas.mjs`)).href);

// SCHEMAS binds exactly the admitted actions, each with an input/output pair.
assert.deepEqual(Object.keys(mod.SCHEMAS).sort(), [...spec.expectedIds].sort());

let accepted = 0;
let rejected = 0;

for (const c of spec.cases ?? []) {
  const pair = mod.SCHEMAS[c.id];
  assert.ok(pair, `SCHEMAS is missing ${c.id}`);

  // Sanitized identifier exports are the very schemas SCHEMAS binds.
  if (c.safeName) {
    assert.equal(mod[`${c.safeName}_inputSchema`], pair.input, `${c.id} input export`);
    assert.equal(mod[`${c.safeName}_outputSchema`], pair.output, `${c.id} output export`);
  }

  for (const input of c.valid) {
    const result = pair.input.safeParse(input);
    assert.ok(result.success, `${c.id} must accept ${JSON.stringify(input)}`);
    // passthrough: parsed data keeps every supplied key.
    for (const key of Object.keys(input)) assert.ok(key in result.data, `${c.id} dropped ${key}`);
    accepted += 1;
  }

  for (const input of c.invalid) {
    assert.equal(
      pair.input.safeParse(input).success,
      false,
      `${c.id} must reject ${JSON.stringify(input)}`,
    );
    rejected += 1;
  }

  // Extra keys survive the boundary (passthrough), never silently stripped.
  if (c.valid.length > 0) {
    const probe = { ...c.valid[0], __extra: "kept" };
    assert.equal(pair.input.parse(probe).__extra, "kept");
  }

  // Output boundary: success flag required, receiptRef/error strings only.
  for (const out of spec.outputValid ?? []) {
    assert.ok(pair.output.safeParse(out).success, `${c.id} output must accept ${JSON.stringify(out)}`);
  }
  for (const out of spec.outputInvalid ?? []) {
    assert.equal(pair.output.safeParse(out).success, false, `${c.id} output must reject ${JSON.stringify(out)}`);
  }
}

console.log(
  JSON.stringify({ receipt: "GENERATED_EXPO_SCHEMAS_PASS", actions: Object.keys(mod.SCHEMAS).length, accepted, rejected }),
);
