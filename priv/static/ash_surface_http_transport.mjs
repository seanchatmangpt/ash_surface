// AshSurface HTTP transport adapter (TransportAdapter: invoke/available/reconcile).
//
// Transport law: after dispatch, ANY failure (network error, non-2xx, non-JSON
// body) THROWS. The runtime classifies a throw as TRANSPORT_OUTCOME_UNKNOWN /
// UNKNOWN_AFTER_DISPATCH and never replays over another transport. This adapter
// never returns a network_error-style envelope.

import { reconcileResultSchema } from "./ash_surface_runtime.mjs";

export class HttpTransportError extends Error {
  constructor(code, message, options = {}) {
    super(message, options.cause ? { cause: options.cause } : undefined);
    this.name = "HttpTransportError";
    this.code = code;
    this.status = options.status ?? null;
    // Preserved like ChannelTransportError.response: {status, ok, headers, body}
    // where body is the parsed JSON (or text when not JSON, null when empty).
    this.response = options.response ?? null;
    // "pre-dispatch" (nothing reached fetch) | "post-dispatch" (outcome unknown).
    this.phase = options.phase ?? "post-dispatch";
  }
}

/** Reads the Phoenix CSRF token from the document meta tag; null outside a browser. */
export function getPhoenixCSRFToken() {
  if (typeof document === "undefined" || typeof document.querySelector !== "function") return null;
  const meta = document.querySelector("meta[name='csrf-token']");
  const token = meta && typeof meta.getAttribute === "function" ? meta.getAttribute("content") : null;
  return token || null;
}

/** Header record carrying the CSRF token, or {} when none is available. */
export function buildCSRFHeaders(token = getPhoenixCSRFToken()) {
  return token ? { "x-csrf-token": token } : {};
}

function defaultValidateEndpoint(endpoint) {
  if (typeof endpoint !== "string" || endpoint.length === 0) {
    throw new HttpTransportError("INVALID_ENDPOINT", "endpoint must be a non-empty string", { phase: "pre-dispatch" });
  }
  return true;
}

// Cross-origin law: the endpoint is ALWAYS resolved with WHATWG `new URL(endpoint, base)`
// (no string-pattern pre-check) and the parsed origin must be the page origin (browser)
// or listed in options.allowedOrigins. Base = page href, else options.baseUrl.
// Node (no page, no baseUrl): relative endpoints are refused (RELATIVE_ENDPOINT_NO_BASE);
// absolute endpoints are refused unless allowedOrigins lists their origin.
// Returns the resolved absolute href, which is what gets dispatched.
function resolveEndpoint(endpoint, allowedOrigins, baseUrl) {
  const pageHref = globalThis.location?.href;
  const base = pageHref ?? baseUrl;
  let parsed;
  try {
    parsed = new URL(endpoint, base);
  } catch (cause) {
    const code = base == null ? "RELATIVE_ENDPOINT_NO_BASE" : "INVALID_ENDPOINT";
    throw new HttpTransportError(code, `endpoint is not a valid URL: ${String(endpoint)}`, { cause, phase: "pre-dispatch" });
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new HttpTransportError("INVALID_ENDPOINT", `endpoint scheme refused: ${parsed.protocol}`, { phase: "pre-dispatch" });
  }
  const allowed = new Set(allowedOrigins ?? []);
  const pageOrigin = globalThis.location?.origin;
  if (pageOrigin && pageOrigin !== "null") allowed.add(pageOrigin);
  if (baseUrl && !pageHref) {
    try {
      // an explicit baseUrl authorizes its own origin (relative endpoints resolve onto it)
      allowed.add(new URL(baseUrl).origin);
    } catch {
      throw new HttpTransportError("INVALID_ENDPOINT", "baseUrl is not a valid URL", { phase: "pre-dispatch" });
    }
  }
  if (!allowed.has(parsed.origin)) {
    throw new HttpTransportError("CROSS_ORIGIN_ENDPOINT", `cross-origin endpoint refused: ${parsed.origin}`, { phase: "pre-dispatch" });
  }
  return parsed.href;
}

function toHeaders(value) {
  try {
    return new Headers(value ?? undefined);
  } catch (cause) {
    throw new HttpTransportError("INVALID_HEADERS", "headers are not a valid HeadersInit", { cause, phase: "pre-dispatch" });
  }
}

function mergeHeaders(...sources) {
  const out = new Headers();
  for (const source of sources) {
    for (const [k, v] of toHeaders(source)) out.set(k, v);
  }
  return Object.fromEntries(out);
}

function reconcileUrl(resolvedEndpoint, commandId) {
  const u = new URL(resolvedEndpoint);
  u.search = `${u.search ? `${u.search}&` : "?"}commandId=${encodeURIComponent(commandId)}`;
  return u.href;
}

function csrfHeaders(csrf) {
  if (csrf === false || csrf == null) return {};
  if (typeof csrf === "string" && csrf !== "auto") return buildCSRFHeaders(csrf);
  const headers = buildCSRFHeaders();
  // csrf:"auto" with no document (Node) yields no header; csrf:"required"-style
  // strictness is opt-in via csrf:"require", which refuses pre-dispatch.
  return headers;
}

async function resolveHeaders(headers) {
  let value;
  try {
    value = typeof headers === "function" ? await headers() : headers;
  } catch (cause) {
    throw new HttpTransportError("HEADERS_RESOLVE_FAILED", `headers resolver failed: ${cause?.message ?? cause}`, { cause, phase: "pre-dispatch" });
  }
  return value && typeof value === "object" ? value : {};
}

