// Real-zod evaluator shared by the corpus. The Elixir runner shells out to this
// file to MINT probe verdicts (so `expected` comes from real execution of the
// Elixir-rendered expression), and the JS replay imports it to re-execute the same
// expression against the same probes. One executor, two callers: a verdict
// disagreement is a real bug in the rendered text or in the execution environment.
//
//   node zod_eval.mjs <cases.json>   cases: [{"zod": "<expr>", "value": <json>}]
//   -> prints a JSON array of booleans (safeParse success), one per case.

import fs from "node:fs";
import { pathToFileURL } from "node:url";
import { z } from "zod";

// Zod 4 `.regex("<string>")` throws at parse time; the guard-admitted string
// spelling must be converted to a RegExp at the embed site.
const STRING_REGEX = /\.regex\(("(?:[^"\\]|\\.)*")\)/g;

export function compileZod(expression) {
  const source = expression.replace(STRING_REGEX, (_m, literal) => `.regex(new RegExp(${literal}))`);
  return new Function("z", `return (${source});`)(z);
}

export function evaluate(cases) {
  const cache = new Map();
  return cases.map(({ zod, value }) => {
    if (!cache.has(zod)) cache.set(zod, compileZod(zod));
    return cache.get(zod).safeParse(value).success;
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const cases = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  process.stdout.write(JSON.stringify(evaluate(cases)));
}
