# wave3-rx

Standing: PASS

Lane RX: strengthen tests that survived mutation in wave3-skmutd (test files only).
Subject: HEAD e3b5d7ffe plus uncommitted working tree (test/ported untracked).

## Tests added

- `typed_controller/router_introspection_test.exs`: controller identity (second controller
  sharing an action name), mount ordering in reverse-declared router, `introspect_router`
  `{path, verb}` ordering, method downcasing for unmounted routes (`"GET"`, `:POST`), nil method.
- `typed_controller/codegen_enforcement_test.exs`: node+zod extra-key rejection on a route body.
- `ts/should_fail/typed_controller_results_fail_test.exs`: extra-key refusal on body and query.
- `typed_channel/channel_payload_test.exs`: `returns_kind` is `"map"` for inline maps, `"map"`
  for a NewType reference (type_ref branch), nil when no returns. `channel_runtime_gap_test.exs`
  left untouched (loud-skip gap file).

## Mutation proof (scratch /tmp/rx, tar of live repo, sha256 restore verified each run)

| mutation | rc | result |
|---|---|---|
| drop `plug == controller` | 2 | 1 failure (red) |
| mount sort reversed / dropped | 2 / 2 | 1 failure each (red) |
| introspect_router sort reversed / dropped | 2 / 2 | 1 failure each (red) |
| method downcase removed | 2 | 1 failure (red) |
| `.strict()` removed (codegen_enforcement) | 2 | 1 failure (red) |
| `.strict()` removed (results_fail) | 2 | 1 failure (red) |
| `returns_kind` -> "unknown" | 2 | 2 failures (red) |
| type_ref branch -> "type_ref" | 2 | 1 failure (red) |

All restores sha256-identical. Harness `/tmp/rx/mut.py`, raw `/tmp/rx/out_*.txt`.

## Live gates (MIX_BUILD_ROOT=_build-rx)

- `mix test test/ash_surface/ported/typed_controller test/ash_surface/ported/typed_channel
  test/ash_surface/ported/ts`: rc=0 (un-piped), 376 tests, 0 failures, 27 skipped.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.

## Disclosures

- Substrate moved: `lib/ash_surface/field_name.ex` (untracked, other lane, mtime 02:48) made
  emitted names camelCase; `ts/should_pass/zod_route_cases_test.exs` failed deterministically
  (`rememberMe`). Repaired test-only by wrapping its `RouteSchema.build` in
  `AshNames.with_verbatim` (not an owned file; targeted edit).
- Latent lib defect, not fixed: `Introspector.common_suffix/1` trims a shared trailing
  grapheme, not a segment (helpers `alpha_auth_path`/`zeta_auth_path` give prefixes
  `alph`/`zet`). New ordering test uses `alpha`/`zulu` to avoid it. UNVERIFIED elsewhere.
- Intermittent `codegen_test.exs` failure (verbatim expectation) seen once in a combined run,
  passed alone 2x and in the final full run.
