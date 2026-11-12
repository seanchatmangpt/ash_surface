// Fragment runner: wraps a raw render_* Zod expression in `import { z } from "zod"`
// and runs safeParse cases.
// usage: node fragment_runner.mjs <input.json>   (or JSON on stdin when no arg)
// input: {"expression": "z.string().min(2)", "cases": [{"label": "..", "expect": true, "payload": ..}]}
// Prints one JSON array: [{label, expect, success, issues}].
import { readFileSync } from "node:fs";
import { z } from "zod";

const file = process.argv[2];
const spec = JSON.parse(readFileSync(file ?? 0, "utf8"));
const schema = new Function("z", `return (${spec.expression});`)(z);
const out = (spec.cases ?? []).map((c) => {
  const r = schema.safeParse(c.payload);
  return {
    label: c.label,
    expect: c.expect,
    success: r.success,
    issues: r.success ? [] : r.error.issues.map((i) => i.path.join(".") + ": " + i.code),
  };
});
process.stdout.write(JSON.stringify(out));
