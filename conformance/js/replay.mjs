// JavaScript replay of the AshSurface conformance corpus against the shipped
// runtime (priv/static/ash_surface_runtime.mjs).
//
// Every vector receives EXACTLY ONE status; nothing is silently skipped:
//
//   PASS              JS behavior equals `expected`
//   FAIL              JS behavior differs (a real cross-language bug), or a pinned
//                     divergence no longer holds
//   NOT_APPLICABLE    the JS runtime cannot express the vector; a reason is given
//   KNOWN_DIVERGENCE  JS differs AND the exact difference is pinned in
//                     known_divergences.mjs
//
// Ordinary ESM JavaScript, no TypeScript.

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  createClient,
  observationProjectionSchema,
  reconcileResultSchema,
  eventProjectionSchema,
  STANDING_VALUES,
  SurfaceRuntimeError,
} from "../../priv/static/ash_surface_runtime.mjs";
import {
  canonicalJson,
  canonicalTermDigest,
  eventStateDigest,
  receiptBinding,
  receiptHash,
  sha256Hex,
} from "./reference.mjs";
import { KNOWN_DIVERGENCES } from "./known_divergences.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
export const DEFAULT_CORPUS_DIR = path.join(here, "..");

const JS_TO_KIND = {
  UNKNOWN_TRANSPORT: "unknown_transport",
  UNSUPPORTED_TRANSPORT: "unsupported_transport",
  UNKNOWN_DIMENSION: "unknown_dimension",
  UNKNOWN_DIMENSION_CLASS: "unknown_dimension_class",
};
// JS raises one code for both "facts is not a map" and "a transport's facts is
// not a map"; Elixir distinguishes them. Either Elixir kind matches the JS code.
const FACTS_MAP_KINDS = ["facts_must_be_a_map", "transport_facts_must_be_a_map"];

const na = (reason) => ({ na: reason });

export function loadCorpus(dir = DEFAULT_CORPUS_DIR) {
  const manifest = JSON.parse(fs.readFileSync(path.join(dir, "MANIFEST.json"), "utf8"));
  const files = manifest.files.map((entry) => {
    const file = JSON.parse(fs.readFileSync(path.join(dir, entry.path), "utf8"));
    return { entry, ...file };
  });
  return { manifest, files };
}

// ---- client construction -----------------------------------------------------------

const ACTION_ID = "Conformance.Resource#act";

function contractWith(actions) {
  return {
    surfaceSchemaVersion: "26.10.1",
    ashManifestSchemaVersion: "1",
    manifest: {},
    surface: { profile: {}, actions },
  };
}

function action(profile, extra = {}) {
  return { id: ACTION_ID, resource: "Conformance.Resource", action: "act", profile, ...extra };
}

const okAdapter = (available) => ({
  invoke: async () => ({ data: { id: "1" } }),
  ...(available === false ? { available: false } : {}),
});

function errorOf(cause) {
  if (cause instanceof SurfaceRuntimeError) return cause;
  throw cause;
}

function errorKind(cause, expectedKind) {
  const error = errorOf(cause);
  if (error.code === "TRANSPORT_FACTS_MUST_BE_A_MAP") {
    return FACTS_MAP_KINDS.includes(expectedKind) ? expectedKind : "transport_facts_must_be_a_map";
  }
  return JS_TO_KIND[error.code] ?? `js:${error.code}`;
}

const DECISION_FIELDS = [
  "actionId",
  "available",
  "declared",
  "dimensions",
  "dispatchState",
  "fallback",
  "frontier",
  "preferred",
  "reason",
  "selected",
];

