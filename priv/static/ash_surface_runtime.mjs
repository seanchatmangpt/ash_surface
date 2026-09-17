import { z } from "zod";

/**
 * JavaScript projection of an AshSurface contract.
 *
 * This file is ordinary executable JavaScript. JSDoc is the static/editor typing
 * surface and Zod is the executable boundary schema. TypeScript is not required,
 * emitted, or consumed.
 */

export const SURFACE_RUNTIME_VERSION = "26.9.17";
const SUPPORTED_SURFACE_MAJORS = [0, 26];
const KNOWN_TRANSPORTS = Object.freeze(["http", "phoenix_channel"]);
// v26.9.17 F6 selection-frontier vocabulary: delegated per-transport dimension
// facts (cost/latency lower is better; privacy higher is better). Twin of
// lib/ash_surface/transport.ex (@dimensions / @dimension_classes).
const KNOWN_DIMENSIONS = Object.freeze(["cost", "latency", "privacy"]);
const KNOWN_DIMENSION_CLASSES = Object.freeze(["low", "medium", "high"]);
const DIMENSION_PRIORITY = Object.freeze(["cost", "latency", "privacy"]);

const jsonRecordSchema = z.record(z.string(), z.unknown());

// F3 (tightened by chicago-standing-table-029): one canonical standing
// vocabulary, owned lib-side by AshSurface.Standing
// (lib/ash_surface/standing.ex). The five base standings are the closed
// z.enum() core; the open REFUSED class ("REFUSED_"-prefixed refusal
// standings, e.g. "REFUSED_NO_AUTHORITY") is the regex branch. Bare "REFUSED"
// is NOT a standing — a refusal must name its reason — and "UNKNOWN" is
// deliberately not a standing: it is a post-dispatch outcome.
export const STANDING_VALUES = Object.freeze([
  "ALIVE",
  "PARTIAL_ALIVE",
  "BLOCKED",
  "BUILD_BROKEN",
  "UNSUPPORTED",
]);

const standingSchema = z.union([
  z.enum(STANDING_VALUES),
  // The open REFUSED class: at least one reason char beyond the prefix —
  // bare "REFUSED" and the empty reason "REFUSED_" are not refusals (mirrors
  // lib/ash_surface/standing.ex "REFUSED_" <> _ rest law).
  z.string().regex(/^REFUSED_.+/),
]);

// F3 refusal guard: every declared possible refusal is a "REFUSED_"-prefixed
// code with a named reason (mirrors the Elixir REFUSED_* refusal vocabulary,
// e.g. "REFUSED_UNKNOWN_ACTION"). Off-vocabulary names and the unnamed
// "REFUSED"/"REFUSED_" are refused at the boundary.
const refusalCodeSchema = z.string().regex(/^REFUSED_.+/);

export const surfaceActionSchema = z
  .object({
    id: z.string().min(1),
    // v26.9.17 delegation: semanticId, authorityBoundary, doAuthority, and
    // receiptRequired are delegated facts. They arrive from the manifest's
    // custom.ash_surface metadata or are null — an absent key means "not
    // delegated" and surfaces as null; values are never defaulted or
    // re-derived client-side.
    semanticId: z.string().min(1).nullable().default(null),
    resource: z.string().min(1),
    action: z.string().min(1),
    authorityBoundary: z
      .enum(["OBSERVE", "SELECT", "CONSTRUCT", "DO"])
      .nullable()
      .default(null),
    doAuthority: z.boolean().nullable().default(null),
    receiptRequired: z.boolean().nullable().default(null),
    evidenceRequired: z.boolean().default(false),
    possibleRefusals: z.array(refusalCodeSchema).default([]),
    profile: jsonRecordSchema.default({}),
  })
  .passthrough();

export const observationProjectionSchema = z
  .object({
    observationId: z.string().min(1),
    exactSubject: z.string().min(1),
    observedAt: z.string().min(1),
    stateDigest: z.string().min(1),
    facts: jsonRecordSchema,
    evidenceRefs: z.array(z.string()).default([]),
    standing: standingSchema.default("ALIVE"),
    projectionPurpose: z.string().default("consumer_state_observation"),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
  })
  .passthrough();

