// T16 zod runner: validates JSON payloads against emitted artifact schemas (real zod) and
// evaluates `js` cases (zod API behavior on the emitted schemas).
// usage: node zod_t16_runner.mjs <artifact.mjs> <cases.json>
// Output: JSON array. schema case -> {label, success, issues:["path: code"]} where issues of
// invalid_union are flattened (union branch errors included). js case -> {label, value|thrown}.
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";
import { z } from "zod";

const [artifact, casesFile] = process.argv.slice(2);
const { SCHEMAS } = await import(pathToFileURL(resolve(artifact)).href);
const cases = JSON.parse(readFileSync(casesFile, "utf8"));

const flat = (issues, base = []) =>
  issues.flatMap((i) => {
    const p = [...base, ...i.path];
    const here = { path: p.join("."), code: i.code };
    if (i.code === "invalid_union" && Array.isArray(i.errors))
      return [here, ...i.errors.flatMap((e) => flat(e, p))];
    return [here];
  });
const fmt = (l) => l.map((x) => `${x.path}: ${x.code}`);

const out = cases.map((c) => {
  if (c.js !== undefined) {
    try {
      const fn = new Function("S", "z", c.js);
      return { label: c.label, value: fn(SCHEMAS, z) ?? null };
    } catch (e) {
      return { label: c.label, thrown: String(e && e.message ? e.message : e), name: e && e.name };
    }
  }
  const schema = SCHEMAS[c.id];
  if (!schema) return { label: c.label, success: null, issues: ["unknown schema id " + c.id] };
  const r = schema.safeParse(c.payload);
  return { label: c.label, success: r.success, issues: r.success ? [] : fmt(flat(r.error.issues)) };
});
process.stdout.write(JSON.stringify(out));
