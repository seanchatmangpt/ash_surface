import test from "node:test";
import assert from "node:assert/strict";
import {
  createClient,
  planningEpisodeSchema,
} from "../../priv/static/ash_surface_runtime.mjs";

// Golden field parity, frozen from lib/ash_surface/planning_episode.ex
// (AshSurface.PlanningEpisode.to_map/1 camelCase keys). If the Elixir shape
// changes, this golden list changes in the same change.
const GOLDEN_EPISODE_FIELDS = Object.freeze([
  "episodeId",
  "worldStateRef",
  "taskNetworkRef",
  "plannerIdentity",
  "policyIdentity",
  "policyStanding",
  "candidateActions",
  "authorityCeiling",
]);

// @type standing :: :VALID_STRONG | :VALID_STRONG_CYCLIC | :REFUSED
const GOLDEN_STANDINGS = Object.freeze([
  "VALID_STRONG",
  "VALID_STRONG_CYCLIC",
  "REFUSED",
]);

// `authority_ceiling` is strictly SELECT or CONSTRUCT, NEVER DO
// (AshSurface != Planner; create/2 raises ArgumentError on :DO).
const ADMITTED_CEILINGS = Object.freeze(["SELECT", "CONSTRUCT"]);

function episode(overrides = {}) {
  return {
    episodeId: "ep_0123456789abcdef",
    worldStateRef: "world:42",
    taskNetworkRef: null,
    plannerIdentity: "ash_pplan:fond",
    policyIdentity: "policy:strong-cyclic",
    policyStanding: "VALID_STRONG",
    candidateActions: [{ resource: "Todo", action: "create" }],
    authorityCeiling: "SELECT",
    ...overrides,
  };
}

function issuePaths(result) {
  return result.error.issues.map((issue) => issue.path.join("."));
}

function containsFunction(value) {
  if (typeof value === "function") return true;
  if (Array.isArray(value)) return value.some(containsFunction);
  if (value && typeof value === "object") {
    return Object.values(value).some(containsFunction);
  }
  return false;
}

test("parses a fully populated episode and freezes matching golden fields", () => {
  const input = episode();
  // Fixture self-check: canonical episode carries exactly the golden fields.
  assert.deepEqual(
    [...Object.keys(input)].sort(),
    [...GOLDEN_EPISODE_FIELDS].sort(),
  );

  const parsed = planningEpisodeSchema.parse(input);
  assert.deepEqual(
    [...Object.keys(parsed)].sort(),
    [...GOLDEN_EPISODE_FIELDS].sort(),
  );
  assert.equal(parsed.episodeId, "ep_0123456789abcdef");
  assert.equal(parsed.worldStateRef, "world:42");
  assert.equal(parsed.taskNetworkRef, null);
  assert.equal(parsed.plannerIdentity, "ash_pplan:fond");
  assert.equal(parsed.policyIdentity, "policy:strong-cyclic");
  assert.equal(parsed.policyStanding, "VALID_STRONG");
  assert.deepEqual(parsed.candidateActions, [
    { resource: "Todo", action: "create" },
  ]);
  assert.equal(parsed.authorityCeiling, "SELECT");
});

test("projects the Elixir defstruct defaults for a minimal episode", () => {
  const parsed = planningEpisodeSchema.parse({
    episodeId: "ep_0123456789abcdef",
    worldStateRef: "world:42",
    plannerIdentity: "ash_pplan:fond",
    policyIdentity: "policy:strong-cyclic",
  });

  // defstruct defaults: policy_standing: :VALID_STRONG,
  // candidate_actions: [], authority_ceiling: :SELECT, task_network_ref: nil.
  assert.equal(parsed.policyStanding, "VALID_STRONG");
  assert.deepEqual(parsed.candidateActions, []);
  assert.equal(parsed.authorityCeiling, "SELECT");
  assert.equal(parsed.taskNetworkRef, undefined);
});

test("taskNetworkRef parity: string | nil, optional", () => {
  for (const taskNetworkRef of ["tn: fond-plan", null, undefined]) {
    const result = planningEpisodeSchema.safeParse(episode({ taskNetworkRef }));
    assert.equal(result.success, true, `expected ${String(taskNetworkRef)} to parse`);
  }

  const refused = planningEpisodeSchema.safeParse(episode({ taskNetworkRef: 7 }));
  assert.equal(refused.success, false);
  assert.ok(issuePaths(refused).includes("taskNetworkRef"));
});

