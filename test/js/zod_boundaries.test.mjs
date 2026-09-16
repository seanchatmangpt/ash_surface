import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  SurfaceRuntimeError,
  surfaceActionSchema,
  observationProjectionSchema,
  planningEpisodeSchema,
  eventProjectionSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

// ---------------------------------------------------------------------------
// State-based boundary tables for the runtime's executable Zod schemas.
//
// Acceptance rows prove each schema admits a fully-populated lawful shape
// (every declared field, plus a passthrough key) and applies defaults to the
// minimal required shape. Rejection rows prove each missing required field,
// each wrong enum/literal (including authorityBoundary "DOUGH"), and wrong
// primitives produce Zod issues that name the offending path — issues are
// surfaced to the caller, never swallowed.
// ---------------------------------------------------------------------------

const fullSurfaceAction = {
  id: "todos:Todo:create",
  semanticId: "ash:Action/todos.create",
  resource: "Todo",
  action: "create",
  authorityBoundary: "CONSTRUCT",
  doAuthority: false,
  receiptRequired: false,
  evidenceRequired: true,
  possibleRefusals: ["REFUSED_NO_AUTHORITY", "REFUSED_UNKNOWN_SUBJECT"],
  profile: { transport: "http", weight: 7 },
  passthroughExtra: "kept",
};

const fullObservation = {
  observationId: "obs_1",
  exactSubject: "Todo:1",
  observedAt: "2026-09-15T00:00:00Z",
  stateDigest: "sha256:aa",
  facts: { status: "done", tags: [1, 2] },
  evidenceRefs: ["ev:1", "ev:2"],
  standing: "PARTIAL_ALIVE",
  projectionPurpose: "consumer_state_observation",
  authorityBoundary: "OBSERVE",
  passthroughExtra: 42,
};

const fullPlanningEpisode = {
  episodeId: "ep_1",
  worldStateRef: "ws:42",
  taskNetworkRef: "tn:7",
  plannerIdentity: "planner:v1",
  policyIdentity: "policy:v2",
  policyStanding: "VALID_STRONG_CYCLIC",
  candidateActions: [{ id: "todos:Todo:create" }, "todos:Todo:list"],
  authorityCeiling: "CONSTRUCT",
  passthroughExtra: null,
};

const fullEvent = {
  eventId: "evt_9",
  sequence: 42,
  subjectRef: "Todo:1",
  eventType: "updated",
  stateDigest: "sha256:bb",
  evidenceRef: "ev:9",
  receiptRef: null,
  payload: { after: { status: "done" } },
  occurredAt: "2026-09-15T00:00:01Z",
  authorityBoundary: "OBSERVE",
  passthroughExtra: true,
};

function assertAccepted(schema, payload, label) {
  const result = schema.safeParse(payload);
  assert.equal(result.success, true, `${label} must accept the full lawful shape: ${result.success ? "" : JSON.stringify(result.error.issues)}`);
  assert.deepEqual(result.data, payload, `${label} must preserve every provided field and passthrough keys`);
}

function assertDefaults(schema, payload, expected, label) {
  const result = schema.safeParse(payload);
  assert.equal(result.success, true, `${label} must accept the minimal required shape: ${result.success ? "" : JSON.stringify(result.error.issues)}`);
  assert.deepEqual(result.data, expected, `${label} must apply declared defaults`);
}

// Sentinel: set the field to this to mean "delete the key entirely".
const DELETE = Symbol("zod-boundaries.delete-field");

// Runs a rejection table. Each case deletes `field` (missing) or sets it to
// `value` (wrong enum/primitive) and asserts a Zod issue names that exact path
// with the expected issue code.
function rejectionTable(schemaName, schema, validShape, cases) {
  for (const { label, field, value, code } of cases) {
    test(`${schemaName} rejects ${label} (issue at "${field}", code ${code})`, () => {
      const payload = { ...validShape };
      delete payload.passthroughExtra;
      if (value === DELETE) {
        delete payload[field];
      } else {
        payload[field] = value;
      }

      const result = schema.safeParse(payload);
      assert.equal(result.success, false, `${schemaName} must reject ${label}`);

      const issues = result.error.issues;
      assert.ok(Array.isArray(issues) && issues.length > 0, `${schemaName} must surface Zod issues for ${label}`);

      // Accept an issue at the field itself or nested beneath it (e.g. an
      // invalid array element surfaces at "possibleRefusals.0").
      const match = issues.find((issue) => issue.path[0] === field);
      assert.ok(
        match,
        `${schemaName} must surface an issue at path "${field}" for ${label}; got paths ${JSON.stringify(issues.map((i) => i.path.join(".")))}`,
      );
      assert.equal(match.code, code, `${schemaName} issue code for ${label}`);
    });
  }
}