export const planningEpisodeSchema = z
  .object({
    episodeId: z.string().min(1),
    worldStateRef: z.string().min(1),
    taskNetworkRef: z.string().nullable().optional(),
    plannerIdentity: z.string().min(1),
    policyIdentity: z.string().min(1),
    policyStanding: z.enum(["VALID_STRONG", "VALID_STRONG_CYCLIC", "REFUSED"]).default("VALID_STRONG"),
    candidateActions: z.array(z.unknown()).default([]),
    authorityCeiling: z.enum(["SELECT", "CONSTRUCT"]).default("SELECT"),
  })
  .passthrough();

export const eventProjectionSchema = z
  .object({
    eventId: z.string().min(1),
    sequence: z.number().int().nonnegative(),
    subjectRef: z.string().min(1),
    eventType: z.string().min(1),
    stateDigest: z.string().min(1),
    evidenceRef: z.string().nullable().optional(),
    receiptRef: z.string().nullable().optional(),
    payload: jsonRecordSchema.nullable().optional(),
    occurredAt: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
  })
  .passthrough();

export const ashSurfaceContractSchema = z
  .object({
    surfaceSchemaVersion: z.string().min(1),
    ashManifestSchemaVersion: z.string().min(1),
    generatorIdentity: z.string().optional(),
    manifestDigest: z.string().optional(),
    // Delegated IR-era envelope extensions (gapfix-test-surface-015 ledger):
    // ontologyDigest / applicationReleaseIdentity have no live producer in
    // the Elixir surface pipeline (AshSurface.contract/2 never emits them);
    // their witnessed producer is upstream generation (the frozen F5 fixture
    // in digest_cross_language_v2.test.mjs). Kept as typed optional rows —
    // present values are validated, absent values stay absent (never
    // defaulted), and emitting them locally would fabricate delegated
    // provenance.
    ontologyDigest: z.string().optional(),
    marketplaceIdentity: z.string().optional(),
    applicationReleaseIdentity: z.string().optional(),
    manifest: jsonRecordSchema,
    surface: z
      .object({
        profile: jsonRecordSchema.default({}),
        actions: z.array(surfaceActionSchema),
      })
      .passthrough(),
  })
  .passthrough();

/**
 * @typedef {Object} SurfaceAction
 * @property {string} id Stable Ash action identity.
 * @property {string|null} semanticId Delegated semantic URI; null when not delegated (v26.9.17 delegation).
 * @property {string} resource Fully-qualified Ash resource module name.
 * @property {string} action Ash action name.
 * @property {"OBSERVE"|"SELECT"|"CONSTRUCT"|"DO"|null} authorityBoundary Delegated; null when not delegated.
 * @property {boolean|null} doAuthority Delegated; null when not delegated.
 * @property {boolean|null} receiptRequired Delegated; null when not delegated.
 * @property {boolean} evidenceRequired
 * @property {string[]} possibleRefusals "REFUSED_"-prefixed refusal codes (F3 guard).
 * @property {Record<string, unknown>} profile Projection-only metadata.
 */

/**
 * @typedef {("ALIVE"|"PARTIAL_ALIVE"|"BLOCKED"|"BUILD_BROKEN"|"UNSUPPORTED"|string)} Standing
 * A canonical standing: one of `STANDING_VALUES` or a "REFUSED_"-prefixed
 * refusal standing (bare "REFUSED" is not a standing — a refusal must name
 * its reason). Mirrors `AshSurface.Standing` (lib/ash_surface/standing.ex).
 */

/**
 * @typedef {Object} TransportAdapter
 * @property {(context: {action: SurfaceAction, input: unknown, contract: AshSurfaceContract, signal?: AbortSignal}) => Promise<unknown>} invoke
 * @property {((action: SurfaceAction, contract: AshSurfaceContract) => boolean) | boolean} [available]
 * @property {((commandId: string) => Promise<{status: "COMPLETED"|"NOT_OBSERVED"|"STILL_UNKNOWN", receipt?: unknown}>)} [reconcile]
 */

/**
 * @typedef {Object} ActionSchemas
 * @property {{parse(value: unknown): unknown}} [input] Zod-compatible input schema.
 * @property {{parse(value: unknown): unknown}} [output] Zod-compatible output schema.
 */

