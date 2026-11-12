# wave3-t9

Standing: PARTIAL

Lane T9 (rpc/ json_manifest_generator .. map_field_name_rpc, 8 files, 223 reference tests).
All 8 ledger rows accounted, `broken=0`. Run-time execution, JSON/markdown manifest generator
and lifecycle-hook codegen-text tests are gaps/non-goal; selection, load-restriction,
keyword-validation and hook-config tests run for real.

## Per-file disposition

| reference file | disposition | ash_surface test(s) (test/ash_surface/ported/rpc/b/) |
|---|---|---|
| json_manifest_generator_test | skipped_gap (59 skips; 1 test ported to config file) | json_manifest_generator_gap_test, manifest_generator_config_test |
| keyword_field_formatting_test | skipped_gap (2 skips) | keyword_field_formatting_gap_test |
| keyword_field_validation_test | ported (8 tests) | keyword_field_validation_test |
| lifecycle_hooks_codegen_test | non_goal (README quote, see below) | none |
| lifecycle_hooks_config_test | adapted (20 tests) | lifecycle_hooks_config_test |
| load_restrictions_test | skipped_gap (21 skips; 25 tests ported) | load_restrictions_test, load_restrictions_gap_test |
| manifest_generator_test | skipped_gap (53 skips; 3 ported to config file) | manifest_generator_gap_test, manifest_generator_config_test |
| map_field_name_rpc_test | skipped_gap (9 skips; +5 selection tests) | map_field_name_rpc_gap_test, map_field_name_selection_test |

## Commands and exits (MIX_BUILD_ROOT=_build-t9 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/b test/ash_surface/no_local_do_test.exs test/ash_surface_mock_discipline_test.exs test/ash_surface/config` | 0 | 331 tests, 0 failures, 144 skipped (all skips are the loud T9 gap tags) |
| per-file: keyword_field_validation / lifecycle_hooks_config / load_restrictions / manifest_generator_config / map_field_name_selection | 0 | 8 / 20 / 25 / 4 / 5 tests, 0 failures, 0 skips |
| `mix format --check-formatted` (rpc/b + config.ex) | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes unaccounted) | `files=264 ported=1 adapted=81 skipped_gap=59 non_goal=11 unaccounted=112 broken=0 shallow=33` (whole-repo at run time; T9 contributes ported=1 adapted=1 skipped_gap=5 non_goal=1) |

## lib edit (disclosed)

`lib/ash_surface/config.ex`: appended `rpc_action_hooks_enabled?/0` and
`rpc_validation_hooks_enabled?/0` (before/after hook configured predicates), required by the
hook-config port. No other lib edits.

## Operator-decision list

- `lifecycle_hooks_codegen_test.exs` is `non_goal` with README quote "no generated `.ts`, no
  `.d.ts`, no `tsc` build step" (grep -F count 1). The README states no hook-specific
  non-goal; the quote supports it only through "tests assert generated TypeScript text".
  Same quote/rationale as the T15 hook rows. Reclassify to skipped_gap if rejected.
- JsonManifestGenerator / ManifestGenerator are not implemented (new generators over a domain
  rpc action registry that ash_surface does not have); left as loud gaps. Decide whether a
  ash_surface-native machine-readable action manifest is wanted.
- run_action execution (21 + 9 + 2 tests) stays a gap pending a Pipeline decision; note other
  lanes are landing RuntimeParity.Rpc.{ResultProcessor,ValueFormatter,...} in flight.

## Standing detail

UNVERIFIED: ledger edit was a read-modify-write of parity/test_ledger.json restricted to T9
rows (indent-2 serialization); concurrent-lane rows were not touched but the file was
re-serialized. `_build-t9` removed at lane end.
