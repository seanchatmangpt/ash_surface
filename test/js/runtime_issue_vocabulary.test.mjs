import test from "node:test";
import assert from "node:assert/strict";
import { VOCABULARY } from "../../priv/static/ash_surface_runtime.mjs";
import { z } from "zod";

test("issue vocabulary is frozen and pins the normalized shape", () => {
  assert.deepEqual(VOCABULARY.issueShapeKeys, ["path", "message", "code"]);
  assert.equal(Object.isFrozen(VOCABULARY.issueShapeKeys), true);
  assert.equal(Object.isFrozen(VOCABULARY.issueRefusalCodes), true);
  assert.ok(VOCABULARY.issueRefusalCodes.includes("INPUT_VALIDATION_FAILED"));
});

test("a real zod failure carries every vocabulary issue key", () => {
  const r = z.object({ a: z.string() }).safeParse({ a: 1 });
  assert.equal(r.success, false);
  for (const k of VOCABULARY.issueShapeKeys) assert.ok(k in r.error.issues[0]);
});