// Maps an Elixir-shaped selection input onto a JS client, or explains why it cannot.
function selectionClient(input) {
  const { declared, available, preferred = "http", profile = {} } = input;
  const known = ["http", "phoenix_channel"];
  let transport;

  if (!Array.isArray(declared) || !Array.isArray(available)) return na("declared/available must be lists");
  if (new Set(declared).size !== declared.length || new Set(available).size !== available.length) {
    return na("JS derives declared/available as sets; a repeated member cannot be stated");
  }
  if (declared.length === 1 && !known.includes(declared[0])) {
    transport = declared[0]; // profile.transport is validated by the runtime
  } else if (declared.length === 1) {
    transport = declared[0];
  } else if (declared.length === 2 && declared[0] === "http" && declared[1] === "phoenix_channel") {
    transport = "auto";
  } else if (declared.length === 2 && declared[0] === "phoenix_channel" && declared[1] === "http") {
    return na("JS declared order is fixed [http, phoenix_channel]; a reversed declared order cannot be stated");
  } else {
    return na("JS declared transports come from profile.transport (http | phoenix_channel | auto)");
  }

  const transports = {};
  const unknownAvailable = available.filter((name) => !known.includes(name));
  for (const name of unknownAvailable) transports[name] = okAdapter();

  const knownAvailable = available.filter((name) => known.includes(name));
  if (unknownAvailable.length === 0) {
    if (knownAvailable.some((name) => !declared.includes(name))) {
      return na("JS derives available from adapters intersected with declared; an undeclared adapter is ignored, so 'unadmitted' cannot be stated");
    }
    const declaredOrder = declared.filter((name) => knownAvailable.includes(name));
    if (JSON.stringify(declaredOrder) !== JSON.stringify(knownAvailable)) {
      return na("JS derives available in declared order; a different available order cannot be stated");
    }
  }
  for (const name of known) {
    if (knownAvailable.includes(name)) transports[name] = okAdapter();
    else if (declared.includes(name) && name === "http") transports[name] = okAdapter(false);
  }

  return {
    build() {
      const client = createClient({
        contract: contractWith([action({ transport, ...profile })]),
        transports,
        prefer: preferred,
      });
      return client;
    },
  };
}

function decisionView(decision) {
  return Object.fromEntries(DECISION_FIELDS.map((key) => [key, decision[key]]));
}

// ---- handlers: (input, expected) -> {na} | {actual, want} -----------------------------

