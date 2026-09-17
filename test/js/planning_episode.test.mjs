import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
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

// ---------------------------------------------------------------------------
// Canonical digest law (chicago-episode-digest-036) — the JS twin.
//
// lib/ash_surface/planning_episode.ex defines episode identity as the SHA-256
// (lowercase hex) of the sorted-key JSON encoding (AshSurface.CanonicalJSON)
// of the episode wire record minus the derived `episodeId`, with `episodeId`
// minted as the "ep_" 16-hex prefix of that digest. The canonicalStringify
// below is the exact JS twin of CanonicalJSON.encode/1 (same shape as the
// receipt twin in consumer_e2e_runner.mjs): key-SORTED objects (JS object
// iteration is otherwise insertion-ordered — precisely the hazard the law
// removes), order-preserving arrays (list order is semantic), JSON scalars
// verbatim.
// ---------------------------------------------------------------------------

/** The same fixture episode as @golden_digest in
 * test/ash_surface/planning_episode_deep_test.exs. The Elixir golden and this
 * record must change in the same change, never independently. */
const GOLDEN_EPISODE_DIGEST =
  "f9c0365f24b5e1260969cfc6a601975b2348581739f3d09804f9a629043433a0";
const GOLDEN_EPISODE_ID = "ep_f9c0365f24b5e126";

function goldenEpisodeRecord() {
  return {
    worldStateRef: "obs_golden_ws",
    taskNetworkRef: "tn_golden_01",
    plannerIdentity: "ash_pplan:fond_hddl_solver",
    policyIdentity: "zoe:policy:strong_cyclic",
    policyStanding: "VALID_STRONG_CYCLIC",
    candidateActions: [
      { action: "select_intercessor", candidate: "person_01", score: 0.75 },
      { action: "select_driver", candidate: "person_02", meta: { k: [1, 2] } },
    ],
    authorityCeiling: "CONSTRUCT",
    episodeId: GOLDEN_EPISODE_ID,
  };
}

/** JS twin of AshSurface.CanonicalJSON.encode/1. */
function canonicalStringify(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalStringify).join(",")}]`;
  if (value !== null && typeof value === "object") {
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((k) => `${JSON.stringify(k)}:${canonicalStringify(value[k])}`)
      .join(",")}}`;
  }
  return JSON.stringify(value);
}

/** The episode digest law: sha256 over the record minus the derived episodeId. */
function episodeDigest(record) {
  const { episodeId: _derived, ...rest } = record;
  return crypto.createHash("sha256").update(canonicalStringify(rest)).digest("hex");
}

/** Reverses key insertion order at every object depth (arrays keep element
 * order — list order is semantic content, never canonicalized). */
function reverseKeyOrder(value) {
  if (Array.isArray(value)) return value.map(reverseKeyOrder);
  if (value !== null && typeof value === "object") {
    const reversed = {};
    for (const key of Object.keys(value).reverse()) reversed[key] = reverseKeyOrder(value[key]);
    return reversed;
  }
  return value;
}

test("digest twin: the wire record minus episodeId digests to the Elixir golden", () => {
  const record = goldenEpisodeRecord();
  assert.equal(episodeDigest(record), GOLDEN_EPISODE_DIGEST);

  // The digest subject survives the runtime's own parse unchanged: the
  // zod-parsed episode digests identically to the raw wire record.
  const parsed = planningEpisodeSchema.parse(record);
  assert.equal(episodeDigest(parsed), GOLDEN_EPISODE_DIGEST);
});

test("digest twin: episodeId re-derives as the ep_ prefix of the digest", () => {
  const record = goldenEpisodeRecord();
  assert.equal("ep_" + episodeDigest(record).slice(0, 16), record.episodeId);
  assert.equal("ep_" + GOLDEN_EPISODE_DIGEST.slice(0, 16), GOLDEN_EPISODE_ID);

  // No circularity: the derived episodeId is excluded from its own digest —
  // records differing ONLY in episodeId digest identically. (A consumer-side
  // fixture may carry an arbitrary id; only episodes minted by
  // PlanningEpisode.create/2 carry the re-derivable prefix.)
  const other = { ...record, episodeId: "ep_ffffffffffffffff" };
  assert.equal(episodeDigest(other), GOLDEN_EPISODE_DIGEST);
});

test("digest twin is order-invariant: deep key-insertion reversal never flips the digest", () => {
  const record = goldenEpisodeRecord();
  const reversed = reverseKeyOrder(record);

  // Self-check: the fixture was actually reordered (JS object key iteration
  // is insertion-ordered, so this reversal is a real byte-order change for a
  // raw stringify).
  assert.notEqual(JSON.stringify(record), JSON.stringify(reversed));

  assert.equal(episodeDigest(reversed), GOLDEN_EPISODE_DIGEST);
});

test("digest twin is value-sensitive: any record mutation flips the digest", () => {
  const mutations = [
    (record) => {
      record.worldStateRef = "obs_other";
    },
    (record) => {
      record.policyStanding = "REFUSED";
    },
    (record) => {
      record.candidateActions[0].score = 0.8;
    },
    (record) => {
      record.candidateActions.reverse();
    },
  ];

  for (const mutate of mutations) {
    const record = goldenEpisodeRecord();
    mutate(record);
    assert.notEqual(episodeDigest(record), GOLDEN_EPISODE_DIGEST);
  }
});

test("hazard pin: raw (unsorted) JSON.stringify is order-sensitive, which is why the law exists", () => {
  const rawDigest = (record) =>
    crypto.createHash("sha256").update(JSON.stringify(record)).digest("hex");

  const record = goldenEpisodeRecord();
  const reversed = reverseKeyOrder(record);

  // Structurally equal records, differently ordered — a raw unsorted
  // stringify leaks insertion order into the digest. This pins the exact
  // hazard the canonical sort removes; if JS ever makes object iteration
  // sorted, this row (not the law) must change.
  assert.notEqual(rawDigest(record), rawDigest(reversed));
  assert.equal(episodeDigest(record), episodeDigest(reversed));
});
