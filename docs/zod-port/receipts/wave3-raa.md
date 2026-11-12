# Wave 3 RAA: route formatter non-vacuity and mapped route arguments

Standing: PASS

## Item 1: shim-court on `lib/ash_surface/compiler/route_schema.ex`

Scratch: `/tmp/raa` (tar of live repo, node_modules/deps symlinked, build root `/tmp/raa/_build-raa2`).
Each mutation: baseline sha256, mutate, run the three suites (formatter_single_emission_test,
ported/typed_controller/codegen_test, emitted_key_collision_renderers_test; 61 tests), restore,
sha256 equal. Unmutated baseline: rc=0, 61 tests, 0 failures.

| mutation | result |
|---|---|
| object keys raw (not formatted) | red, 6 failures |
| double emit (`emitted(emitted(n))`) | red, 2 failures |
| `path_params` formatted | red, 4 failures |
| inverse tables dropped (all) | red, 4 failures |
| inverse swapped (server=>client) | red, 4 failures |
| collision check skipped | red, 2 failures |
| only `body` table dropped / only `params` table dropped | red, 4 / 4 failures |
| only `query` table dropped | SURVIVED (0 failures) before repair |

Repair: `test/ash_surface/compiler/formatter_single_emission_test.exs` route test now also asserts
`g.field_names.query`, `p.field_names.params`, and empty `g.body` / `p.query` tables. Re-run:
`query` dropped red (4 failures), params inverted red (3 failures), restore sha256 equal, baseline green.
(Two of my mutation commands were identity no-ops and are not counted.)

## Item 2: mapped per-argument names on typed routes

Reference does not support it; no change made.

- `~/ash_typescript/lib/ash_typescript/typed_controller/dsl.ex:48-57` (`RouteArgument` struct: name,
  type, constraints, default, allow_nil? only) and `dsl.ex:83-119` (argument schema: name, type,
  constraints, allow_nil?, default; no mapping option).
- `request_handler.ex:305-344`: client names are only `format_output_field(arg.name)` with the input
  formatter as fallback; no per-argument override.
- `request_handler.ex:9-11,151`: `typescript_field_names` is applied to nested keys inside typed
  struct/NewType values, not to route argument names.

## Gates (live tree, `MIX_BUILD_ROOT=_build-raa`, un-piped rc)

- `mix test test/ash_surface/compiler test/ash_surface/ported/typed_controller`: rc=0, 451 tests,
  0 failures, 13 skipped.
- `mix ash_surface.parity.tests`: rc=0 (files=264 unaccounted=0 broken=0).