const HANDLERS = {
  transport_selection(input, expected) {
    if (input.actionId === undefined) return na("JS clients always have an action id; an absent one cannot be stated");
    const plan = selectionClient(input);
    if (plan.na) return plan;
    return trySelection(plan, expected);
  },

  transport_facts_admission(input, expected) {
    const profile = input.profile;
    if (profile === null || typeof profile !== "object" || Array.isArray(profile)) {
      return na("a JS action always carries a profile record; a non-map profile cannot be stated");
    }
    const plan = selectionClient({
      declared: ["http", "phoenix_channel"],
      available: ["http", "phoenix_channel"],
      preferred: "http",
      profile,
    });
    let result;
    try {
      const decision = plan.build().inspect(ACTION_ID).decision;
      result = { ok: true, dimensions: decision.dimensions };
    } catch (cause) {
      result = { error: { kind: errorKind(cause, expected.error?.kind) } };
    }
    const want = expected.facts
      ? {
          ok: true,
          dimensions: Object.values(expected.facts).some((dims) => Object.keys(dims).length > 0)
            ? "declared"
            : "undelegated",
        }
      : { error: { kind: expected.error.kind } };
    return { actual: result, want };
  },

  canonical_json(input) {
    const canonical = canonicalJson(JSON.parse(input.json));
    return { actual: { canonical, sha256: sha256Hex(canonical) } };
  },

  receipt_digest(input) {
    return { actual: { sha256: sha256Hex(canonicalJson(JSON.parse(input.payloadJson))) } };
  },

  surface_contract_digest(input, expected) {
    const contract = JSON.parse(JSON.stringify(input.contract));
    createClient({ contract: JSON.parse(JSON.stringify(input.contract)) }); // Zod admission must accept it
    return { actual: { digest: canonicalTermDigest(contract) }, want: { digest: expected.digest } };
  },

  surface_contract_refusal(input, expected) {
    const kind = expected.error.kind;
    const profile = input.generation.profile ?? {};
    const actionProfile = Object.values(profile.actions ?? {})[0] ?? {};
    const boundary = {
      possible_refusal_not_a_refusal_code: { possibleRefusals: actionProfile.possibleRefusals },
      possible_refusals_must_be_strings: { possibleRefusals: actionProfile.possibleRefusals },
      evidence_required_must_be_boolean: { evidenceRequired: actionProfile.evidenceRequired },
    }[kind];
    if (!boundary) return na("JS consumes minted contracts; manifest/profile admission (contract minting) is Elixir-only");
    let rejected = false;
    try {
      createClient({ contract: contractWith([action({}, boundary)]) });
    } catch (cause) {
      rejected = errorOf(cause).code === "INVALID_SURFACE_CONTRACT";
    }
    return { actual: { rejected }, want: { rejected: true } };
  },

  receipt_binding(input, expected) {
    const receipt = input.receipt;
    if (expected.refusal && expected.refusal.standing !== "REFUSED_RECEIPT_DIGEST_MISMATCH") {
      return na("JS has no consequence-to-observation back-projection; this refusal precedes/excludes the digest check");
    }
    if (input.irAction !== undefined && input.irAction !== null && expected.event) {
      // subject resolution is projection logic; only the digest leg is JS-expressible
    }
    const verdict = receiptBinding(receipt);
    if (expected.refusal) {
      return { actual: { binding: verdict }, want: { binding: "mismatch" } };
    }
    const event = expected.event;
    const view = {
      binding: verdict,
      eventAdmitted: eventProjectionSchema.safeParse(event).success,
    };
    if (input.irAction === undefined || input.irAction === null) {
      view.stateDigest = eventStateDigest(event.subjectRef, event.sequence, event.eventType, receipt.consequence ?? {});
      view.receiptRef = receipt.receiptHash ?? receipt.receiptRef ?? null;
    }
    const want = { binding: "no_mismatch", eventAdmitted: true };
    if ("stateDigest" in view) {
      want.stateDigest = event.stateDigest;
      want.receiptRef = event.receiptRef;
    }
    return { actual: view, want };
  },

  refusal_vocabulary(input, expected) {
    const value = input.value;
    let refusalCode = false;
    try {
      createClient({ contract: contractWith([action({}, { possibleRefusals: [value] })]) });
      refusalCode = true;
    } catch (cause) {
      errorOf(cause);
    }
    const standingValid = observationProjectionSchema.safeParse({
      observationId: "o",
      exactSubject: "s",
      observedAt: "t",
      stateDigest: "d",
      facts: {},
      standing: value,
    }).success;
    const standingRefused = standingValid && !STANDING_VALUES.includes(value);
    return { actual: { refusalCode, standingValid, standingRefused } };
  },

  async reconcile_status(input, expected) {
    const verdict = input.verdict;
    const client = createClient({
      contract: contractWith([action({ transport: "http" })]),
      transports: { http: { invoke: async () => ({}), reconcile: async () => verdict } },
    });
    let admitted;
    try {
      const returned = await client.reconcile("cmd_1", "http");
      admitted = returned === verdict; // the adapter's own object, passthrough keys intact
    } catch (cause) {
      admitted = false;
      assert.equal(errorOf(cause).code, "INVALID_RECONCILE_RESULT");
    }
    assert.equal(reconcileResultSchema.safeParse(verdict).success, admitted, "schema and client agree");
    return { actual: { admitted } };
  },

  ir_codec(input, expected) {
    if (!expected.ok) return na("IR admission (from_map typed rejection) is Elixir-only; JS never constructs IR structs");
    return {
      actual: { digest: canonicalTermDigest(expected.ok.canonicalMap) },
      want: { digest: expected.ok.digest },
    };
  },

  async transport_outcome(input, expected) {
    return outcome(input, expected);
  },
};