/**
 * @typedef {Object} AshSurfaceContract
 * @property {string} surfaceSchemaVersion
 * @property {string} ashManifestSchemaVersion
 * @property {string} [generatorIdentity]
 * @property {Record<string, unknown>} manifest Canonical serialized Ash semantics.
 * @property {{profile: Record<string, unknown>, actions: SurfaceAction[]}} surface
 */

/**
 * @typedef {Object} SurfaceDecision
 * @property {string} actionId
 * @property {string[]} declared
 * @property {string[]} available
 * @property {"http"|"phoenix_channel"} selected
 * @property {"http"|"phoenix_channel"} preferred
 * @property {"preferred_available"|"preferred_unavailable"|"dimension_weighed"} reason
 * @property {"pre_dispatch_only"} fallback
 * @property {"not_dispatched"|"completed"|"unknown_after_dispatch"} dispatchState
 * @property {"undelegated"|"declared"} dimensions Typed presence of delegated dimension facts.
 * @property {Array<"http"|"phoenix_channel">} frontier Non-dominated available transports, declared order.
 */

export class SurfaceRuntimeError extends Error {
  constructor(code, message, options = {}) {
    super(message, options.cause ? { cause: options.cause } : undefined);
    this.name = "SurfaceRuntimeError";
    this.code = code;
    this.receipt = options.receipt ?? null;
    this.issues = options.issues ?? null;
  }
}

/**
 * Creates the JavaScript application-facing client directly from an AshSurface
 * contract.
 *
 * @param {Object} options
 * @param {unknown} options.contract Untrusted AshSurface JSON contract.
 * @param {Partial<Record<"http"|"phoenix_channel", TransportAdapter>>} options.transports
 * @param {"http"|"phoenix_channel"} [options.prefer="http"]
 * @param {Record<string, ActionSchemas>} [options.schemas] Zod schemas keyed by stable action id.
 * @returns {{runtimeVersion: string, contract: AshSurfaceContract, actions: Record<string, Object>, resources: Record<string, Record<string, Object>>, events: Object, reconcile(commandId: string, transportName?: "http"|"phoenix_channel"): Promise<Object>, get(id: string): Object|null, inspect(id: string): Object}}
 */
export function createClient(options) {
  if (!options || typeof options !== "object") {
    throw new SurfaceRuntimeError("INVALID_OPTIONS", "createClient options must be an object");
  }

  const contract = parseContract(options.contract);
  const transports = options.transports ?? {};
  const prefer = options.prefer ?? "http";
  const schemas = options.schemas ?? {};

  assertPreferred(prefer);
  assertTransportAdapters(transports);

  const actions = {};
  const resources = {};
  const eventListeners = new Map();

  for (const action of contract.surface.actions) {
    if (actions[action.id]) {
      throw new SurfaceRuntimeError(
        "DUPLICATE_ACTION_ID",
        `duplicate action id: ${action.id}`,
      );
    }

    const actionSchemas = schemas[action.id];
    const actionClient = Object.freeze({
      id: action.id,
      semanticId: action.semanticId,
      authorityBoundary: action.authorityBoundary,
      doAuthority: action.doAuthority,
      possibleRefusals: Object.freeze([...(action.possibleRefusals || [])]),
      resource: action.resource,
      action: action.action,
      profile: Object.freeze({ ...action.profile }),
      invoke(input, callOptions = {}) {
        return invokeWithReceipt(
          action,
          input,
          callOptions,
          contract,
          transports,
          prefer,
          actionSchemas,
        ).then(({ result }) => result);
      },
      invokeWithReceipt(input, callOptions = {}) {
        return invokeWithReceipt(
          action,
          input,
          callOptions,
          contract,
          transports,
          prefer,
          actionSchemas,
        );
      },
      inspect() {
        return inspectAction(action, contract, transports, prefer);
      },
    });

    actions[action.id] = actionClient;

    if (!resources[action.resource]) resources[action.resource] = {};
    resources[action.resource][action.action] = actionClient;
  }

  freezeRecordValues(actions);
  freezeRecordValues(resources);

  const events = Object.freeze({
    subscribe(subjectRef, callback) {
      if (!eventListeners.has(subjectRef)) eventListeners.set(subjectRef, new Set());
      eventListeners.get(subjectRef).add(callback);
      return () => {
        eventListeners.get(subjectRef)?.delete(callback);
      };
    },
    emit(eventData) {
      const parsed = eventProjectionSchema.parse(eventData);
      const listeners = eventListeners.get(parsed.subjectRef);
      if (listeners) {
        for (const cb of listeners) cb(parsed);
      }
    },
  });

  return Object.freeze({
    runtimeVersion: SURFACE_RUNTIME_VERSION,
    contract,
    actions,
    resources,
    events,
    async reconcile(commandId, transportName = prefer) {
      const adapter = transports[transportName];
      if (!adapter || typeof adapter.reconcile !== "function") {
        return {
          commandId,
          status: "STILL_UNKNOWN",
          reason: "transport_reconciliation_unsupported",
        };
      }
      return await adapter.reconcile(commandId);
    },
    get(id) {
      return actions[id] ?? null;
    },
    inspect(id) {
      const action = actions[id];
      if (!action) throw new SurfaceRuntimeError("UNKNOWN_ACTION", `unknown action: ${id}`);
      return action.inspect();
    },
  });
}

