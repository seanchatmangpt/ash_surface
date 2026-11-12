# Wave 3 Lane T14 Receipt (typed_controller)

Standing: PARTIAL

All 8 `typed_controller/` reference files accounted (4 adapted, 4 skipped_gap). Runtime handler,
DSL verifier, base_path and controller-codegen enforcement have no ash_surface counterpart and
are loud skips, not implemented.

## Per-file disposition

| reference file | disposition | ash_surface file |
|---|---|---|
| fold_argument_constraints_test | adapted | ported/typed_controller/fold_argument_constraints_test.exs |
| router_introspection_test | adapted | ported/typed_controller/router_introspection_test.exs |
| namespace_test | adapted | ported/typed_controller/namespace_test.exs |
| codegen_test | adapted | ported/typed_controller/codegen_test.exs |
| base_path_test | skipped_gap (5 skips) | ported/typed_controller/base_path_gap_test.exs |
| codegen_enforcement_test | skipped_gap (2) | ported/typed_controller/codegen_enforcement_gap_test.exs |
| request_handler_test | skipped_gap (13) | ported/typed_controller/request_handler_gap_test.exs |
| verify_typed_controller_test | skipped_gap (5) | ported/typed_controller/verify_typed_controller_gap_test.exs |

Per-test notes for unported reference tests are in each row's `changes` in
`parity/test_ledger.json`.

## Gate (MIX_ENV=test, MIX_BUILD_ROOT=_build-t14, un-piped capture)

`mix ash_surface.parity.tests --summary` rc=1 (global, other lanes open):
`parity-tests: files=264 ported=8 adapted=101 skipped_gap=56 non_goal=11 unaccounted=88
broken=0 shallow=41`. My directory: `typed_controller files=8 adapted=4 skipped_gap=4
unaccounted=0 broken=0`; SHALLOW warnings (warning only) on namespace_test and
router_introspection_test.

## Commands

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/typed_controller test/ash_surface_mock_discipline_test.exs` | 0 | 85 tests, 0 failures, 25 skipped (all 25 skips are the loud gap tests) |
| `mix format --check-formatted test/ash_surface/ported/typed_controller/*.exs` | 0 | clean |
| `mix ash_surface.parity.tests` | 1 | global gate red from other lanes' rows; T14 rows 0 unaccounted |

The first parity run hit another lane's in-flight `lib/ash_surface/runtime_parity/rpc/*.ex`
compile errors; re-polled until it compiled. T5's fixture file was not used; all fixtures are
private (`support/tc_support.exs`, local Phoenix routers, real node + zod, per-call unique tmp
dir). `_build-t14` deleted.

## Lib edits

None.

## Divergences observed (pinned in tests/ledger, not hidden)

- `Fold` admits unknown constraint keys (no `Ash.Type.constraints` schema); only ill-typed
  known keys are refused.
- `Fold` folds `allow_empty?: false` for string kinds but not `trim?`; array item constraints
  are not folded.
- Introspector verbs and path params are strings; ambiguous mounts are typed errors, not raises.
- `typed_controller_base_path`, `typed_controller_mode`, `controller_namespace_*` config keys
  are declared but read nowhere.

## Operator decisions

- TS-only reference tests inside adapted rows (hooks, imports, paths_only, args style, Valibot,
  namespace re-export files) are recorded as per-test notes citing README "no generated `.ts`".
  No `non_goal` row was claimed. Say if any should become a split skipped_gap (e.g. base_path /
  paths_only implementation in RouteSchema, owned by other lanes).
- Request handler: implementing a Plug runtime would cross README boundary 1 (AshSurface never
  actuates); left as skipped_gap pending a decision.