function trySelection(plan, expected) {
  let actual;
  try {
    actual = { decision: decisionView(plan.build().inspect(ACTION_ID).decision) };
  } catch (cause) {
    actual = { error: { kind: errorKind(cause, expected.error?.kind) } };
  }
  const want = expected.decision
    ? { decision: Object.fromEntries(DECISION_FIELDS.map((key) => [key, expected.decision[key]])) }
    : { error: { kind: expected.error.kind } };
  return { actual, want };
}

const neverSettles = () => new Promise(() => {});

async function outcome(input, expected) {
  const { phase, cause } = input;
  const calls = { http: 0, phoenix_channel: 0 };
  const known = ["http", "phoenix_channel"];
  const available = input.available.filter((n) => known.includes(n));
  const primary = available.includes(input.preferred) ? input.preferred : available[0];
  const controller = new AbortController();
  const callOptions = {};

  const behavior = {
    adapter_rejected: () => Promise.reject(new Error("socket closed after write")),
    deadline_exceeded: neverSettles,
    abort_after_dispatch: neverSettles,
  };
  const transports = {};
  for (const name of known) {
    if (!available.includes(name)) {
      if (name === "http") transports.http = okAdapter(false);
      continue;
    }
    transports[name] = {
      invoke: async () => {
        calls[name] += 1;
        if (phase === "post_dispatch" && name === primary) return behavior[cause]();
        return { data: { id: "1" } };
      },
    };
  }

  if (cause === "deadline_exceeded") callOptions.timeoutMs = 20;
  if (cause === "abort_after_dispatch") {
    callOptions.signal = controller.signal;
    setTimeout(() => controller.abort(new Error("user navigated away")), 5);
  }
  if (cause === "signal_aborted_before_dispatch") {
    controller.abort(new Error("already aborted"));
    callOptions.signal = controller.signal;
  }
  if (cause === "invalid_command_id") callOptions.commandId = "";
  if (cause === "invalid_timeout") callOptions.timeoutMs = 0;

  let client;
  try {
    client = createClient({
      contract: contractWith([action({ transport: "auto" })]),
      transports,
      prefer: input.preferred,
    });
  } catch (error) {
    return { actual: { error: { kind: errorKind(error) } }, want: { error: { kind: expected.error?.kind } } };
  }

  const invoked = () => calls.http + calls.phoenix_channel;

  try {
    await client.actions[ACTION_ID].invokeWithReceipt({}, callOptions);
    return {
      actual: { dispatchState: "dispatched", fallbackAllowed: false, failureOutcome: "NONE (call succeeded)" },
      want: expectedOutcomeView(expected),
    };
  } catch (error) {
    const err = errorOf(error);
    if (expected.error) {
      return { actual: { error: { kind: errorKind(err, expected.error.kind) } }, want: { error: { kind: expected.error.kind } } };
    }
    const receipt = err.receipt;
    if (phase === "post_dispatch") {
      const replayed = invoked() > 1;
      return {
        actual: {
          dispatchState: receipt?.dispatchState === "unknown_after_dispatch" ? "dispatched" : "not_dispatched",
          fallbackAllowed: replayed,
          failureOutcome: err.code === "TRANSPORT_OUTCOME_UNKNOWN" ? receipt?.outcome : err.code,
        },
        want: expectedOutcomeView(expected),
      };
    }
    // pre-dispatch: nothing may have been sent and no dispatch receipt exists
    const sent = invoked() > 0 || (receipt && receipt.dispatchState !== "not_dispatched");
    const decision = client.inspect(ACTION_ID).decision;
    return {
      actual: {
        dispatchState: sent ? "dispatched" : "not_dispatched",
        fallbackAllowed: !sent && decision.fallback === "pre_dispatch_only" && decision.dispatchState === "not_dispatched",
        failureOutcome: null,
      },
      want: expectedOutcomeView(expected),
    };
  } finally {
    if (input.cause === "abort_after_dispatch") controller.abort();
  }
}