function parseContract(contract) {
  const parsed = ashSurfaceContractSchema.safeParse(contract);

  if (!parsed.success) {
    throw new SurfaceRuntimeError("INVALID_SURFACE_CONTRACT", "AshSurface contract failed Zod validation", {
      issues: parsed.error.issues,
    });
  }

  const [major] = parsed.data.surfaceSchemaVersion.split(".").map(Number);
  if (!SUPPORTED_SURFACE_MAJORS.includes(major)) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_SURFACE_VERSION",
      `AshSurface contract major ${parsed.data.surfaceSchemaVersion} is unsupported`,
    );
  }

  return parsed.data;
}

function inspectAction(action, contract, transports, prefer) {
  const declared = declaredTransports(action);
  const available = availableTransports(action, contract, transports, declared);
  const decision = selectTransport(
    action.id,
    declared,
    available,
    prefer,
    factsFromProfile(action),
  );

  return Object.freeze({
    id: action.id,
    semanticId: action.semanticId,
    authorityBoundary: action.authorityBoundary,
    doAuthority: action.doAuthority,
    declared: Object.freeze([...declared]),
    available: Object.freeze([...available]),
    decision: Object.freeze({ ...decision }),
  });
}

async function invokeWithReceipt(
  action,
  input,
  options,
  contract,
  transports,
  prefer,
  actionSchemas,
) {
  let admittedInput = input;

  if (actionSchemas?.input) {
    try {
      admittedInput = actionSchemas.input.parse(input);
    } catch (cause) {
      throw new SurfaceRuntimeError(
        "INPUT_VALIDATION_FAILED",
        `input failed Zod validation for ${action.id}`,
        { cause },
      );
    }
  }

  const declared = declaredTransports(action);
  const available = availableTransports(action, contract, transports, declared);
  const decision = selectTransport(
    action.id,
    declared,
    available,
    prefer,
    factsFromProfile(action),
  );
  const adapter = transports[decision.selected];

  const commandId = options.commandId || `cmd_${Math.random().toString(36).substring(2, 11)}`;

  try {
    const response = await adapter.invoke({
      action,
      input: admittedInput,
      commandId,
      contract,
      signal: options.signal,
    });

    let admittedOutput = response;
    if (actionSchemas?.output) {
      try {
        admittedOutput = actionSchemas.output.parse(response);
      } catch (cause) {
        throw new SurfaceRuntimeError(
          "OUTPUT_VALIDATION_FAILED",
          `output failed Zod validation for ${action.id}`,
          { cause, receipt: buildMXReceipt(decision, action, commandId, "completed", response) },
        );
      }
    }

    const receipt = buildMXReceipt(decision, action, commandId, "completed", admittedOutput);
    return { result: admittedOutput, receipt };
  } catch (cause) {
    if (cause instanceof SurfaceRuntimeError && cause.code === "OUTPUT_VALIDATION_FAILED") {
      throw cause;
    }

    throw new SurfaceRuntimeError(
      "TRANSPORT_OUTCOME_UNKNOWN",
      `${decision.selected} transport failed after dispatch for ${action.id}; no automatic cross-transport retry was attempted`,
      { cause, receipt: buildMXReceipt(decision, action, commandId, "unknown_after_dispatch", null) },
    );
  }
}

