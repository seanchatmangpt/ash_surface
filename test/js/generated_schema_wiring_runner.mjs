import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

// w3-02 court: generated filter/sort/page/response consts parse real payloads
// under real zod 4 (string-arg .regex would throw at parse).
const spec = JSON.parse(await readFile(process.argv[2], "utf8"));
const mod = await import(pathToFileURL(join(spec.targetDir, `${spec.prefix}.mjs`)).href);
const d = mod.getAction(spec.id);
assert.deepEqual(d.capabilityFlags, spec.flags);
assert.ok(Object.isFrozen(d.capabilityFlags));
for (const [slot, cases] of Object.entries(spec.cases)) {
  const schema = d[slot];
  assert.ok(schema, `descriptor.${slot} missing`);
  assert.equal(mod.QUERY_SCHEMAS[spec.id][slot.replace("Schema", "")], schema);
  for (const v of cases.valid) assert.ok(schema.safeParse(v).success, `${slot} valid ${JSON.stringify(v)}`);
  for (const v of cases.invalid) assert.ok(!schema.safeParse(v).success, `${slot} invalid ${JSON.stringify(v)}`);
}
console.log(JSON.stringify({ receipt: "GENERATED_SCHEMA_WIRING_PASS" }));
