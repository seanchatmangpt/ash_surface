# wave3-t10

Standing: PARTIAL

Lane T10 (reference `rpc/` namespace .. rpc_get_actions, 17 files, 269 tests). All 17 rows are
accounted (0 unaccounted, 0 broken). 34 of 269 tests run for real; 235 are per-test loud skips.

## Per-file disposition

| reference file | disposition | runnable test file | tests run | loud skips |
|---|---|---|---|---|
| namespace_test | adapted | ported/rpc/c/namespace_resolution_test.exs | 8 | 40 (namespace_gap_test.exs) |
| result_processor_duration_test | ported | result_processor_duration_test.exs | 7 | 0 |
| result_processor_keyword_test | ported | result_processor_keyword_test.exs | 9 | 0 |
| result_processor_plain_map_test | ported | result_processor_plain_map_test.exs | 4 | 0 |
| nested_query_opts_result_test | adapted | nested_query_opts_result_test.exs | 6 | 0 |
| nested_map_field_formatting_test | skipped_gap | (gap file) | 0 | 4 |
| nested_query_opts_pipeline_test | skipped_gap | (gap file) | 0 | 14 |
| nested_query_opts_test | skipped_gap | (gap file) | 0 | 28 |
| optional_tenant_for_all_actions_test | skipped_gap | (gap file) | 0 | 9 |
| output_field_formatting_test | skipped_gap | (gap file) | 0 | 2 |
| pagination_advanced_test | skipped_gap | (gap file) | 0 | 19 |
| private_arguments_test | skipped_gap | (gap file) | 0 | 15 |
| restricted_schema_codegen_test | skipped_gap | (gap file) | 0 | 15 |
| rpc_composite_primary_key_test | skipped_gap | (gap file) | 0 | 9 |
| rpc_field_argument_mapping_test | skipped_gap | (gap file) | 0 | 9 |
| rpc_function_generation_mapped_fields_test | skipped_gap | (gap file) | 0 | 22 |
| rpc_get_actions_test | skipped_gap | (gap file) | 0 | 49 |

Namespace: 8 of 9 resolution tests ported to the real precedence chain (projection > resource >
domain `namespace`) on Spark-compiled inline domains/resources; the 9th (needs domain rpc
entries) and the JSDoc/multi-file/custom-code describes are loud skips (no generated `.ts`).
Gap files carry one `@tag skip:` per reference test (`T10 gap: <file>` + capability ids).

## Commands

| command (MIX_BUILD_ROOT=_build-t10 MIX_ENV=test) | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/c` | 0 | 269 tests, 0 failures, 235 skipped |
| `mix format --check-formatted test/ash_surface/ported/rpc/c/*.exs` | 0 | clean |
| `mix test test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes open) | below |

`parity-tests: files=264 ported=8 adapted=101 skipped_gap=56 non_goal=11 unaccounted=88 broken=0
shallow=41`. T10 rows: ported 3, adapted 2, skipped_gap 12.

## Lib edits

None.

## Follow-up and operator decisions

- UNVERIFIED staleness: `lib/ash_surface/runtime_parity/rpc/pipeline.ex` landed from another
  lane while this lane ran (it was mid-edit and uncompilable at times). Gap texts for
  nested_query_opts_pipeline, pagination_advanced, private_arguments, rpc_composite_primary_key,
  rpc_field_argument_mapping, rpc_get_actions and optional_tenant (pipeline part) say "no
  Rpc.Pipeline runtime" and should be re-triaged against it; those were not re-ported.
- nested query-opts envelope (nested_query_opts_test, 28 tests) has no counterpart in
  RuntimeParity.RequestedFields; implementing it is a follow-up capability.
- TypeScript-text files (restricted_schema_codegen, rpc_function_generation_mapped_fields,
  namespace JSDoc) are recorded `skipped_gap`, not `non_goal`: not individually quote-verified;
  README line 29 ("no generated `.ts`") supports non_goal if the operator elects it.