function missing(field) {
  return { label: `missing required field "${field}"`, field, value: DELETE, code: "invalid_type" };
}

function wrong(label, field, value, code = "invalid_type") {
  return { label, field, value, code };
}

// --- surfaceActionSchema ---------------------------------------------------

test("surfaceActionSchema accepts the full lawful shape with all fields", () => {
  assertAccepted(surfaceActionSchema, fullSurfaceAction, "surfaceActionSchema");
});

test("surfaceActionSchema applies defaults to the minimal required shape", () => {
  assertDefaults(
    surfaceActionSchema,
    { id: "a", resource: "R", action: "act" },
    {
      id: "a",
      semanticId: "ash:Action",
      resource: "R",
      action: "act",
      authorityBoundary: "DO",
      doAuthority: true,
      receiptRequired: true,
      evidenceRequired: false,
      possibleRefusals: [],
      profile: {},
    },
    "surfaceActionSchema",
  );
});

rejectionTable("surfaceActionSchema", surfaceActionSchema, fullSurfaceAction, [
  missing("id"),
  missing("resource"),
  missing("action"),
  wrong("authorityBoundary enum \"DOUGH\"", "authorityBoundary", "DOUGH", "invalid_value"),
  wrong("authorityBoundary primitive 7", "authorityBoundary", 7, "invalid_value"),
  wrong("id as number", "id", 42),
  wrong("id as empty string", "id", "", "too_small"),
  wrong("resource as boolean", "resource", true),
  wrong("action as object", "action", {}),
  wrong("semanticId as number", "semanticId", 3.14),
  wrong("doAuthority as string", "doAuthority", "true"),
  wrong("receiptRequired as number", "receiptRequired", 1),
  wrong("evidenceRequired as null", "evidenceRequired", null),
  wrong("possibleRefusals as bare string", "possibleRefusals", "REFUSED_NO_AUTHORITY"),
  wrong("possibleRefusals with non-string element", "possibleRefusals", [42]),
  wrong("profile as string", "profile", "nope"),
  wrong("profile as array", "profile", []),
]);

// --- observationProjectionSchema -------------------------------------------

test("observationProjectionSchema accepts the full lawful shape with all fields", () => {
  assertAccepted(observationProjectionSchema, fullObservation, "observationProjectionSchema");
});

test("observationProjectionSchema applies defaults to the minimal required shape", () => {
  assertDefaults(
    observationProjectionSchema,
    { observationId: "o", exactSubject: "S", observedAt: "T", stateDigest: "d", facts: {} },
    {
      observationId: "o",
      exactSubject: "S",
      observedAt: "T",
      stateDigest: "d",
      facts: {},
      evidenceRefs: [],
      standing: "ALIVE",
      projectionPurpose: "consumer_state_observation",
      authorityBoundary: "OBSERVE",
    },
    "observationProjectionSchema",
  );
});

rejectionTable("observationProjectionSchema", observationProjectionSchema, fullObservation, [
  missing("observationId"),
  missing("exactSubject"),
  missing("observedAt"),
  missing("stateDigest"),
  missing("facts"),
  wrong("authorityBoundary literal \"DOUGH\"", "authorityBoundary", "DOUGH", "invalid_value"),
  wrong("authorityBoundary as boolean", "authorityBoundary", true, "invalid_value"),
  wrong("observationId as number", "observationId", 42),
  wrong("exactSubject as boolean", "exactSubject", false),
  wrong("observedAt as array", "observedAt", []),
  wrong("stateDigest as object", "stateDigest", {}),
  wrong("stateDigest as empty string", "stateDigest", "", "too_small"),
  wrong("facts as number", "facts", 42),
  wrong("facts as string", "facts", "nope"),
  wrong("facts as array", "facts", ["not", "a", "record"]),
  wrong("evidenceRefs as bare string", "evidenceRefs", "ev:1"),
  wrong("evidenceRefs with non-string element", "evidenceRefs", [1]),
  wrong("standing as number", "standing", 7),
]);

