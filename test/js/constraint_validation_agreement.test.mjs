// Agreement runner for ConstraintValidator vs emitted Zod (lane w3-14).
// usage: node constraint_validation_agreement.test.mjs <schemas.mjs> <cases.json>
// schemas.mjs exports SCHEMAS {id: zodSchema}; cases: [{id, missing?, payload}].
// Prints a JSON array [{id, success, codes}]. With no args it is a no-op so
// `node --test test/js` globbing stays green; the driver is
// test/ash_surface/compiler/constraint_validator_test.exs.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const [schemas, casesFile] = process.argv.slice(2);
if (!schemas || !casesFile) {
  process.exit(0);
}
const { SCHEMAS } = await import(pathToFileURL(resolve(schemas)).href);
const cases = JSON.parse(readFileSync(casesFile, "utf8"));
const out = cases.map((c) => {
  const r = SCHEMAS[c.id].safeParse(c.missing ? undefined : c.payload);
  return {
    id: c.id,
    success: r.success,
    issues: r.success ? [] : r.error.issues.map((i) => ({ code: i.code, path: i.path })),
  };
});
process.stdout.write(JSON.stringify(out));
