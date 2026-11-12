// Batch fragment runner: input {"specs":[{"kind","expression","cases":[{label,expect,payload}]}]}
// Prints {kind: [{label, expect, success}]} under real zod.
import { readFileSync } from "node:fs";
import { z } from "zod";

const spec = JSON.parse(readFileSync(process.argv[2] ?? 0, "utf8"));
const out = {};
for (const s of spec.specs) {
  const schema = new Function("z", `return (${s.expression});`)(z);
  out[s.kind] = s.cases.map((c) => ({
    label: c.label,
    expect: c.expect,
    success: schema.safeParse(c.payload).success,
  }));
}
process.stdout.write(JSON.stringify(out));
