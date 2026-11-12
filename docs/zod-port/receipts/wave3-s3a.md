# Wave 3 S3-A: HTTP transport origin law and pre-dispatch tagging

Standing: PARTIAL_ALIVE

## Commands

- `node --test test/js/http_transport.test.mjs test/js/http_transport_h5_m13.test.mjs
  test/js/http_transport_s3a.test.mjs test/js/transport_law.test.mjs
  test/js/runtime_hardening.test.mjs` -> exit 0 (pipe-filtered), 57 tests, 57 pass, 0 fail
  (5 new in http_transport_s3a.test.mjs).
- `node --test test/js/conformance_replay.test.mjs` -> 16 tests, 10 pass, 5 fail (timed out
  at ~110 s). Failing: corpus agreement, MUST accounting, replay-can-fail, w3-04 kinds, w3-04
  transport wire vectors. Cause UNVERIFIED; the likely cause is that replay.mjs passes
  absolute endpoints with no allowlist, which the new law refuses (see follow-ups).
- No mix run; no build dir.

## Changes (priv/static/ash_surface_http_transport.mjs)

1. Origin check: `resolveEndpoint` always uses `new URL(endpoint, base)`, with no regex
   pre-check. Base is the page href, else the new `baseUrl` option. The parsed origin must be
   the page origin, the `baseUrl` origin or in `allowedOrigins`. Only http/https is accepted.
   Unparseable input is refused. Node policy: relative endpoints need `baseUrl`
   (RELATIVE_ENDPOINT_NO_BASE); absolute endpoints need `allowedOrigins`
   (CROSS_ORIGIN_ENDPOINT). The resolved href is what is dispatched and reconciled.
2. `beforeRequest` replacement url is re-checked immediately before fetch.
3. Pre-dispatch failures (non-serializable body, headers resolver throw) now throw
   HttpTransportError phase "pre-dispatch" with codes INVALID_REQUEST_BODY and
   HEADERS_RESOLVE_FAILED.

Existing http_transport tests were updated to pass `allowedOrigins` for their absolute
local-server endpoints.

## Courts (real node:http servers, real fetch)

- The five bypass inputs (`\\evil`, `/\evil`, ` //evil`, tab variants) were refused under
  4 option combinations each, and the servers received 0 requests.
- A beforeRequest url swap (foreign origin and backslash form) was refused with 0 requests.
- A BigInt or circular body gives INVALID_REQUEST_BODY (pre-dispatch). A headers throw gives
  HEADERS_RESOLVE_FAILED on invoke and reconcile.
- A real dead-port network failure gives phase post-dispatch. Through `createClient` it
  classifies as TRANSPORT_OUTCOME_UNKNOWN with receipt dispatchState unknown_after_dispatch.

## Follow-ups for other owners

- RUNTIME (ash_surface_runtime.mjs ~line 757, not mine): the catch block ignores
  `cause.phase`, so pre-dispatch-tagged errors are also classified
  TRANSPORT_OUTCOME_UNKNOWN / unknown_after_dispatch (witnessed in the s3a court, which logs
  it). The runtime should map `phase === "pre-dispatch"` to a not-dispatched typed refusal.
- conformance/js/replay.mjs (lines ~568, 610-611; owner w3-04): add `allowedOrigins:
  [new URL(url).origin]` to the createHttpTransport calls.
- lib/ash_surface/projector/expo.ex (~line 410; owner S1-H): the generated reconcile call
  passes an absolute `reconcileEndpoint` with no allowlist and needs `allowedOrigins` (or
  `baseUrl`). Any projector goldens containing it must be regenerated.
- ash_surface_channel_transport.mjs was not touched.
