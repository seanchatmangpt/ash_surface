# wave3-gu10

Standing: PARTIAL

Lane GU-T10: convert loud-skip gap tests of the T10 partition (`test/ash_surface/ported/rpc/c/`)
now that a non-actuating RPC pipeline exists. Of the 235 skips recorded in `wave3-t10.md`,
119 are converted to real tests with zero skips; 116 remain loud skips with corrected reasons.
No `lib/` edits. No README edit; no row marked `non_goal`.

## Converted vs still-skipped

| reference file | converted (test file) | still skipped (gap file) and reason |
|---|---|---|
| nested_query_opts_test | 28/28 (nested_query_opts_surface_test.exs) | 0 (old reason stale: the envelope already exists in RuntimeParity.RequestedFields) |
| nested_query_opts_pipeline_test | 13/14 (nested_query_opts_pipeline_surface_test.exs) | 1: 014 multitenant paging within a tenant needs a data layer |
| rpc_get_actions_test | 42/49 (rpc_get_actions_surface_test.exs 39, rpc_get_actions_global_config_surface_test.exs 3) | 7: 029-032, 047-049 assert generated TypeScript text |
| rpc_field_argument_mapping_test | 9/9 (rpc_field_argument_mapping_surface_test.exs) | 0 |
| private_arguments_test | 15/15 (private_arguments_surface_test.exs 4, private_arguments_ir_surface_test.exs 11) | 0 (TS-text tests adapted onto the compiled IR: schema.input, schema.zod, schema.validation_error) |
| rpc_composite_primary_key_test | 4/9 (rpc_composite_primary_key_surface_test.exs) | 5: 001-005 generated TypeScript text |
| pagination_advanced_test | 4/19 (pagination_advanced_surface_test.exs) | 15: data-layer limit/offset/sort/filter semantics, dataset size, timing, cross-request consistency |
| optional_tenant_for_all_actions_test | 2/9 (optional_tenant_pipeline_surface_test.exs) | 7: 001-007 generated TypeScript text |
| output_field_formatting_test | 2/2 (output_field_formatting_surface_test.exs) | 0 |
| nested_map_field_formatting_test | 0/4 | 4: generated TypeScript text, no Zod/IR adaptation written |
| restricted_schema_codegen_test | 0/15 | 15: generated TypeScript text, no Zod/IR adaptation written |
| rpc_function_generation_mapped_fields_test | 0/22 | 22: generated TypeScript text, no Zod/IR adaptation written |
| namespace_test (gap half) | 0/40 | 40: JSDoc / multi-file / custom-code text; 006 needs the reference domain rpc entries |

Totals: 235 skips before; 119 converted; 116 remain (40+4+1+7+15+15+5+22+7). TypeScript-text
skips were not marked `non_goal` (README line 29 supports it only by operator election).

Deltas that change what a converted test asserts (all recorded in the ledger `changes`):

- Execution is not ported. Where the reference stored rows and read them back, the caller builds
  the real Ash struct/page/error and the pipeline shapes it, so assertions on "which stored row
  matched" become assertions on the parsed request (`request.get_by`, `request.identity`,
  `request.input`) plus the shaped record. A test that would pass for any record is a
  data-layer test and stayed skipped.
- Not-found cases feed a caller-built `Ash.Error.Query.NotFound`; the envelope type is asserted.
- Global `not_found_error?` (044-046) becomes the compile-time IR fact
  (`ResourceFacts.not_found_error?`) on real inline Spark resources with `Application` env
  restored per test.
- Composite identity with a missing key (008) uses `Pipeline.resolve_identity/1` (landed by GU-T11).
- The field-mapping "validation errors" test asserts the envelope for a caller-built Required
  error; the envelope reports `address_line_1`-style attribute names unmapped (observed, not
  asserted by the reference).

## Commands and exits

Build root `_build-gu10` (deleted at the end), `MIX_ENV=test`.

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/c` | 0 | 269 tests, 0 failures, 116 skipped (153 run) |
| `mix test test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `mix format --check-formatted test/ash_surface/ported/rpc/c/*.exs` | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 | `files=264 ported=9 adapted=172 skipped_gap=29 non_goal=19 unaccounted=17 broken=18 shallow=75` |

The gate exits 1 on rows owned by other lanes (T8 `rpc/a/*_gap`, GU7 `run_action/*`,
17 unaccounted); `mix ash_surface.parity.tests` lists zero BROKEN rows under `rpc/c`. The gate
requires every file listed on a `skipped_gap` row to contain the row's skip tag, so mixed rows
(pipeline, get_actions, composite, pagination, optional_tenant) list only the gap file in
`ash_surface_tests` and name the converted surface files in `changes`.
Grep over `rpc/c`: zero `Process.sleep`, `Mock`, `mock(`.

## Ledger rows (small targeted Edits)

adapted (fully converted): nested_query_opts, output_field_formatting, rpc_field_argument_mapping,
private_arguments. skipped_gap (remaining parts only): nested_query_opts_pipeline (014),
rpc_get_actions (7), rpc_composite_primary_key (5), pagination_advanced (15),
optional_tenant_for_all_actions (7), nested_map_field_formatting (gap text corrected).
Deleted gap files: nested_query_opts, output_field_formatting, rpc_field_argument_mapping,
private_arguments.

## Operator decisions

- README line 29 `non_goal` for the TypeScript-text remainder: 100 of the 116 skips (namespace
  40, function_generation 22, restricted_schema 15, nested_map 4, optional_tenant 7,
  composite 5, get_actions 7). The other 16 are data-layer dependent (pagination 15, pipeline
  014 1). Not marked.
- A Zod/IR adaptation like the private-arguments one may exist for restricted_schema_codegen and
  rpc_function_generation_mapped_fields (input types with mapped names); not attempted.

## Falsifiers

- A converted pipeline test passes for any caller-built record: the 7 get_actions "lookup" tests
  pin `request.get_by` alongside the record, but record identity is the caller's.
- `t2.exs` (another lane's support file) was mid-edit and uncompilable during this lane; the
  global-config test carries its own inline compile helper instead of importing it.

## See Also

`wave3-t10.md` · `wave3-t6b.md` · `../RPC-PIPELINE-CORE.md` · `../TEST-PORT-CONTRACT.md`
