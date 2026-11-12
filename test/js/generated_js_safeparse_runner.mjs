import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { ZodError } from "zod";

// L17 court: the safeParse INPUT_VALIDATION_FAILED envelope of the GENERATED
// dispatchIntent (L07/L08's law). The projected module is imported and driven
// under real Node — no mocks. Spec sidecar:
//   { targetDir, prefix, dispatchId, descriptorId, validInput,
//     invalidInputs: [{ label, input, expectIssueFor }],
//     unknownId }
//
// Law: bad input throws an error with code INPUT_VALIDATION_FAILED whose
// detail.issues = [{ path (dot-joined string), message, code }]; no raw
// ZodError escapes; REFUSED_* refusals are unchanged.

const specPath = process.argv[2];
if (!specPath) {
  throw new Error("usage: node generated_js_safeparse_runner.mjs <specPath>");
}

const spec = JSON.parse(await readFile(specPath, "utf8"));

// The DO boundary is dispatch-INTENT only: any I/O or transport use trips here.
const trap = (name) => () => { throw new Error(`projected module touched ${name}`); };
globalThis.fetch = trap("fetch");
globalThis.WebSocket = trap("WebSocket");

const mod = await import(pathToFileURL(join(spec.targetDir, `${spec.prefix}.mjs`)).href);
const { dispatchIntent } = mod;

// Valid input still mints the frozen intent with parsed data.
const intent = dispatchIntent(spec.dispatchId, spec.validInput);
assert.deepEqual(intent, {
  kind: "DISPATCH_INTENT",
  actionId: spec.dispatchId,
  input: spec.validInput,
});
assert.ok(Object.isFrozen(intent), "intent must stay frozen");

// Invalid inputs: the envelope, never a raw ZodError.
for (const bad of spec.invalidInputs) {
  let thrown = null;
  try {
    dispatchIntent(spec.dispatchId, bad.input);
  } catch (e) {
    thrown = e;
  }
  assert.ok(thrown, `${bad.label}: expected a throw`);
  assert.equal(thrown.code, "INPUT_VALIDATION_FAILED", `${bad.label}: code`);
  assert.notEqual(thrown.name, "ZodError", `${bad.label}: raw ZodError escaped`);
  assert.ok(!(thrown instanceof ZodError), `${bad.label}: raw ZodError instance escaped`);
  assert.equal(typeof thrown.message, "string");
  assert.ok(thrown.message.includes(spec.dispatchId), `${bad.label}: message names the action`);

  const issues = thrown.detail?.issues;
  assert.ok(Array.isArray(issues) && issues.length > 0, `${bad.label}: detail.issues non-empty`);
  for (const issue of issues) {
    assert.equal(typeof issue.path, "string", `${bad.label}: path is a dot-joined string`);
    assert.equal(typeof issue.message, "string");
    assert.ok(issue.message.length > 0, `${bad.label}: message non-empty`);
    assert.equal(typeof issue.code, "string");
    assert.ok(issue.code.length > 0, `${bad.label}: code non-empty`);
  }
  const paths = issues.map((i) => i.path);
  assert.ok(
    paths.includes(bad.expectIssueFor),
    `${bad.label}: expected an issue at path ${bad.expectIssueFor}, got ${JSON.stringify(paths)}`,
  );
}

// REFUSED_* refusals are unchanged and never carry the envelope code.
assert.throws(() => dispatchIntent(spec.unknownId, {}), /REFUSED_UNKNOWN_ACTION/);
try {
  dispatchIntent(spec.unknownId, {});
} catch (e) {
  assert.equal(e.refusal, "REFUSED_UNKNOWN_ACTION");
  assert.notEqual(e.code, "INPUT_VALIDATION_FAILED");
}
assert.throws(() => dispatchIntent(spec.descriptorId, {}), /REFUSED_NOT_DO_BOUNDARY/);
try {
  dispatchIntent(spec.descriptorId, {});
} catch (e) {
  assert.equal(e.refusal, "REFUSED_NOT_DO_BOUNDARY");
  assert.notEqual(e.code, "INPUT_VALIDATION_FAILED");
}

console.log(
  JSON.stringify({
    receipt: "GENERATED_JS_SAFEPARSE_PASS",
    invalidCases: spec.invalidInputs.length,
    refusals: 2,
  }),
);
