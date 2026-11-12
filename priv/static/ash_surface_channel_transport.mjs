// AshSurface Phoenix-channel transport adapter (TransportAdapter: invoke/available/reconcile)
// plus channel -> client.events bridge.
//
// Transport law: after push, an error reply, a timeout, or a throwing hook
// THROWS; the runtime classifies it UNKNOWN_AFTER_DISPATCH. No retry here, no
// cross-transport fallback, no network_error envelope.

import { eventProjectionSchema } from "./ash_surface_runtime.mjs";

export class ChannelTransportError extends Error {
  constructor(code, message, options = {}) {
    super(message, options.cause ? { cause: options.cause } : undefined);
    this.name = "ChannelTransportError";
    this.code = code;
    this.response = options.response ?? null;
  }
}

function pushOnce(channel, event, payload, timeout) {
  return new Promise((resolve, reject) => {
    let push;
    try {
      push = channel.push(event, payload, timeout);
    } catch (cause) {
      reject(new ChannelTransportError("CHANNEL_PUSH_FAILED", `channel push failed: ${cause?.message ?? cause}`, { cause }));
      return;
    }
    push
      .receive("ok", (response) => resolve(response))
      .receive("error", (response) =>
        reject(new ChannelTransportError("CHANNEL_ERROR_REPLY", `channel replied error to ${event}`, { response })),
      )
      .receive("timeout", () =>
        reject(new ChannelTransportError("CHANNEL_TIMEOUT", `channel push ${event} timed out after ${timeout}ms`)),
      );
  });
}

/**
 * @param {Object} options
 * @param {{push: Function}} options.channel Phoenix Channel (or a real implementation of push/receive).
 * @param {string} [options.event="run"]
 * @param {number} [options.timeout=10000] Push timeout in ms.
 * @param {(payload: object, context: object) => object|void|Promise<object|void>} [options.beforePush] May return a replacement payload.
 * @param {(response: unknown, context: object) => unknown} [options.afterResponse] May return a replacement response.
 */
export function createChannelTransport(options = {}) {
  const { channel, event = "run", timeout = 10000, beforePush, afterResponse } = options;
  if (!channel || typeof channel.push !== "function") {
    throw new ChannelTransportError("INVALID_CHANNEL", "channel with push/3 is required");
  }

  async function dispatch(name, payload, context) {
    if (typeof beforePush === "function") {
      const replaced = await beforePush(payload, context);
      if (replaced !== undefined) payload = replaced;
    }
    let response = await pushOnce(channel, name, payload, timeout);
    if (typeof afterResponse === "function") {
      const replaced = await afterResponse(response, context);
      if (replaced !== undefined) response = replaced;
    }
    return response;
  }

  return {
    available: true,

    invoke(context) {
      const { action, input, commandId, idempotency } = context;
      const payload = { action: action.id, input, commandId, ...(idempotency ? { idempotency } : {}) };
      return dispatch(event, payload, context);
    },

    reconcile(commandId) {
      return dispatch("reconcile", { commandId }, { commandId, reconcile: true });
    },
  };
}

/**
 * Maps channel events onto `client.events.emit` (validated by the runtime's
 * eventProjectionSchema). Returns refs (for channel.off) and unsubscribe.
 *
 * @param {{on: Function, off: Function}} channel
 * @param {{emit: (event: unknown) => void}} events `client.events`
 * @param {{eventNames?: string[], onError?: (error: unknown, payload: unknown) => void}} [options]
 */
export function createSurfaceChannelEvents(channel, events, options = {}) {
  const { eventNames = ["surface_event"], onError } = options;
  // Failures never propagate into Phoenix dispatch; they are reported to onError
  // and always recorded in the returned `errors` array (never silent).
  const errors = [];
  const report = (error, payload) => {
    errors.push({ error, payload });
    if (typeof onError !== "function") return;
    try {
      onError(error, payload);
    } catch (onErrorFailure) {
      errors.push({ error: onErrorFailure, payload });
    }
  };
  const entries = eventNames.map((name) => {
    const handler = (payload) => {
      const parsed = eventProjectionSchema.safeParse(payload);
      if (!parsed.success) {
        report(parsed.error, payload);
        return;
      }
      try {
        events.emit(parsed.data);
      } catch (error) {
        report(error, payload);
      }
    };
    const ref = channel.on(name, handler);
    return { name, ref };
  });
  const refs = entries.map((e) => e.ref);
  return {
    refs,
    errors,
    unsubscribe() {
      for (const { name, ref } of entries) channel.off(name, ref);
    },
  };
}