function expectedOutcomeView(expected) {
  return {
    dispatchState: expected.dispatchState,
    fallbackAllowed: expected.fallbackAllowed,
    failureOutcome: expected.failureOutcome,
  };
}

// The adapter-unavailable pre-dispatch fallback vector is a selection fact, not a
// failed call: evaluate it through inspect().
async function outcomeFallback(input, expected) {
  const plan = selectionClient({ ...input, profile: {} });
  if (plan.na) return plan;
  const decision = plan.build().inspect(ACTION_ID).decision;
  return {
    actual: {
      dispatchState: decision.dispatchState,
      fallbackAllowed: decision.fallback === "pre_dispatch_only" && decision.dispatchState === "not_dispatched",
      failureOutcome: null,
    },
    want: expectedOutcomeView(expected),
  };
}

HANDLERS.transport_outcome = async (input, expected) => {
  if (input.cause === "adapter_unavailable") return outcomeFallback(input, expected);
  return outcome(input, expected);
};

// ---- engine ---------------------------------------------------------------------------

function same(a, b) {
  try {
    assert.deepStrictEqual(a, b);
    return true;
  } catch {
    return false;
  }
}

export async function replayVector(kind, vector, divergences = KNOWN_DIVERGENCES) {
  const handler = HANDLERS[kind];
  if (!handler) return { id: vector.id, kind, status: "FAIL", reason: `no JS handler or NOT_APPLICABLE declaration for kind ${kind}` };

  let outcomeOf;
  try {
    outcomeOf = await handler(vector.input, vector.expected);
  } catch (error) {
    outcomeOf = { crashed: `${error?.name}: ${error?.message}` };
  }

  const pinned = Object.hasOwn(divergences, vector.id) ? divergences[vector.id] : null;

  if (outcomeOf.na) {
    if (pinned) return { id: vector.id, kind, status: "FAIL", reason: "stale known-divergence entry: vector is NOT_APPLICABLE" };
    return { id: vector.id, kind, status: "NOT_APPLICABLE", reason: outcomeOf.na };
  }

  const actual = outcomeOf.crashed !== undefined ? { crashed: outcomeOf.crashed } : outcomeOf.actual;
  const want = outcomeOf.want ?? vector.expected;
  const agrees = outcomeOf.crashed === undefined && same(actual, want);

  if (pinned) {
    if (agrees) return { id: vector.id, kind, status: "FAIL", reason: "known divergence no longer diverges: remove its entry", actual };
    if (!same(actual, pinned.jsActual)) {
      return { id: vector.id, kind, status: "FAIL", reason: "divergence changed shape", actual, pinned: pinned.jsActual };
    }
    return { id: vector.id, kind, status: "KNOWN_DIVERGENCE", reason: pinned.reason, actual, want };
  }

  if (agrees) return { id: vector.id, kind, status: "PASS", reason: null };
  return { id: vector.id, kind, status: "FAIL", reason: "JavaScript disagrees with the corpus", actual, want };
}

export async function replayCorpus({ dir = DEFAULT_CORPUS_DIR, divergences = KNOWN_DIVERGENCES } = {}) {
  const { files } = loadCorpus(dir);
  const results = [];
  for (const file of files) {
    for (const vector of file.vectors) {
      results.push({ file: file.entry.path, level: vector.level, ...(await replayVector(file.kind, vector, divergences)) });
    }
  }
  return results;
}

export function summarize(results) {
  const by = {};
  for (const result of results) {
    by[result.kind] ??= { PASS: 0, FAIL: 0, NOT_APPLICABLE: 0, KNOWN_DIVERGENCE: 0 };
    by[result.kind][result.status] += 1;
  }
  return by;
}
