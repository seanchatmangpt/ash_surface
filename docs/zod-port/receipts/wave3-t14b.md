# Wave 3 Lane T14b Receipt (typed_controller gaps)

Standing: PARTIAL

Three of four T14 skipped_gap rows converted to adapted with real tests; request_handler_test stays
skipped_gap (README: AshSurface never actuates; no Plug runtime built).

## Converted / still skipped

| row | before | after | file |
|---|---|---|---|
| base_path_test | skipped_gap (5 skips) | adapted, 0 skips | ported/typed_controller/base_path_test.exs |
| codegen_enforcement_test | skipped_gap (2) | adapted, 0 skips | ported/typed_controller/codegen_enforcement_test.exs |
| verify_typed_controller_test | skipped_gap (5) | adapted, 0 skips | ported/typed_controller/verify_typed_controller_test.exs |
| request_handler_test | skipped_gap (13) | skipped_gap (13), operator decision | request_handler_gap_test.exs |

Converted 3 rows (12 loud skips removed), still skipped 1 row (13 skips). Old three gap files deleted.

## Lib edits

- `lib/ash_surface/compiler/route_schema.ex`: `build/2` opts `:base_path` (string or
  `{:runtime_expr, js}`), `:mode` (`:full | :paths_only`), `:verify`; defaults read from
  `Config.typed_controller_base_path/0` and `typed_controller_mode/0` (previously unread).
  `namespace_plan/2` consumes `enable_controller_namespace_files` and
  `controller_namespace_output_dir`. `build/1` behavior unchanged (default `""`/`:full`).
- `lib/ash_surface/compiler/route_schema/verifier.ex` (new): descriptor-level
  VerifyTypedController equivalent; typed refusals `duplicate_route_names`,
  `invalid_argument_types`, `invalid_names`, `invalid_field_names` (nested paths).
- Not done: `typed_controller_path_params_style`, hooks, error handler keys stay unread
  (no consumer without a request runtime / TS output). F1-cfgkeys rows/tests not edited.

## Divergences pinned

- ZodType renders `map` as `z.record(z.string(), z.unknown())`; no field-level inline expansion
  of typed maps (pinned in codegen_enforcement_test). Missing-handler verifier case has no
  descriptor counterpart (handlers are actuation).

## Commands (MIX_ENV=test, MIX_BUILD_ROOT=_build-t14b, un-piped rc)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/typed_controller test/ash_surface_mock_discipline_test.exs test/ash_surface/no_local_do_test.exs` | 0 | 99 tests, 0 failures, 13 skipped (all request_handler gap) |
| `mix format --check-formatted` on touched lib + tests | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 | global red from other lanes: files=264 ported=9 adapted=136 skipped_gap=64 non_goal=16 unaccounted=34 broken=5 shallow=54; no typed_controller line flagged |

First test run failed once (map-field assertion against a field-expanding Zod that does not
exist); test re-pinned to the real record behavior. No allowlist edits; no_local_do green.
`_build-t14b` deleted. Ledger edited with three targeted string replacements, JSON re-validated.

## Operator decisions

- request_handler_test: keep skipped_gap, or record non_goal (needs a README quote).