// --- planningEpisodeSchema ---------------------------------------------------

test("planningEpisodeSchema accepts the full lawful shape with all fields", () => {
  assertAccepted(planningEpisodeSchema, fullPlanningEpisode, "planningEpisodeSchema");
});

test("planningEpisodeSchema applies defaults to the minimal required shape", () => {
  assertDefaults(
    planningEpisodeSchema,
    { episodeId: "e", worldStateRef: "ws", plannerIdentity: "p", policyIdentity: "pol" },
    {
      episodeId: "e",
      worldStateRef: "ws",
      plannerIdentity: "p",
      policyIdentity: "pol",
      policyStanding: "VALID_STRONG",
      candidateActions: [],
      authorityCeiling: "SELECT",
    },
    "planningEpisodeSchema",
  );
});

rejectionTable("planningEpisodeSchema", planningEpisodeSchema, fullPlanningEpisode, [
  missing("episodeId"),
  missing("worldStateRef"),
  missing("plannerIdentity"),
  missing("policyIdentity"),
  wrong("policyStanding enum \"DOUGH\"", "policyStanding", "DOUGH", "invalid_value"),
  wrong("authorityCeiling enum \"DO\" (valid action boundary, illegal ceiling)", "authorityCeiling", "DO", "invalid_value"),
  wrong("episodeId as number", "episodeId", 42),
  wrong("episodeId as empty string", "episodeId", "", "too_small"),
  wrong("worldStateRef as boolean", "worldStateRef", true),
  wrong("taskNetworkRef as number (not string/null)", "taskNetworkRef", 42),
  wrong("plannerIdentity as array", "plannerIdentity", []),
  wrong("policyIdentity as object", "policyIdentity", {}),
  wrong("policyStanding as number", "policyStanding", 1, "invalid_value"),
  wrong("candidateActions as string", "candidateActions", "not-an-array"),
  wrong("authorityCeiling as number", "authorityCeiling", 99, "invalid_value"),
]);

// --- eventProjectionSchema ---------------------------------------------------

test("eventProjectionSchema accepts the full lawful shape with all fields", () => {
  assertAccepted(eventProjectionSchema, fullEvent, "eventProjectionSchema");
});

test("eventProjectionSchema applies defaults to the minimal required shape", () => {
  assertDefaults(
    eventProjectionSchema,
    { eventId: "e", sequence: 0, subjectRef: "S", eventType: "created", stateDigest: "d", occurredAt: "T" },
    {
      eventId: "e",
      sequence: 0,
      subjectRef: "S",
      eventType: "created",
      stateDigest: "d",
      occurredAt: "T",
      authorityBoundary: "OBSERVE",
    },
    "eventProjectionSchema",
  );
});

rejectionTable("eventProjectionSchema", eventProjectionSchema, fullEvent, [
  missing("eventId"),
  missing("sequence"),
  missing("subjectRef"),
  missing("eventType"),
  missing("stateDigest"),
  missing("occurredAt"),
  wrong("authorityBoundary literal \"DOUGH\"", "authorityBoundary", "DOUGH", "invalid_value"),
  wrong("eventId as number", "eventId", 42),
  wrong("sequence as string", "sequence", "42"),
  wrong("sequence as float", "sequence", 1.5),
  wrong("sequence as negative int", "sequence", -1, "too_small"),
  wrong("subjectRef as boolean", "subjectRef", false),
  wrong("eventType as number", "eventType", 42),
  wrong("eventType as empty string", "eventType", "", "too_small"),
  wrong("stateDigest as array", "stateDigest", []),
  wrong("evidenceRef as number (not string/null)", "evidenceRef", 42),
  wrong("receiptRef as boolean (not string/null)", "receiptRef", true),
  wrong("payload as string (not record/null)", "payload", "nope"),
  wrong("payload as number (not record/null)", "payload", 42),
  wrong("occurredAt as float", "occurredAt", 9.5),
]);

// --- Issues surfaced to the caller, never swallowed --------------------------

