# Wave 3 S1-E: HTTP transport H5 and M13

Standing: PASS

## Commands

- `node --test test/js/http_transport.test.mjs test/js/http_transport_h5_m13.test.mjs
  test/js/transport_law.test.mjs test/js/runtime_hardening.test.mjs`
  -> 52 tests, 52 pass, 0 fail (8 new in http_transport_h5_m13.test.mjs).
- No mix run; no build dir created.

## Files changed

- priv/static/ash_surface_http_transport.mjs
- test/js/http_transport_h5_m13.test.mjs (new; real node:http server, real fetch, no mocks)

## Fixed

- H5: non-2xx error carries `response` {status, ok, headers, body (parsed JSON, else text)};
  204/empty 2xx returns `null` (typed empty-success; the runtime output schema decides);
  non-JSON 2xx still throws HTTP_INVALID_BODY with response preserved. Always throws, no retry.
- M13: Headers/array/object headers normalized via `Headers`; reconcile URL built via `URL`
  (query before fragment, `%20` encoding kept); `allowedOrigins` option refuses cross-origin
  absolute endpoints (CROSS_ORIGIN_ENDPOINT); `csrf:"require"` refuses pre-dispatch with
  CSRF_TOKEN_UNAVAILABLE; `csrf:"auto"` in Node stays `{}` (documented); errors carry
  `phase` ("pre-dispatch" for beforeRequest/validation, "post-dispatch" otherwise).

## Registered (not fixed)

- Cross-origin refusal is enforced only when `allowedOrigins` is given or a page origin exists
  (browser). With neither (Node), absolute endpoints are accepted, because
  conformance/js/replay.mjs and lib/ash_surface/projector/expo.ex (not owned) use absolute
  endpoints without an allowlist.
- Runtime does not special-case `null` results; an action with an output schema rejecting null
  yields OUTPUT_VALIDATION_FAILED (classification unchanged).
