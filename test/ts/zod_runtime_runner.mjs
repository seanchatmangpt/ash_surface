// Zod runtime runner: imports a generated artifact and validates JSON cases.
// usage: node zod_runtime_runner.mjs <artifact.mjs> <cases.json>
// Prints one JSON array: [{id, label, expect, success, issues}].
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const [artifact, casesFile] = process.argv.slice(2);
if (!artifact || !casesFile) {
  console.error("usage: zod_runtime_runner.mjs <artifact.mjs> <cases.json>");
  process.exit(2);
}
const { SCHEMAS } = await import(pathToFileURL(resolve(artifact)).href);
const cases = JSON.parse(readFileSync(casesFile, "utf8"));
const out = cases.map((c) => {
  const schema = SCHEMAS[c.id];
  if (!schema) return { id: c.id, label: c.label, expect: c.expect, success: null, issues: ["unknown schema id"] };
  const r = schema.safeParse(c.payload);
  return {
    id: c.id,
    label: c.label,
    expect: c.expect,
    success: r.success,
    issues: r.success ? [] : r.error.issues.map((i) => i.path.join(".") + ": " + i.code),
  };
});
process.stdout.write(JSON.stringify(out));
