# Wave 3 Lane T11 Receipt

Standing: PARTIAL

Scope: `rpc/` rpc_identities .. struct_argument (15 reference files, 233 tests). 3 files
`adapted` (real behavior), 12 files `skipped_gap` (every reference test has a loud per-test
skip). Reference `~/ash_typescript` HEAD `5d6e80aec1afcbabaf0831768c210fecd81bd869`.

## Per-file disposition

| reference file | ash_surface file(s) | disposition |
|---|---|---|
| rpc_input_optionality | ported/rpc/d/rpc_input_optionality_test.exs (4 tests) | adapted (manifest action inputs required?/allow_nil?) |
| runtime_source_of_truth_guard | ported/rpc/d/runtime_source_of_truth_guard_test.exs (7 tests) | adapted (runtime_parity files, Compat sole reader) |
| struct_argument | ported/rpc/d/struct_argument_test.exs (8 tests) + struct_argument_gap_test.exs (4 loud skips, not on the row) | adapted; per-test notes in row `changes` |
| rpc_identities (21) | rpc_identities_gap_test.exs | skipped_gap |
| rpc_integration (19) | rpc_integration_gap_test.exs | skipped_gap |
| rpc_mapped_identity_fields (4) | rpc_mapped_identity_fields_gap_test.exs | skipped_gap |
| rpc_metadata (35) | rpc_metadata_gap_test.exs | skipped_gap (DSL half already in metadata_projection_test.exs) |
| rpc_optional_fields (8) | rpc_optional_fields_gap_test.exs | skipped_gap |
| rpc_pipeline (35) | rpc_pipeline_gap_test.exs | skipped_gap |
| rpc_validate_action_read_action (2) | rpc_validate_action_read_action_gap_test.exs | skipped_gap |
| rpc_validate_action (12) | rpc_validate_action_gap_test.exs | skipped_gap |
| rpc_validation_error_structure (14) | rpc_validation_error_structure_gap_test.exs | skipped_gap |
| run_typed_query (13) | run_typed_query_gap_test.exs | skipped_gap |
| sort_and_filter_types (47) | sort_and_filter_types_gap_test.exs | skipped_gap |
| struct_argument_integration (8) | struct_argument_integration_gap_test.exs | skipped_gap |

Gap reasons: no in-process `Rpc.run_action`/`validate_action`/`Pipeline` request parser
(capabilities `runtime.module.Rpc*`), no `run_typed_query`, TS SortField/FilterField text
(README: no generated `.ts`). Gap files mirror every reference describe/test name.
The gap rows were not implemented under the divergence law: the missing surface is the
in-process RPC runtime (a design non-existence, not a feature slice within this lane).
Note: another lane has since added `lib/ash_surface/runtime_parity/rpc/value_formatter.ex`;
I did not re-evaluate gap rows against it (UNVERIFIED whether any gap test is now portable).

## Commands (MIX_BUILD_ROOT=_build-t11 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/d` | 0 | 241 tests, 0 failures, 222 skipped |
| `mix test` mock_discipline court + `ported/rpc/d` | 0 | 243 tests, 0 failures, 222 skipped |
| `mix format --check-formatted test/ash_surface/ported/rpc/d/*.exs` | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (gate, other lanes pending) | `files=264 ported=1 adapted=81 skipped_gap=59 non_goal=11 unaccounted=112 broken=0 shallow=33` |

My 15 rows: adapted=3, skipped_gap=12, unaccounted=0, broken=0.

## lib edits

None. `parity/test_ledger.json`: T11 rows only (round-trip-exact JSON patch of 15 rows;
re-read immediately before write). `_build-t11` deleted.

## Operator decisions

- Whether to build an in-process `run_action`/`validate_action` pipeline (would unlock 12 gap
  rows, ~210 tests) or record them as README non-goals (no README sentence covers runtime
  pipeline, so they stay skipped_gap).
