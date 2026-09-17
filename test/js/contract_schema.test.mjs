import test from "node:test";
import assert from "node:assert/strict";
import {
  ashSurfaceContractSchema,
  createClient,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";

// ---------------------------------------------------------------------------
// Direct boundary table for ashSurfaceContractSchema — the runtime envelope
// schema that createClient.parseContract runs on every client construction.
// Until gapfix-test-surface-015 this export had zero DIRECT tests (its only
// exercise was indirect, through createClient happy paths and the frozen v2
// digest fixtures). These rows pin the schema itself: acceptance of the full
// lawful shape, defaults on the minimal shape, per-field rejections with
// issue paths, and passthrough of undeclared keys.
//
// Producer-or-remove decision (gapfix-test-surface-015, ledgered): the
// optional identity rows `ontologyDigest` / `applicationReleaseIdentity`
// have NO live producer in the current Elixir surface pipeline
// (AshSurface.contract/2 emits surfaceSchemaVersion, ashManifestSchemaVersion,
// generatorIdentity, manifestDigest, marketplaceIdentity, manifest, surface —
// nothing else). The witnessed producer is upstream IR-era generation (the
// frozen F5 fixture in digest_cross_language_v2.test.mjs carries real values,
// e.g. "ash-surface-wt/v43@282f3ca"). Decision:
//   - PRODUCER: refused — the surface boundary receives no ontology or
//     release input, so emitting either digest here would fabricate
//     delegated provenance (hashing nothing, or re-deriving upstream facts).
//   - REMOVE: refused — F5 is a witnessed real wire form; deleting the rows
//     would silently downgrade those fields from typed to unvalidated
//     passthrough.
//   - KEPT as typed optional delegated-extension rows: present values are
//     validated (rows below reject non-strings), absent values stay absent
//     (no defaults are fabricated), and passthrough keeps undeclared
//     envelope extensions digestible.
// ---------------------------------------------------------------------------

const fullAction = {
  id: "todos:Todo:create",
  semanticId: "ash:Action/todos.create",
  resource: "Todo",
  action: "create",
  authorityBoundary: "CONSTRUCT",
  doAuthority: false,
  receiptRequired: false,
  evidenceRequired: true,
  possibleRefusals: ["REFUSED_NO_AUTHORITY"],
  profile: { transport: "http" },
};

const fullContract = {
  surfaceSchemaVersion: "26.9.16",
  ashManifestSchemaVersion: "1.0.0",
  generatorIdentity: "ash_surface:v26.9.16",
  manifestDigest: "a".repeat(64),
  ontologyDigest: "b".repeat(64),
  marketplaceIdentity: "ggen-marketplace:v26.9.16",
  applicationReleaseIdentity: "my_app@2.1.0",
  manifest: { entrypoints: [], resources: [] },
  surface: { profile: { tier: "gold" }, actions: [fullAction] },
  undeclaredEnvelopeExtension: { kept: true },
};

function minimal() {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions: [] },
  };
}

// --- acceptance -------------------------------------------------------------

test("ashSurfaceContractSchema accepts the full lawful contract with every declared field", () => {
  const result = ashSurfaceContractSchema.safeParse(fullContract);
  assert.equal(result.success, true, `full contract must be admitted: ${result.success ? "" : JSON.stringify(result.error.issues)}`);
  assert.deepEqual(result.data, fullContract, "every provided field must survive parsing unchanged");
});

test("ashSurfaceContractSchema applies surface defaults to the minimal lawful contract", () => {
  const result = ashSurfaceContractSchema.safeParse(minimal());
  assert.equal(result.success, true);
  assert.deepEqual(result.data, {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions: [] },
  });
});

test("absent optional identity fields stay absent — no identity is fabricated", () => {
  const result = ashSurfaceContractSchema.safeParse(minimal());
  for (const field of [
    "generatorIdentity",
    "manifestDigest",
    "ontologyDigest",
    "marketplaceIdentity",
    "applicationReleaseIdentity",
  ]) {
    assert.equal(field in result.data, false, `${field} must not be defaulted into existence`);
  }
});

