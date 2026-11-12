# wave3-f1or

Standing: PASS

Lane F1-origin-b. Subject: /Users/sac/ash_surface working tree (uncommitted, SHA e3b5d7ffe + dirty).

## State found
Prior lane had landed: `resolveEndpoint` in priv/static/ash_surface_http_transport.mjs
(always `new URL(endpoint, base)`, origin compare, relative needs page/baseUrl, absolute needs
allowedOrigins), replay.mjs allowedOrigins, expo.ex reconcileBaseUrl/reconcileAllowedOrigins,
runtime phase classification (isAdapterPreDispatch), unique per-test tmp dir in
expo_origin_test.exs.

## Defect fixed this lane
expo_origin_test.exs script read `process.argv.slice(1)` (included the script path), so node
resolved `run.mjs/zoela_surface.mjs` -> ERR_MODULE_NOT_FOUND. Changed to `slice(2)`.

## Commands (MIX_BUILD_ROOT=_build-f1ob)
- mix test expo_origin_test.exs expo_client_reconcile_test.exs: 2 tests, 0 failures (before fix: 1 failure)
- mix test test/ash_surface/projector: 91 tests, 0 failures
- node conformance/js/replay.mjs: exit 0
- suite transport_*, runtime_source, codegen_runtime_copy, runtime_parity, projector: 231 tests, 3 properties, 0 failures, exit 0

## Falsifiers
Origin test asserts absolute own-origin COMPLETED, relative-no-base RELATIVE_ENDPOINT_NO_BASE,
relative-with-base COMPLETED; real node:http server, no mocks, no sleeps.

## Re-pins (typed causes verified)
- transport_falsifiers_test / transport_fallback_test export guards now list `classify_failure: 2`
  (pure phase classifier in transport.ex, takes no Decision, has its own transport_classify_test).
- expo_wave3_s1h_court_test "hostile keys": route_schema.ex:185 deliberately refuses `__proto__`
  with `{:denied_argument_name, route, "__proto__"}` (S2b-b). Test now asserts that refusal and
  drops `__proto__` from the lawful quoted-key case.
