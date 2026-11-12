# Wave 2 JS Lane Receipt

Standing: PARTIAL

Lane js (census lane 19). Subject: working tree of /Users/sac/ash_surface (no SHA; uncommitted).

## Files

- NEW priv/static/ash_surface_http_transport.mjs (createHttpTransport, getPhoenixCSRFToken,
  buildCSRFHeaders, HttpTransportError)
- NEW priv/static/ash_surface_channel_transport.mjs (createChannelTransport,
  createSurfaceChannelEvents, ChannelTransportError)
- lib/ash_surface/projector/expo.ex (D1 relative import, D2 reconcile delegation, D3 option
  forwarding, quoted non-identifier keys)
- test/js/http_transport.test.mjs, test/js/channel_transport.test.mjs (NEW)
- test/js/generated_client_reconcile_runner.mjs (real node:http server)
- test/ash_surface/projector/expo_client_reconcile_test.exs, expo_client_test.exs

## Law

After dispatch, non-2xx, network failure, non-JSON body, channel error reply, channel timeout all
THROW; the runtime classifies them TRANSPORT_OUTCOME_UNKNOWN. No network_error envelope, no retry.
reconcile (HTTP GET `?commandId=`, channel push "reconcile") validates with the runtime's
reconcileResultSchema and throws on invalid. The in-memory channel in the tests is a hand-written
real implementation of push/receive/on/off, not a mock.

## Commands

- `node --test test/js/http_transport.test.mjs test/js/channel_transport.test.mjs
  test/js/transport_law.test.mjs test/js/runtime_hardening.test.mjs
  test/js/idempotency_retry.test.mjs test/js/observability_events.test.mjs`
  -> tests 80, pass 80, fail 0.
- `MIX_BUILD_ROOT=_build-js mix test test/ash_surface/projector/expo_client_test.exs
  test/ash_surface/projector/expo_client_reconcile_test.exs` -> 4 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-js mix test test/ash_surface/projector/expo_*_test.exs
  test/ash_surface/projector/generated_artifacts_exec_test.exs` -> 42 tests, 7 failures (see below).
- `_build-js` deleted.

## Behaviour changes

- D1: emitted client imports `./ash_surface_runtime.mjs` and `./ash_surface_http_transport.mjs`.
- D2: `client.reconcile` is the runtime's; `reconcileEndpoint` builds a reconcile-only HTTP adapter
  (available:false, never selected for dispatch). Reconcile failures now THROW instead of returning
  STILL_UNKNOWN (law); no transport -> runtime's typed STILL_UNKNOWN reason
  transport_reconciliation_unsupported.
- D3: `onEvent` and all other createClient options forwarded (`...rest`, `schemas` overridable).
- Non-identifier field keys are JSON-quoted (own regex in expo.ex; schema.ex untouched).

## UNVERIFIED / failing outside owned files

- 3 of the 7 failures are GeneratedArtifactsExecTest tanstack/client tests: that file
  (not owned) installs only a `node_modules/ash_surface` shim, so the relative runtime import is
  unresolved (ERR_MODULE_NOT_FOUND ash_surface_runtime.mjs). Fix: copy the three runtime .mjs
  files into the target dir in its `install_runtime_shim!`.
- 4 failures are schemas runner tests (`read must reject ...` uuid input accepted); they sit in
  generated_expo_schemas_runner/zod_type.ex territory (zod_type.ex is untracked, another lane);
  cause not isolated here, UNVERIFIED as pre-existing.
- projector copying runtime files into target_dir was tried and reverted:
  expo_determinism_test pins the documented artifact set.
- Full `mix test` not run (VM-exit abort, pre-existing).

## Requests

1. Codegen task must copy ash_surface_runtime.mjs, ash_surface_http_transport.mjs,
   ash_surface_channel_transport.mjs beside generated artifacts (and update
   generated_artifacts_exec_test.exs shim accordingly).
2. package.json exports map decision: expose `./http-transport` and `./channel-transport`
   subpaths (and the bare "ash_surface" runtime entry) or keep file-copy only.
3. Conformance transport vectors: HTTP/channel throw-on-failure and reconcile validation cases
   for conformance/vectors.