function buildMXReceipt(decision, action, commandId, dispatchState, result) {
  const domainReceiptRef = result?.receiptRef || result?.receipt?.hash || result?.data?.id || null;
  const outcome = dispatchState === "completed" ? "SUCCESS" : "UNKNOWN_AFTER_DISPATCH";

  const transportReceipt = Object.freeze({
    actionId: decision.actionId,
    selected: decision.selected,
    preferred: decision.preferred,
    reason: decision.reason,
    fallback: decision.fallback,
    dispatchState,
    declared: [...decision.declared],
    available: [...decision.available],
    dimensions: decision.dimensions,
    frontier: [...(decision.frontier || [])],
  });

  return Object.freeze({
    ...decision,
    commandId,
    semanticId: action.semanticId,
    authorityBoundary: action.authorityBoundary,
    doAuthority: action.doAuthority,
    dispatchState,
    outcome,
    domainReceiptRef,
    transportReceipt,
    consequenceReceipt: result?.consequenceReceipt || (result?.data ? { id: result.data.id, data: result.data } : null),
    timestamp: new Date().toISOString(),
  });
}

function declaredTransports(action) {
  const requested = action.profile?.transport ?? "auto";

  if (requested === "auto") return [...KNOWN_TRANSPORTS];
  if (KNOWN_TRANSPORTS.includes(requested)) return [requested];

  throw new SurfaceRuntimeError(
    "UNKNOWN_TRANSPORT",
    `unknown transport projection ${String(requested)} for ${action.id}`,
  );
}

function availableTransports(action, contract, transports, declared) {
  return declared.filter((name) => {
    const adapter = transports[name];
    if (!adapter || typeof adapter.invoke !== "function") return false;

    if (typeof adapter.available === "function") {
      return adapter.available(action, contract) === true;
    }

    return adapter.available !== false;
  });
}

/**
 * Reads the delegated transport dimension facts out of an action's profile
 * (the contract's `surface.actions[].profile` shape). An absent or null
 * "transportFacts" key normalizes to an empty facts map — not delegated,
 * never defaulted. Unknown transports, dimensions, or classes are typed
 * pre-dispatch refusals, never silent drops.
 */
function factsFromProfile(action) {
  const raw = action.profile?.transportFacts;

  if (raw === undefined || raw === null) return {};
  assertPlainObject(raw, "transportFacts");

  const facts = {};

  for (const [transport, dimensions] of Object.entries(raw)) {
    if (!KNOWN_TRANSPORTS.includes(transport)) {
      throw new SurfaceRuntimeError(
        "UNKNOWN_TRANSPORT",
        `unknown transport fact key: ${transport}`,
      );
    }

    assertPlainObject(dimensions, `transportFacts.${transport}`);

    const admitted = {};

    for (const [dimension, value] of Object.entries(dimensions)) {
      if (value === undefined || value === null) continue; // nil = not delegated
      if (!KNOWN_DIMENSIONS.includes(dimension)) {
        throw new SurfaceRuntimeError(
          "UNKNOWN_DIMENSION",
          `unknown dimension fact ${dimension} for ${transport}`,
        );
      }
      if (!KNOWN_DIMENSION_CLASSES.includes(value)) {
        throw new SurfaceRuntimeError(
          "UNKNOWN_DIMENSION_CLASS",
          `unknown ${dimension} class ${String(value)} for ${transport}`,
        );
      }
      admitted[dimension] = value;
    }

    facts[transport] = admitted;
  }

  return facts;
}

function assertPlainObject(value, label) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new SurfaceRuntimeError(
      "TRANSPORT_FACTS_MUST_BE_A_MAP",
      `${label} must be a plain object`,
    );
  }
}

function dimensionFact(facts, transport, dimension) {
  return facts[transport]?.[dimension] ?? null;
}

// Lower is better for cost and latency; higher is better for privacy.
const DIMENSION_RANK = Object.freeze({ low: 0, medium: 1, high: 2 });