test("undeclared top-level envelope keys pass through (passthrough contract)", () => {
  const result = ashSurfaceContractSchema.safeParse(minimal());
  const withExtension = ashSurfaceContractSchema.safeParse({
    ...minimal(),
    undeclaredEnvelopeExtension: { kept: true },
  });
  assert.equal(withExtension.success, true);
  assert.deepEqual(withExtension.data.undeclaredEnvelopeExtension, { kept: true });
});

// --- rejection rows ----------------------------------------------------------

function rejects(label, mutate, path, code) {
  test(`ashSurfaceContractSchema rejects ${label} (issue at "${path}", code ${code})`, () => {
    const payload = minimal();
    mutate(payload);
    const result = ashSurfaceContractSchema.safeParse(payload);
    assert.equal(result.success, false, `must reject ${label}`);
    const issue = result.error.issues.find((candidate) => candidate.path.join(".") === path);
    assert.ok(issue, `expected an issue at "${path}"; got ${JSON.stringify(result.error.issues.map((i) => i.path.join(".")))}`);
    assert.equal(issue.code, code);
  });
}

rejects("missing surfaceSchemaVersion", (p) => delete p.surfaceSchemaVersion, "surfaceSchemaVersion", "invalid_type");
rejects("surfaceSchemaVersion as number", (p) => { p.surfaceSchemaVersion = 42; }, "surfaceSchemaVersion", "invalid_type");
rejects("empty surfaceSchemaVersion", (p) => { p.surfaceSchemaVersion = ""; }, "surfaceSchemaVersion", "too_small");
rejects("missing ashManifestSchemaVersion", (p) => delete p.ashManifestSchemaVersion, "ashManifestSchemaVersion", "invalid_type");
rejects("empty ashManifestSchemaVersion", (p) => { p.ashManifestSchemaVersion = ""; }, "ashManifestSchemaVersion", "too_small");
rejects("missing manifest", (p) => delete p.manifest, "manifest", "invalid_type");
rejects("manifest as string", (p) => { p.manifest = "not-a-record"; }, "manifest", "invalid_type");
rejects("manifest as array", (p) => { p.manifest = []; }, "manifest", "invalid_type");
rejects("missing surface", (p) => delete p.surface, "surface", "invalid_type");
rejects("surface as string", (p) => { p.surface = "nope"; }, "surface", "invalid_type");
rejects("surface.actions as object", (p) => { p.surface = { profile: {}, actions: { id: "x" } }; }, "surface.actions", "invalid_type");
rejects("surface.profile as string", (p) => { p.surface = { profile: "nope", actions: [] }; }, "surface.profile", "invalid_type");
rejects("generatorIdentity as number", (p) => { p.generatorIdentity = 7; }, "generatorIdentity", "invalid_type");
rejects("manifestDigest as boolean", (p) => { p.manifestDigest = true; }, "manifestDigest", "invalid_type");
rejects("ontologyDigest as number (typed delegated-extension row)", (p) => { p.ontologyDigest = 42; }, "ontologyDigest", "invalid_type");
rejects("marketplaceIdentity as null", (p) => { p.marketplaceIdentity = null; }, "marketplaceIdentity", "invalid_type");
rejects("applicationReleaseIdentity as number (typed delegated-extension row)", (p) => { p.applicationReleaseIdentity = 42; }, "applicationReleaseIdentity", "invalid_type");

test("a malformed action inside surface.actions surfaces an issue naming its exact path", () => {
  const payload = minimal();
  payload.surface.actions = [
    { ...fullAction, id: "todos:Todo:create" },
    { ...fullAction, authorityBoundary: "DOUGH" },
  ];

  const result = ashSurfaceContractSchema.safeParse(payload);
  assert.equal(result.success, false);
  const issue = result.error.issues.find((candidate) => candidate.path.join(".") === "surface.actions.1.authorityBoundary");
  assert.ok(issue, `expected an issue at surface.actions.1.authorityBoundary; got ${JSON.stringify(result.error.issues.map((i) => i.path.join(".")))}`);
  assert.equal(issue.code, "invalid_value");
});

// --- the schema is the exact boundary createClient enforces -------------------

test("createClient refuses a contract the schema rejects (non-string ontologyDigest)", () => {
  assert.throws(
    () => createClient({ contract: { ...minimal(), ontologyDigest: 42 }, transports: {} }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "INVALID_SURFACE_CONTRACT",
  );
});
