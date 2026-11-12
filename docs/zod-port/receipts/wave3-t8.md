# wave3-t8

Standing: PARTIAL

Lane T8 (`rpc/` calculation_field_selection .. input_parsing_stress, 21 files). All 21 rows
accounted, none `unaccounted`/`broken`: 6 adapted-and-running, 13 `skipped_gap`, 2 `non_goal`.
Gaps are dominated by the missing in-process `run_action`/`Pipeline`/domain `typescript_rpc`
surface (same cause as T6/T11); a non-actuating `RuntimeParity.Rpc.*` pipeline was appearing
in the tree from another lane during this session and was not yet a stable test entry.

## Per-file disposition

| reference file | disposition | ash_surface file(s) (`test/ash_surface/ported/rpc/a/`) |
|---|---|---|
| calculation_field_selection | adapted (9 tests) | calculation_field_selection_test.exs |
| codegen_determinism | adapted (1) | codegen_determinism_test.exs |
| custom_type_schema | adapted (11) | custom_type_schema_test.exs |
| embedded_argument | adapted (8) | embedded_argument_test.exs |
| forbidden_field_redaction | adapted (2) | forbidden_field_redaction_test.exs |
| channel_lifecycle_hooks_config | adapted (20) | channel_lifecycle_hooks_config_test.exs |
| channel_lifecycle_hooks_codegen | non_goal (22) | README quote (no generated .ts) |
| endpoint_configuration | non_goal (8) | README quote (no generated .ts) |
| calculations, comprehensive_integration, embedded_argument_rpc, error_redaction, error_scenarios, first_aggregate_complex_types, input_field_formatting, input_parsing_stress, entrypoint_resolution | skipped_gap (10+22+7+2+10+3+3+28+2 = 87 loud skips) | `<name>_gap_test.exs`; caps runtime.module.Rpc{,.Pipeline,.ResultProcessor,.ValueFormatter} |
| enable_filter, enable_sort, error_handling, error_protocol | skipped_gap (15+18+33+32 = 98 loud skips) | `<name>_gap_test.exs`; caps runtime.module.Rpc.{Pipeline,ErrorBuilder,Errors}, dsl.rpc.entity.rpc_action |

Per-test notes: gap files carry one `@tag skip:` test per reference test (AST-extracted,
describe structure kept; bodies are `:ok` placeholders). Adapted deltas per row are in each
ledger `changes` (custom_type_schema: valibot + import tests dropped, storage-derived tests
re-pinned to ash_surface's refusal; codegen_determinism: 5 hashes not 10, manifest generation
cost).

## Commands (MIX_BUILD_ROOT=_build-t8, MIX_ENV=test; build root deleted)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/a` | 0 | 236 tests, 0 failures, 185 skipped (51 running: 9+1+11+8+2+20 = 51; 185 = 87+98 loud skips) |
| `mix test test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `mix format --check-formatted` (config.ex + a/*.exs) | 0 | clean |
| `mix ash_surface.parity.tests --summary` (shared tree) | 1 | `files=264 ported=9 adapted=132 skipped_gap=73 non_goal=16 unaccounted=34 broken=0 shallow=50` (exit 1 = other lanes' unaccounted rows; my 21 rows not broken; calculation_field_selection / channel_lifecycle_hooks_config / forbidden_field_redaction SHALLOW warnings only: no node/zod/renderer reference, same as T5 rfp rows) |

## lib edits

`lib/ash_surface/config.ex`: added `rpc_action_channel_hooks_enabled?/0` and
`rpc_validation_channel_hooks_enabled?/0` (divergence-law implementation of the reference's
`AshTypescript.Rpc.rpc_*_channel_hooks_enabled?`), single targeted Edit after re-read.

## Operator decisions

1. non_goal rows `channel_lifecycle_hooks_codegen`, `endpoint_configuration`: quote is the
   README sentence "no generated `.ts`, no `.d.ts`, no `tsc` build step" (verified by grep -F);
   confirm that is acceptable for Elixir tests of TS-emitting hooks/endpoints.
2. Whether to build the in-process pipeline/domain rpc DSL surface: would unlock 13 gap rows
   (185 skips). `error_handling`/`error_protocol`/`enable_*` could partly port against the
   in-flight `RuntimeParity.Rpc.{Pipeline,ErrorBuilder}` once it has a stable test entry.
3. ash_surface refuses (not guesses) schemas for hand-rolled custom types lacking a
   `zod_mapping_overrides` entry; the reference derives from `storage_type/1`.

## See Also

`TEST-PORT-CONTRACT.md` · `TEST-PORT-PLAN.md`