function dimensionBetter(dimension, a, b) {
  return dimension === "privacy"
    ? DIMENSION_RANK[a] > DIMENSION_RANK[b]
    : DIMENSION_RANK[a] < DIMENSION_RANK[b];
}

// :better | :worse | :equal | :incomparable — an axis is comparable only
// where both transports declare a class.
function compareDimension(dimension, a, b, facts) {
  const classA = dimensionFact(facts, a, dimension);
  const classB = dimensionFact(facts, b, dimension);

  if (classA === null || classB === null) return "incomparable";
  if (classA === classB) return "equal";
  return dimensionBetter(dimension, classA, classB) ? "better" : "worse";
}

// a dominates b iff a is at least as good on every comparable axis and
// strictly better on at least one.
function dominates(a, b, facts) {
  let better = false;

  for (const dimension of DIMENSION_PRIORITY) {
    const verdict = compareDimension(dimension, a, b, facts);
    if (verdict === "worse") return false;
    if (verdict === "better") better = true;
  }

  return better;
}

// The admitted-alternatives frontier: every available transport (in declared
// order) that no other available transport dominates.
function transportFrontier(declared, available, facts) {
  const ordered = declared.filter((transport) => available.includes(transport));

  return ordered.filter(
    (transport) =>
      !ordered.some((other) => other !== transport && dominates(other, transport, facts)),
  );
}

// Deterministic frontier winner: compared pairwise in declared order, the
// first comparable axis with differing classes decides; a full tie falls to
// declared order.
function frontierBest(frontier, declared, facts) {
  return frontier.reduce((champion, candidate) => {
    for (const dimension of DIMENSION_PRIORITY) {
      const verdict = compareDimension(dimension, candidate, champion, facts);
      if (verdict === "better") return candidate;
      if (verdict === "worse") return champion;
    }

    return declared.indexOf(candidate) <= declared.indexOf(champion) ? candidate : champion;
  });
}

function selectTransport(actionId, declared, available, preferred, facts = {}) {
  const declaredDimensions = Object.values(facts).some(
    (dimensions) => Object.keys(dimensions).length > 0,
  );
  const dimensions = declaredDimensions ? "declared" : "undelegated";

  if (available.length === 0) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_TRANSPORT",
      `no admitted transport implementation is available for ${actionId}`,
      {
        receipt: {
          actionId,
          declared: [...declared],
          available: [...available],
          preferred,
          selected: null,
          reason: "no_available_transport",
          fallback: "pre_dispatch_only",
          dispatchState: "not_dispatched",
          dimensions,
          frontier: [],
        },
      },
    );
  }

  const frontier = transportFrontier(declared, available, facts);
  const decision = (selected, reason) => ({
    actionId,
    declared: [...declared],
    available: [...available],
    selected,
    preferred,
    reason,
    fallback: "pre_dispatch_only",
    dispatchState: "not_dispatched",
    dimensions,
    frontier: [...frontier],
  });

  if (declaredDimensions) {
    if (available.includes(preferred) && frontier.includes(preferred)) {
      return decision(preferred, "preferred_available");
    }

    return decision(frontierBest(frontier, declared, facts), "dimension_weighed");
  }

  const selected = available.includes(preferred)
    ? preferred
    : declared.find((candidate) => available.includes(candidate));

  return decision(
    selected,
    selected === preferred ? "preferred_available" : "preferred_unavailable",
  );
}

function assertPreferred(prefer) {
  if (!KNOWN_TRANSPORTS.includes(prefer)) {
    throw new SurfaceRuntimeError("UNKNOWN_TRANSPORT", `unknown preferred transport: ${prefer}`);
  }
}

function assertTransportAdapters(transports) {
  if (!transports || typeof transports !== "object") {
    throw new SurfaceRuntimeError("INVALID_TRANSPORTS", "transports must be an object");
  }

  const unknown = Object.keys(transports).filter((name) => !KNOWN_TRANSPORTS.includes(name));
  if (unknown.length > 0) {
    throw new SurfaceRuntimeError("UNKNOWN_TRANSPORT", `unknown transport adapter(s): ${unknown.join(", ")}`);
  }
}

function freezeRecordValues(record) {
  for (const value of Object.values(record)) Object.freeze(value);
}
