import { z } from "zod";

/**
 * JavaScript projection of an AshSurface contract.
 *
 * This file is ordinary executable JavaScript. JSDoc is the static/editor typing
 * surface and Zod is the executable boundary schema. TypeScript is not required,
 * emitted, or consumed.
 */

export const SURFACE_RUNTIME_VERSION = "0.2.0";
const SUPPORTED_SURFACE_MAJOR = 0;
const KNOWN_TRANSPORTS = Object.freeze(["http", "phoenix_channel"]);

const jsonRecordSchema = z.record(z.string(), z.unknown());

export const surfaceActionSchema = z
  .object({
    id: z.string().min(1),
    resource: z.string().min(1),
    action: z.string().min(1),
    profile: jsonRecordSchema.default({}),
  })
  .passthrough();

export const ashSurfaceContractSchema = z
  .object({
    surfaceSchemaVersion: z.string().min(1),
    ashManifestSchemaVersion: z.string().min(1),
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
 * @property {string} resource Fully-qualified Ash resource module name.
 * @property {string} action Ash action name.
 * @property {Record<string, unknown>} profile Projection-only metadata.
 */

/**
 * @typedef {Object} TransportAdapter
 * @property {(context: {action: SurfaceAction, input: unknown, contract: AshSurfaceContract, signal?: AbortSignal}) => Promise<unknown>} invoke
 * @property {((action: SurfaceAction, contract: AshSurfaceContract) => boolean) | boolean} [available]
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
 * contract. No AshTypescript manifest or generated TypeScript artifact is used.
 *
 * @param {Object} options
 * @param {unknown} options.contract Untrusted AshSurface JSON contract.
 * @param {Partial<Record<"http"|"phoenix_channel", TransportAdapter>>} options.transports
 * @param {"http"|"phoenix_channel"} [options.prefer="http"]
 * @param {Record<string, ActionSchemas>} [options.schemas] Zod schemas keyed by stable action id.
 * @returns {{runtimeVersion: string, contract: AshSurfaceContract, actions: Record<string, Object>, resources: Record<string, Record<string, Object>>, get(id: string): Object|null, inspect(id: string): Object}}
 */
export function createClient({ contract, transports = {}, prefer = "http", schemas = {} }) {
  const admittedContract = parseContract(contract);
  assertPreferred(prefer);
  assertTransportAdapters(transports);

  const actions = Object.create(null);
  const resources = Object.create(null);

  for (const action of admittedContract.surface.actions) {
    if (actions[action.id]) {
      throw new SurfaceRuntimeError("DUPLICATE_ACTION_ID", `duplicate action identity: ${action.id}`);
    }

    const descriptor = Object.freeze({
      id: action.id,
      resource: action.resource,
      action: action.action,
      profile: Object.freeze({ ...action.profile }),
      inspect() {
        return inspectAction(action, admittedContract, transports, prefer);
      },
      async invoke(input, options = {}) {
        const { result } = await invokeWithReceipt(
          action,
          input,
          options,
          admittedContract,
          transports,
          prefer,
          schemas[action.id],
        );
        return result;
      },
      async invokeWithReceipt(input, options = {}) {
        return invokeWithReceipt(
          action,
          input,
          options,
          admittedContract,
          transports,
          prefer,
          schemas[action.id],
        );
      },
    });

    actions[action.id] = descriptor;
    resources[action.resource] ??= Object.create(null);

    if (resources[action.resource][action.action]) {
      throw new SurfaceRuntimeError(
        "DUPLICATE_RESOURCE_ACTION",
        `duplicate action ${action.action} on resource ${action.resource}`,
      );
    }

    resources[action.resource][action.action] = descriptor;
  }

  freezeRecordValues(resources);

  return Object.freeze({
    runtimeVersion: SURFACE_RUNTIME_VERSION,
    contract: admittedContract,
    actions: Object.freeze(actions),
    resources: Object.freeze(resources),
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
  if (major !== SUPPORTED_SURFACE_MAJOR) {
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

  try {
    const result = await adapter.invoke({
      action,
      input: admittedInput,
      contract,
      signal: options.signal,
    });

    let admittedOutput = result;
    if (actionSchemas?.output) {
      try {
        admittedOutput = actionSchemas.output.parse(result);
      } catch (cause) {
        throw new SurfaceRuntimeError(
          "OUTPUT_VALIDATION_FAILED",
          `output failed Zod validation for ${action.id}`,
          { cause, receipt: complete(decision) },
        );
      }
    }

    return { result: admittedOutput, receipt: complete(decision) };
  } catch (cause) {
    if (cause instanceof SurfaceRuntimeError && cause.code === "OUTPUT_VALIDATION_FAILED") {
      throw cause;
    }

    throw new SurfaceRuntimeError(
      "TRANSPORT_OUTCOME_UNKNOWN",
      `${decision.selected} transport failed after dispatch for ${action.id}; no automatic cross-transport retry was attempted`,
      { cause, receipt: unknownAfterDispatch(decision) },
    );
  }
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

function complete(decision) {
  return Object.freeze({ ...decision, dispatchState: "completed" });
}

function unknownAfterDispatch(decision) {
  return Object.freeze({ ...decision, dispatchState: "unknown_after_dispatch" });
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
