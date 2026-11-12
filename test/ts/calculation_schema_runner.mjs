// usage: node calculation_schema_runner.mjs <input.json>
// input: {zod: "<expr over z>", cases: [{label,payload}]}; prints [{label,success}].
import { readFileSync } from "node:fs";
import { z } from "zod";

const { zod, cases } = JSON.parse(readFileSync(process.argv[2], "utf8"));
const schema = new Function("z", `return (${zod});`)(z);
process.stdout.write(
  JSON.stringify(cases.map((c) => ({ label: c.label, success: schema.safeParse(c.payload).success }))),
);
