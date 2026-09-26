import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

// ---------------------------------------------------------------------------
// Cross-language IR projection proof.
//
// The emitted artifact (tmp file) is manufactured by the Elixir projector
// `AshSurface.Projectors.JS.project_ir/2`; its truth contract is the
// `fixture.json` sidecar written by the same run. This suite imports the
// artifact and proves the exports parse and describe the fixture IR
// truthfully: descriptors, JSDoc namespaces, Zod schemas from IR.Schema.zod
// strings, and the DO-boundary law (dispatch-INTENT only, refusing factory,
// no execution path).
//
// Hermetic: the suite re-runs the targeted mix test to (re)manufacture the
// bridge before importing it; a failure there fails here — never a fabricated
// pass.
//
// Cross-runtime gate (same class as the playwright observation gate in
// playwright_accessibility.test.mjs and the FLOCK_TEST runtime gate): bridge
// manufacture requires the BEAM toolchain (`mix`). CI's node-only javascript
// job (no erlang/elixir installed) type-refuses to SKIP instead of failing on
// spawnSync ENOENT; the elixir job (`mix test.all` -> `test.js` -> `npm test`)
// and the zero-config-v2 battery run the suite for real with mix on PATH.
// ---------------------------------------------------------------------------

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const bridgeDir = path.join(repoRoot, "tmp", "js_projector");

function ensureBridge() {
  const mixTest = execFileSync(
    "mix",
    ["test", "test/ash_surface/projectors/js_projector_test.exs"],
    { cwd: repoRoot, stdio: "pipe", encoding: "utf8" }
  );
  return mixTest;
}

function mixAvailable() {
  try {
    execFileSync("mix", ["--version"], { cwd: repoRoot, stdio: "pipe" });
    return true;
  } catch (err) {
    if (err?.code === "ENOENT") return false;
    throw err; // mix exists but would not run: not a skip case, fail loudly
  }
}

const mixReady = mixAvailable();
const runtimeSkip = {
  skip: mixReady
    ? false
    : "mix (BEAM toolchain) not installed; cross-language bridge manufacture requires it — runs under `mix test.all` / zero-config-v2",
};

let mixOutput = null;
let fixture = null;
let artifactSource = null;
let artifactPath = null;
let ACTIONS = null;
let SCHEMAS = null;
let NAMESPACES = null;
let getAction = null;
let dispatchIntent = null;
let fixtureActions = null;

if (mixReady) {
  mixOutput = ensureBridge();

  fixture = JSON.parse(readFileSync(path.join(bridgeDir, "fixture.json"), "utf8"));
  artifactPath = path.join(bridgeDir, `${fixture.prefix}.mjs`);
  artifactSource = readFileSync(artifactPath, "utf8");

  // Importing the artifact IS the parse proof: a syntax error fails the suite.
  const artifact = await import(pathToFileURL(artifactPath).href);

  ({ ACTIONS, SCHEMAS, NAMESPACES, getAction, dispatchIntent } = artifact);
  fixtureActions = fixture.actions;
}

test("bridge was manufactured by a passing targeted mix run", runtimeSkip, () => {
  // execFileSync already fails this suite on a non-zero mix exit; the Result
  // line additionally proves tests ran and passed (no "Failed:" summary line
  // exists on a clean run).
  assert.match(mixOutput, /Result: \d+ passed/);
  assert.doesNotMatch(mixOutput, /Failed:/);
});

test("artifact source embeds IR.Schema.zod strings verbatim", runtimeSkip, () => {
  for (const action of fixtureActions) {
    if (action.zod !== null) {
      assert.ok(
        artifactSource.includes(action.zod),
        `artifact must embed the zod string for ${action.id} verbatim`
      );
    }
  }
});

test("ACTIONS lists every fixture action, id-sorted, nothing else", runtimeSkip, () => {
  const expected = fixtureActions.map((a) => a.id).sort();
  assert.deepEqual(ACTIONS.map((a) => a.id), expected);
});

