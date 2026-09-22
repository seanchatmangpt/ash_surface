import { z } from "zod";

/**
 * JavaScript projection of an AshSurface contract.
 *
 * This file is ordinary executable JavaScript. JSDoc is the static/editor typing
 * surface and Zod is the executable boundary schema. TypeScript is not required,
 * emitted, or consumed.
 */

export const SURFACE_RUNTIME_VERSION = "26.9.21";
const SUPPORTED_SURFACE_MAJORS = [0, 26];
const KNOWN_TRANSPORTS = Object.freeze(["http", "phoenix_channel"]);

const jsonRecordSchema = z.record(z.string(), z.unknown());

export const surfaceActionSchema = z
  .object({
    id: z.string().min(1),
    semanticId: z.string().min(1).default("ash:Action"),
    resource: z.string().min(1),
    action: z.string().min(1),
    authorityBoundary: z.enum(["OBSERVE", "SELECT", "CONSTRUCT", "DO"]).default("DO"),
    doAuthority: z.boolean().default(true),
    receiptRequired: z.boolean().default(true),
    evidenceRequired: z.boolean().default(false),
    possibleRefusals: z.array(z.string()).default([]),
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
    standing: z.string().default("ALIVE"),
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

const evidenceStandingSchema = z.enum(["UNKNOWN", "PARTIAL_ALIVE", "ALIVE", "BLOCKED", "REFUSED"]);

export const possibilitySchema = z
  .object({
    possibilityId: z.string().min(1),
    exactSubject: z.string().min(1),
    capabilityId: z.string().min(1),
    label: z.string().min(1),
    summary: z.string().nullable().optional(),
    actionRef: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    status: z.enum(["CANDIDATE", "PRESERVED", "BLOCKED", "REFUSED"]),
    reversibility: z.enum(["REVERSIBLE", "CONDITIONAL", "IRREVERSIBLE"]),
    stateDigest: z.string().min(1),
    costSummary: z.string().nullable().optional(),
    consequenceSummary: z.string().nullable().optional(),
    requirements: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    expiresAt: z.string().nullable().optional(),
    authorityCeiling: z.enum(["OBSERVE", "SELECT", "CONSTRUCT"]).default("SELECT"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const possibilitySetSchema = z
  .object({
    setId: z.string().min(1),
    exactSubject: z.string().min(1),
    objective: z.string().min(1),
    horizon: z.string().nullable().optional(),
    selectionRef: z.string().nullable().optional(),
    closureReason: z.string().nullable().optional(),
    possibilities: z.array(possibilitySchema),
    constraints: z.array(z.string()).default([]),
    sourceEpisodeRefs: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    standing: evidenceStandingSchema.default("PARTIAL_ALIVE"),
    mode: z.literal("MAXIMAL_REVERSIBLE_FRONTIER"),
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.standing === "ALIVE" && value.possibilities.length === 0) {
      ctx.addIssue({ code: "custom", message: "ALIVE possibility set requires at least one option" });
    }
    if (new Set(value.possibilities.map((item) => item.possibilityId)).size !== value.possibilities.length) {
      ctx.addIssue({ code: "custom", message: "possibility ids must be unique" });
    }
  });

export const whyThisSchema = z
  .object({
    explanationId: z.string().min(1),
    subjectRef: z.string().min(1),
    title: z.string().min(1),
    summary: z.string().min(1),
    claimKind: z.enum(["HYPOTHESIS", "OBSERVATION", "USER_STATED", "DOCTRINAL"]),
    evidenceState: evidenceStandingSchema,
    falsifier: z.string().nullable().optional(),
    basis: z.array(z.string()).default([]),
    caveats: z.array(z.string()).default([]),
    profileRefs: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    hypothesisRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.claimKind === "HYPOTHESIS" && !value.falsifier) {
      ctx.addIssue({ code: "custom", message: "HYPOTHESIS explanation requires falsifier" });
    }
  });

export const outcomeHypothesisSchema = z
  .object({
    hypothesisId: z.string().min(1),
    subjectRef: z.string().min(1),
    practiceRef: z.string().min(1),
    outcomeRef: z.string().min(1),
    relationship: z.enum(["MAY_SUPPORT", "MAY_HINDER", "ASSOCIATED", "UNKNOWN"]),
    evidenceState: evidenceStandingSchema,
    falsifier: z.string().min(1),
    horizon: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
    observationRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    causalClaim: z.literal(false),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const devotionalSegmentSchema = z
  .object({
    position: z.number().int().nonnegative(),
    kind: z.enum(["SCRIPTURE", "COMMENTARY", "PRAYER", "REFLECTION", "MUSIC", "TRANSITION"]),
    ref: z.string().min(1),
    label: z.string().min(1),
    durationSeconds: z.number().int().nonnegative(),
    audioRef: z.string().nullable().optional(),
  })
  .passthrough();

export const devotionalEpisodeSchema = z
  .object({
    episodeId: z.string().min(1),
    title: z.string().min(1),
    subtitle: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    status: z.enum(["READY", "IN_PROGRESS", "COMPLETED", "BLOCKED"]),
    durationSeconds: z.number().int().nonnegative(),
    completionReceiptRef: z.string().nullable().optional(),
    stateDigest: z.string().min(1),
    segments: z.array(devotionalSegmentSchema),
    hypothesisRefs: z.array(z.string()).default([]),
    sourceRefs: z.array(z.string()).default([]),
    playbackPolicy: z.literal("STRAIGHT_THROUGH"),
    continuousPlay: z.literal(true),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .superRefine((value, ctx) => {
    if (value.status === "COMPLETED" && !value.completionReceiptRef) {
      ctx.addIssue({ code: "custom", message: "COMPLETED devotional requires completion receipt" });
    }
  });

export const commitmentBoundarySchema = z
  .object({
    boundaryId: z.string().min(1),
    subjectRef: z.string().min(1),
    actionRef: z.string().min(1),
    consequenceSummary: z.string().min(1),
    reversibility: z.enum(["REVERSIBLE", "CONDITIONAL", "IRREVERSIBLE"]),
    confirmationState: z.enum(["UNCONFIRMED", "CONFIRMED", "DECLINED", "EXPIRED"]),
    constructRef: z.string().nullable().optional(),
    whyThisRef: z.string().nullable().optional(),
    expiresAt: z.string().nullable().optional(),
    externalEffects: z.array(z.string()).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    stateDigest: z.string().min(1),
    confirmationRequired: z.literal(true),
    nextHandoff: z.literal("BRCE"),
    authorityCeiling: z.literal("CONSTRUCT"),
    doAuthority: z.literal(false),
  })
  .passthrough();

export const journeyEntrySchema = z
  .object({
    entryId: z.string().min(1),
    kind: z.enum(["PRACTICE", "SERVICE", "ATTENDANCE", "COMMITMENT", "REFLECTION", "OUTCOME", "RECEIPT"]),
    subjectRef: z.string().min(1),
    label: z.string().min(1),
    occurredAt: z.string().min(1),
    receiptRef: z.string().nullable().optional(),
    evidenceRefs: z.array(z.string()).default([]),
    standing: evidenceStandingSchema,
  })
  .passthrough();

export const journeySchema = z
  .object({
    journeyId: z.string().min(1),
    exactSubject: z.string().min(1),
    entries: z.array(journeyEntrySchema),
    evidenceRefs: z.array(z.string()).default([]),
    receiptRefs: z.array(z.string()).default([]),
    privacyScope: z.literal("SUBJECT_PRIVATE"),
    standing: evidenceStandingSchema,
    stateDigest: z.string().min(1),
    authorityBoundary: z.literal("OBSERVE").default("OBSERVE"),
    doAuthority: z.literal(false).default(false),
  })
  .passthrough();

export const humanSurfaceSchema = z
  .object({
    surfaceId: z.string().min(1),
    exactSubject: z.string().min(1),
    stateDigest: z.string().min(1),
    standing: evidenceStandingSchema,
    grammar: z.tuple([
      z.literal("SEE"),
      z.literal("UNDERSTAND"),
      z.literal("EXPLORE"),
      z.literal("CHOOSE"),
      z.literal("ACT"),
      z.literal("LEARN"),
    ]),
    areas: z.tuple([
      z.literal("TODAY"),
      z.literal("BIBLE"),
      z.literal("LIFE"),
      z.literal("ZOE"),
      z.literal("YOU"),
    ]),
    today: jsonRecordSchema,
    bible: jsonRecordSchema,
    life: jsonRecordSchema,
    zoe: jsonRecordSchema,
    you: jsonRecordSchema,
    possibilitySets: z.array(possibilitySetSchema).default([]),
    explanations: z.array(whyThisSchema).default([]),
    devotionalEpisodes: z.array(devotionalEpisodeSchema).default([]),
    outcomeHypotheses: z.array(outcomeHypothesisSchema).default([]),
    commitmentBoundaries: z.array(commitmentBoundarySchema).default([]),
    journeys: z.array(journeySchema).default([]),
    evidenceRefs: z.array(z.string()).default([]),
    receiptRefs: z.array(z.string()).default([]),
    authorityBoundary: z.literal("OBSERVE"),
    doAuthority: z.literal(false),
  })
  .passthrough();

export function parseHumanSurfaceProjection(value) {
  const parsed = humanSurfaceSchema.safeParse(value);
  if (!parsed.success) {
    throw new SurfaceRuntimeError(
      "INVALID_HUMAN_SURFACE",
      "AshSurface human projection failed Zod validation",
      { issues: parsed.error.issues },
    );
  }
  return parsed.data;
}

export const ashSurfaceContractSchema = z
  .object({
    surfaceSchemaVersion: z.string().min(1),
    ashManifestSchemaVersion: z.string().min(1),
    generatorIdentity: z.string().optional(),
    manifestDigest: z.string().optional(),
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
 * @property {string} semanticId Formal semantic URI.
 * @property {string} resource Fully-qualified Ash resource module name.
 * @property {string} action Ash action name.
 * @property {"OBSERVE"|"SELECT"|"CONSTRUCT"|"DO"} authorityBoundary
 * @property {boolean} doAuthority
 * @property {boolean} receiptRequired
 * @property {boolean} evidenceRequired
 * @property {string[]} possibleRefusals
 * @property {Record<string, unknown>} profile Projection-only metadata.
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
 * @property {"preferred_available"|"preferred_unavailable"} reason
 * @property {"pre_dispatch_only"} fallback
 * @property {"not_dispatched"|"completed"|"unknown_after_dispatch"} dispatchState
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
  const decision = selectTransport(action.id, declared, available, prefer);

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
  const decision = selectTransport(action.id, declared, available, prefer);
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

function selectTransport(actionId, declared, available, preferred) {
  const selected = available.includes(preferred)
    ? preferred
    : declared.find((candidate) => available.includes(candidate));

  if (!selected) {
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
        },
      },
    );
  }

  return {
    actionId,
    declared: [...declared],
    available: [...available],
    selected,
    preferred,
    reason: selected === preferred ? "preferred_available" : "preferred_unavailable",
    fallback: "pre_dispatch_only",
    dispatchState: "not_dispatched",
  };
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
