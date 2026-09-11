/**
 * AshSurface runtime adapter for AshTypescript's public JSON manifest.
 *
 * The manifest remains authoritative for which generated RPC functions exist.
 * This module adds only action lookup and pre-dispatch transport selection.
 * It does not cache server state, revalidate trusted responses, or retry a
 * request on another transport after dispatch.
 */

export const SURFACE_RUNTIME_VERSION = "0.1.0";
const SUPPORTED_MANIFEST_MAJOR = 1;

export class SurfaceRuntimeError extends Error {
  constructor(code, message, options = {}) {
    super(message, options.cause ? { cause: options.cause } : undefined);
    this.name = "SurfaceRuntimeError";
    this.code = code;
    this.receipt = options.receipt ?? null;
  }
}

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

/**
 * Builds a framework-neutral action surface from AshTypescript's public JSON
 * manifest and generated RPC module.
 *
 * @param {Object} options
 * @param {Object} options.manifest AshTypescript JSON manifest (schema major 1)
 * @param {Object} options.rpc imported generated AshTypescript RPC module
 * @param {Object|null} [options.channel] joined Phoenix Channel for channel variants
 * @param {"http"|"phoenix_channel"} [options.prefer="http"] preferred transport
 * @returns {Object}
 */
export function createSurface({ manifest, rpc, channel = null, prefer = "http" }) {
  assertManifest(manifest);
  assertPreferred(prefer);

  if (!rpc || typeof rpc !== "object") {
    throw new SurfaceRuntimeError("INVALID_RPC_MODULE", "rpc must be an imported generated RPC module");
  }

  const actions = Object.create(null);
  const namespaces = Object.create(null);

  for (const action of manifest.actions) {
    const id = actionId(action);

    if (actions[id]) {
      throw new SurfaceRuntimeError("DUPLICATE_ACTION_ID", `duplicate action identity: ${id}`);
    }

    const descriptor = Object.freeze({
      id,
      namespace: action.namespace ?? null,
      resource: action.resource,
      actionType: action.actionType,
      manifest: action,
      inspect() {
        return inspectAction(action, rpc, channel, prefer);
      },
      async invoke(config = {}) {
        const { result } = await invokeWithReceipt(action, config, { rpc, channel, prefer });
        return result;
      },
      async invokeWithReceipt(config = {}) {
        return invokeWithReceipt(action, config, { rpc, channel, prefer });
      },
    });

    actions[id] = descriptor;

    const namespace = action.namespace ?? "default";
    namespaces[namespace] ??= Object.create(null);

    if (namespaces[namespace][action.functionName]) {
      throw new SurfaceRuntimeError(
        "DUPLICATE_NAMESPACE_FUNCTION",
        `duplicate function ${action.functionName} in namespace ${namespace}`,
      );
    }

    namespaces[namespace][action.functionName] = descriptor;
  }

  freezeRecordValues(namespaces);

  return Object.freeze({
    runtimeVersion: SURFACE_RUNTIME_VERSION,
    manifestVersion: manifest.version,
    actions: Object.freeze(actions),
    namespaces: Object.freeze(namespaces),
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

function inspectAction(action, rpc, channel, prefer) {
  const declared = declaredTransports(action);
  const available = availableTransports(action, rpc, channel);
  const decision = selectTransport(actionId(action), declared, available, prefer);

  return Object.freeze({
    id: actionId(action),
    declared: Object.freeze([...declared]),
    available: Object.freeze([...available]),
    decision: Object.freeze({ ...decision }),
  });
}

async function invokeWithReceipt(action, config, runtime) {
  const id = actionId(action);
  const declared = declaredTransports(action);
  const available = availableTransports(action, runtime.rpc, runtime.channel);
  const decision = selectTransport(id, declared, available, runtime.prefer);

  if (decision.selected === "http") {
    const fn = runtime.rpc[action.functionName];
    return invokeHttp(fn, config, decision);
  }

  const channelName = action.variantNames?.channel;
  const fn = runtime.rpc[channelName];
  return invokeChannel(fn, runtime.channel, config, decision);
}

async function invokeHttp(fn, config, decision) {
  try {
    const result = await fn(config);
    return { result, receipt: complete(decision) };
  } catch (cause) {
    throw new SurfaceRuntimeError(
      "TRANSPORT_OUTCOME_UNKNOWN",
      `HTTP transport failed after dispatch for ${decision.actionId}; no automatic cross-transport retry was attempted`,
      { cause, receipt: unknownAfterDispatch(decision) },
    );
  }
}

function invokeChannel(fn, channel, config, decision) {
  return new Promise((resolve, reject) => {
    let settled = false;

    const resolveOnce = (result) => {
      if (settled) return;
      settled = true;
      resolve({ result, receipt: complete(decision) });
    };

    const rejectOnce = (code, message, cause) => {
      if (settled) return;
      settled = true;
      reject(
        new SurfaceRuntimeError(code, message, {
          cause,
          receipt: unknownAfterDispatch(decision),
        }),
      );
    };

    try {
      fn({
        ...config,
        channel,
        resultHandler: resolveOnce,
        errorHandler: (error) =>
          rejectOnce(
            "TRANSPORT_OUTCOME_UNKNOWN",
            `Phoenix Channel transport errored after dispatch for ${decision.actionId}; no HTTP fallback was attempted`,
            error,
          ),
        timeoutHandler: () =>
          rejectOnce(
            "TRANSPORT_OUTCOME_UNKNOWN",
            `Phoenix Channel transport timed out after dispatch for ${decision.actionId}; no HTTP fallback was attempted`,
          ),
      });
    } catch (cause) {
      rejectOnce(
        "TRANSPORT_OUTCOME_UNKNOWN",
        `Phoenix Channel invocation failed after dispatch for ${decision.actionId}`,
        cause,
      );
    }
  });
}

function declaredTransports(action) {
  const declared = ["http"];
  if (action.variants?.channel === true && action.variantNames?.channel) {
    declared.push("phoenix_channel");
  }
  return declared;
}

function availableTransports(action, rpc, channel) {
  const available = [];
  if (typeof rpc[action.functionName] === "function") available.push("http");

  if (
    action.variants?.channel === true &&
    action.variantNames?.channel &&
    channel &&
    typeof rpc[action.variantNames.channel] === "function"
  ) {
    available.push("phoenix_channel");
  }

  return available;
}

function selectTransport(actionIdValue, declared, available, preferred) {
  const selected = available.includes(preferred)
    ? preferred
    : declared.find((candidate) => available.includes(candidate));

  if (!selected) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_TRANSPORT",
      `no admitted transport implementation is available for ${actionIdValue}`,
      {
        receipt: {
          actionId: actionIdValue,
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
    actionId: actionIdValue,
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

function actionId(action) {
  const namespace = action.namespace ?? "default";
  return `${namespace}:${action.resource}:${action.functionName}`;
}

function assertManifest(manifest) {
  if (!manifest || typeof manifest !== "object" || !Array.isArray(manifest.actions)) {
    throw new SurfaceRuntimeError("INVALID_MANIFEST", "manifest.actions must be an array");
  }

  const [major] = String(manifest.version ?? "").split(".").map(Number);
  if (major !== SUPPORTED_MANIFEST_MAJOR) {
    throw new SurfaceRuntimeError(
      "UNSUPPORTED_MANIFEST_VERSION",
      `AshTypescript manifest major ${manifest.version ?? "<missing>"} is unsupported`,
    );
  }
}

function assertPreferred(prefer) {
  if (prefer !== "http" && prefer !== "phoenix_channel") {
    throw new SurfaceRuntimeError("UNKNOWN_TRANSPORT", `unknown preferred transport: ${prefer}`);
  }
}

function freezeRecordValues(record) {
  for (const value of Object.values(record)) Object.freeze(value);
}