test("descriptors describe the fixture IR truthfully", runtimeSkip, () => {
  for (const truth of fixtureActions) {
    const descriptor = getAction(truth.id);
    assert.notEqual(descriptor, null, `getAction(${truth.id}) must resolve`);
    assert.equal(descriptor.id, truth.id);
    assert.equal(descriptor.resource, truth.resource);
    assert.equal(descriptor.action, truth.action);
    assert.equal(descriptor.actionType, truth.actionType);
    assert.equal(descriptor.authorityBoundary, truth.authorityBoundary);
    assert.equal(descriptor.receiptRequired, truth.receiptRequired);
    assert.equal(descriptor.descriptorKind, truth.descriptorKind);
    assert.equal(descriptor.capabilityIri, truth.capabilityIri);
    assert.equal(descriptor.label, truth.label);
  }
});

test("descriptors are pure data: no execution members on any descriptor", runtimeSkip, () => {
  const dataFields = [
    "id",
    "resource",
    "action",
    "actionType",
    "authorityBoundary",
    "receiptRequired",
    "descriptorKind",
    "capabilityIri",
    "label",
    "schema",
  ].sort();

  for (const descriptor of ACTIONS) {
    assert.deepEqual(Object.keys(descriptor).sort(), dataFields);
    assert.ok(Object.isFrozen(descriptor));
  }
});

test("namespaces group descriptors by resource with shared identity", runtimeSkip, () => {
  assert.deepEqual(Object.keys(NAMESPACES).sort(), [
    ...new Set(fixtureActions.map((a) => a.resource)),
  ].sort());

  for (const truth of fixtureActions) {
    const member = NAMESPACES[truth.resource][truth.action];
    assert.equal(member, getAction(truth.id), `${truth.id} must be the same object in namespace and ACTIONS`);
  }
});

test("SCHEMAS carries exactly the fixture actions that delegated a zod string", runtimeSkip, () => {
  const withZod = fixtureActions.filter((a) => a.zod !== null).map((a) => a.id).sort();
  assert.deepEqual(Object.keys(SCHEMAS).sort(), withZod);

  for (const id of withZod) {
    assert.equal(typeof SCHEMAS[id].parse, "function", `${id} schema must be a Zod schema`);
  }
});

test("zod schemas parse valid fixture inputs and reject invalid ones", runtimeSkip, () => {
  for (const truth of fixtureActions) {
    if (truth.zod === null) {
      continue;
    }
    assert.deepEqual(
      SCHEMAS[truth.id].parse(truth.validInput),
      truth.validInput,
      `${truth.id} valid input must parse`
    );
    assert.throws(
      () => SCHEMAS[truth.id].parse(truth.invalidInput),
      { name: "ZodError" },
      `${truth.id} invalid input must surface a ZodError`
    );
  }
});

test("DO-boundary actions mint frozen dispatch intents (data only)", runtimeSkip, () => {
  const doActions = fixtureActions.filter((a) => a.descriptorKind === "DISPATCH_INTENT");
  assert.equal(doActions.length, 1);

  for (const truth of doActions) {
    const input = truth.validInput ?? {};
    const intent = dispatchIntent(truth.id, input);

    assert.equal(intent.kind, "DISPATCH_INTENT");
    assert.equal(intent.actionId, truth.id);
    assert.deepEqual(intent.input, SCHEMAS[truth.id].parse(input));
    assert.ok(Object.isFrozen(intent), "an intent is frozen data");
  }
});

test("non-DO actions refuse dispatch intents", runtimeSkip, () => {
  for (const truth of fixtureActions.filter((a) => a.descriptorKind !== "DISPATCH_INTENT")) {
    assert.throws(
      () => dispatchIntent(truth.id, truth.validInput ?? {}),
      /REFUSED_NOT_DO_BOUNDARY/
    );
  }
});

test("unknown actions refuse dispatch intents", runtimeSkip, () => {
  assert.throws(() => dispatchIntent("Nope.missing", {}), /REFUSED_UNKNOWN_ACTION/);
});

test("invalid input surfaces ZodError at the dispatch-intent boundary", runtimeSkip, () => {
  const [doAction] = fixtureActions.filter((a) => a.descriptorKind === "DISPATCH_INTENT");
  assert.throws(
    () => dispatchIntent(doAction.id, doAction.invalidInput),
    { name: "ZodError" }
  );
});