test("admits exactly the Elixir standing enum", () => {
  for (const policyStanding of GOLDEN_STANDINGS) {
    const result = planningEpisodeSchema.safeParse(episode({ policyStanding }));
    assert.equal(result.success, true, `expected ${policyStanding} to parse`);
  }

  for (const policyStanding of ["UNKNOWN", "valid_strong", "VALID_WEAK"]) {
    const refused = planningEpisodeSchema.safeParse(episode({ policyStanding }));
    assert.equal(refused.success, false, `expected ${policyStanding} to be refused`);
    assert.ok(issuePaths(refused).includes("policyStanding"));
  }
});

test("authorityCeiling admits only SELECT/CONSTRUCT; DO is never admitted", () => {
  for (const authorityCeiling of ADMITTED_CEILINGS) {
    const result = planningEpisodeSchema.safeParse(episode({ authorityCeiling }));
    assert.equal(result.success, true, `expected ${authorityCeiling} to parse`);
    assert.equal(result.data.authorityCeiling, authorityCeiling);
  }

  // The JS mirror of the Elixir ArgumentError: an episode can never carry
  // execution authority, so a DO ceiling is malformed, not defaulted.
  for (const authorityCeiling of ["DO", "do", "OBSERVE", "SUPER"]) {
    const refused = planningEpisodeSchema.safeParse(episode({ authorityCeiling }));
    assert.equal(refused.success, false, `expected ${authorityCeiling} to be refused`);
    assert.ok(issuePaths(refused).includes("authorityCeiling"));
  }

  // No input shape can parse to a DO ceiling: every admitted parse lands in
  // the admitted set.
  const defaulted = planningEpisodeSchema.parse(episode({ authorityCeiling: undefined }));
  assert.ok(ADMITTED_CEILINGS.includes(defaulted.authorityCeiling));
});

test("parsed episodes are inert plan state: no dispatch surface on any field", () => {
  const parsed = planningEpisodeSchema.parse(
    episode({
      candidateActions: [
        { id: "todos:Todo:create", authorityBoundary: "DO", transport: "http" },
      ],
    }),
  );

  // Even DO-shaped candidates inside an episode stay plain data: the schema
  // never attaches behavior, so a candidate is a plan fact, never a command.
  assert.equal(containsFunction(parsed), false);
  assert.deepEqual(parsed.candidateActions, [
    { id: "todos:Todo:create", authorityBoundary: "DO", transport: "http" },
  ]);
});

test("no dispatch from an episode: episode state never contacts a transport", () => {
  let dispatches = 0;
  const transports = {
    http: {
      async invoke() {
        dispatches += 1;
        return { ok: true };
      },
    },
  };

  const client = createClient({
    contract: {
      surfaceSchemaVersion: "0.1.0",
      ashManifestSchemaVersion: "1.1.0",
      manifest: {},
      surface: { profile: {}, actions: [] },
    },
    transports,
  });

  const parsed = planningEpisodeSchema.parse(
    episode({
      candidateActions: [{ id: "todos:Todo:create", authorityBoundary: "DO" }],
    }),
  );

  // Reading the episode (including its candidates) dispatches nothing, and
  // the client exposes no episode-keyed entry point that could.
  assert.equal(dispatches, 0);
  assert.deepEqual(
    Object.keys(client).filter((key) => /episode/i.test(key)),
    [],
  );

  // An episode grants no action client: its candidates cannot be dispatched
  // through the runtime even by id.
  assert.equal(client.get("todos:Todo:create"), null);
  assert.equal(dispatches, 0);
});

test("rejects malformed episodes via the zod schema path", () => {
  for (const notAnObject of [null, [], "ep_1", 42, true]) {
    const refused = planningEpisodeSchema.safeParse(notAnObject);
    assert.equal(refused.success, false, `expected ${String(notAnObject)} to be refused`);
  }

  for (const required of ["episodeId", "worldStateRef", "plannerIdentity", "policyIdentity"]) {
    const shape = episode();
    delete shape[required];
    const refused = planningEpisodeSchema.safeParse(shape);
    assert.equal(refused.success, false, `expected missing ${required} to be refused`);
    assert.ok(issuePaths(refused).includes(required));
  }

  for (const empty of ["episodeId", "worldStateRef", "plannerIdentity", "policyIdentity"]) {
    const refused = planningEpisodeSchema.safeParse(episode({ [empty]: "" }));
    assert.equal(refused.success, false, `expected empty ${empty} to be refused`);
    assert.ok(issuePaths(refused).includes(empty));
  }

  const notAnArray = planningEpisodeSchema.safeParse(
    episode({ candidateActions: "create Todo" }),
  );
  assert.equal(notAnArray.success, false);
  assert.ok(issuePaths(notAnArray).includes("candidateActions"));
});