/**
 * @param {Object} options
 * @param {string} [options.baseUrl] Base for relative endpoints when there is no page (Node).
 * @param {string[]} [options.allowedOrigins]
 * @param {string} options.endpoint POST target for invoke; GET `?commandId=` target for reconcile.
 * @param {(endpoint: string) => unknown} [options.validateEndpoint] Throws or returns false to refuse.
 * @param {Record<string,string>|(() => Record<string,string>|Promise<Record<string,string>>)} [options.headers]
 * @param {RequestInit} [options.fetchOptions]
 * @param {typeof fetch} [options.customFetch]
 * @param {"auto"|false|string} [options.csrf="auto"]
 * @param {(request: {url: string, init: RequestInit, context: object}) => unknown} [options.beforeRequest] May return a replacement {url?, init?}.
 * @param {(result: {response: Response, body: unknown, context: object}) => unknown} [options.afterRequest]
 */
export function createHttpTransport(options = {}) {
  const {
    endpoint,
    validateEndpoint = defaultValidateEndpoint,
    headers,
    fetchOptions = {},
    customFetch,
    csrf = "auto",
    beforeRequest,
    afterRequest,
    allowedOrigins,
    baseUrl,
  } = options;

  if (validateEndpoint(endpoint) === false) {
    throw new HttpTransportError("INVALID_ENDPOINT", `endpoint refused by validateEndpoint: ${String(endpoint)}`, { phase: "pre-dispatch" });
  }
  const resolvedEndpoint = resolveEndpoint(endpoint, allowedOrigins, baseUrl);
  const recheck = (url) => resolveEndpoint(url, allowedOrigins, baseUrl);

  const csrfFor = () => {
    if (csrf === "require") {
      const token = getPhoenixCSRFToken();
      if (!token) throw new HttpTransportError("CSRF_TOKEN_UNAVAILABLE", "csrf:\"require\" but no CSRF token is available (no document/meta tag)", { phase: "pre-dispatch" });
      return buildCSRFHeaders(token);
    }
    return csrfHeaders(csrf);
  };

  const doFetch = (url, init) => (customFetch ?? globalThis.fetch)(url, init);

  async function send(url, init, context) {
    if (typeof beforeRequest === "function") {
      let replaced;
      try {
        replaced = await beforeRequest({ url, init, context });
      } catch (cause) {
        throw new HttpTransportError("HTTP_BEFORE_REQUEST_FAILED", `beforeRequest threw: ${cause?.message ?? cause}`, { cause, phase: "pre-dispatch" });
      }
      if (replaced && typeof replaced === "object") {
        url = replaced.url ?? url;
        init = replaced.init ?? init;
      }
    }
    // Final-URL origin check right before fetch (beforeRequest may swap the url
    // after CSRF/idempotency headers are already in init).
    url = recheck(url);

    let response;
    try {
      response = await doFetch(url, init);
    } catch (cause) {
      throw new HttpTransportError("HTTP_NETWORK_FAILURE", `HTTP request failed: ${cause?.message ?? cause}`, { cause });
    }

    let text;
    try {
      text = await response.text();
    } catch (cause) {
      throw new HttpTransportError("HTTP_INVALID_BODY", "HTTP response body could not be read", { cause, status: response.status });
    }
    const empty = text.trim().length === 0;
    let body = null;
    let jsonOk = empty;
    if (!empty) {
      try {
        body = JSON.parse(text);
        jsonOk = true;
      } catch {
        body = text;
      }
    }
    const preserved = { status: response.status, ok: response.ok, headers: Object.fromEntries(response.headers), body };

    if (!response.ok) {
      throw new HttpTransportError("HTTP_NON_2XX", `HTTP status ${response.status}`, { status: response.status, response: preserved });
    }
    // Typed empty-success: a 2xx with no body (e.g. 204) is a successful dispatch
    // whose result is null; the runtime's output schema decides admissibility.
    if (!jsonOk) {
      throw new HttpTransportError("HTTP_INVALID_BODY", "HTTP response body is not JSON", { status: response.status, response: preserved });
    }

    if (typeof afterRequest === "function") {
      let replaced;
      try {
        replaced = await afterRequest({ response, body, context });
      } catch (cause) {
        throw new HttpTransportError("HTTP_AFTER_REQUEST_FAILED", `afterRequest threw: ${cause?.message ?? cause}`, { cause, status: response.status, response: preserved, phase: "post-dispatch" });
      }
      if (replaced !== undefined) body = replaced;
    }
    return body;
  }

  return {
    available: true,

    async invoke(context) {
      const { action, input, commandId, signal, idempotency } = context;
      const merged = mergeHeaders(
        fetchOptions.headers,
        { "Content-Type": "application/json" },
        csrfFor(),
        await resolveHeaders(headers),
        idempotency?.key ? { [idempotency.keyHeader ?? "Idempotency-Key"]: idempotency.key } : {},
      );

      let body;
      try {
        body = JSON.stringify({ action: action.id, input, commandId });
      } catch (cause) {
        throw new HttpTransportError("INVALID_REQUEST_BODY", `request body is not JSON-serializable: ${cause?.message ?? cause}`, { cause, phase: "pre-dispatch" });
      }
      const init = {
        ...fetchOptions,
        method: "POST",
        headers: merged,
        body,
        ...(signal ? { signal } : {}),
      };
      return send(resolvedEndpoint, init, context);
    },

    async reconcile(commandId) {
      const url = reconcileUrl(resolvedEndpoint, commandId);
      const init = {
        ...fetchOptions,
        headers: mergeHeaders(fetchOptions.headers, await resolveHeaders(headers)),
      };
      delete init.method;
      delete init.body;
      const body = await send(url, init, { commandId, reconcile: true });
      const parsed = reconcileResultSchema.safeParse(body);
      if (!parsed.success) {
        throw new HttpTransportError("HTTP_INVALID_RECONCILE", "reconcile reply failed reconcileResultSchema");
      }
      return body;
    },
  };
}