test("parse() throws ZodError whose .issues are available to the caller", () => {
  const cases = [
    ["surfaceActionSchema", surfaceActionSchema, { ...fullSurfaceAction, authorityBoundary: "DOUGH" }, "authorityBoundary"],
    ["observationProjectionSchema", observationProjectionSchema, { ...fullObservation, facts: 42 }, "facts"],
    ["planningEpisodeSchema", planningEpisodeSchema, { ...fullPlanningEpisode, policyStanding: "DOUGH" }, "policyStanding"],
    ["eventProjectionSchema", eventProjectionSchema, { ...fullEvent, sequence: "42" }, "sequence"],
  ];

  for (const [name, schema, payload, path] of cases) {
    assert.throws(
      () => schema.parse(payload),
      (error) => {
        assert.ok(Array.isArray(error.issues) && error.issues.length > 0, `${name} error.issues must be an exposed non-empty array`);
        assert.ok(
          error.issues.some((issue) => issue.path.join(".") === path),
          `${name} thrown issues must name path "${path}"`,
        );
        return true;
      },
      `${name}.parse must throw on unlawful input`,
    );
  }
});

test("createClient surfaces contract Zod issues on SurfaceRuntimeError.issues instead of swallowing them", () => {
  const badAction = { ...fullSurfaceAction, authorityBoundary: "DOUGH" };
  assert.throws(
    () =>
      createClient({
        contract: {
          surfaceSchemaVersion: "0.1.0",
          ashManifestSchemaVersion: "1.1.0",
          manifest: {},
          surface: { profile: {}, actions: [badAction] },
        },
        transports: {},
      }),
    (error) => {
      assert.ok(error instanceof SurfaceRuntimeError);
      assert.equal(error.code, "INVALID_SURFACE_CONTRACT");
      assert.ok(Array.isArray(error.issues) && error.issues.length > 0, "runtime must expose parsed.error.issues to the caller");
      assert.ok(
        error.issues.some((issue) => issue.path.join(".") === "surface.actions.0.authorityBoundary"),
        `issues must name the offending action path; got ${JSON.stringify(error.issues.map((i) => i.path.join(".")))}`,
      );
      return true;
    },
  );
});

test("events.emit surfaces eventProjectionSchema issues (throws rather than swallowing)", () => {
  const client = createClient({
    contract: {
      surfaceSchemaVersion: "0.1.0",
      ashManifestSchemaVersion: "1.1.0",
      manifest: {},
      surface: { profile: {}, actions: [] },
    },
    transports: {},
  });

  assert.throws(
    () => client.events.emit({ ...fullEvent, sequence: "not-a-number" }),
    (error) =>
      Array.isArray(error.issues) &&
      error.issues.some((issue) => issue.path.join(".") === "sequence"),
    "emit must propagate the ZodError with issues",
  );
});

// --- Transport enum rejection ("carrier") ------------------------------------
// Transport is not a Zod field of these schemas (profile values are unknown by
// design); the transport enumeration is runtime-owned via KNOWN_TRANSPORTS, so
// its rejection rows are asserted against the runtime boundary directly.

function minimalContract(actions) {
  return {
    surfaceSchemaVersion: "0.1.0",
    ashManifestSchemaVersion: "1.1.0",
    manifest: {},
    surface: { profile: {}, actions },
  };
}

test("runtime rejects unknown preferred transport \"carrier\"", () => {
  assert.throws(
    () => createClient({ contract: minimalContract([]), transports: {}, prefer: "carrier" }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNKNOWN_TRANSPORT",
  );
});

test("runtime rejects an unknown transport adapter named \"carrier\"", () => {
  assert.throws(
    () => createClient({ contract: minimalContract([]), transports: { carrier: { async invoke() {} } } }),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNKNOWN_TRANSPORT",
  );
});

test("runtime rejects action profile transport \"carrier\" at inspect time", () => {
  const client = createClient({
    contract: minimalContract([{ ...fullSurfaceAction, profile: { transport: "carrier" } }]),
    transports: { http: { async invoke() { return {}; } } },
  });

  assert.throws(
    () => client.inspect("todos:Todo:create"),
    (error) => error instanceof SurfaceRuntimeError && error.code === "UNKNOWN_TRANSPORT",
  );
});
