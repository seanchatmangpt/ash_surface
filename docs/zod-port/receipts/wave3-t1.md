# Wave 3 Lane T1 Receipt

Standing: PARTIAL

All 15 T1 reference files are accounted (9 ported/adapted rows backed by runnable tests, 0 broken);
the formatter-driven artifact-key tests and a few capability-missing tests are loud skips in
unlisted `*_gap_test.exs` files and recorded in each row's `changes`. Reference
`~/ash_typescript` HEAD `5d6e80aec1afcbabaf0831768c210fecd81bd869`. Build root
`_build-t1` (deleted).

## Per-file dispositions (ledger rows, owner_lane T1)

| reference file | disposition | ash_surface tests | skips (gap file) |
|---|---|---|---|
| aggregate_field_formatting_test | adapted | ported/top/aggregate_field_formatting_test.exs | 2 (formatter_artifact_gap) |
| calculation_field_formatting_test | adapted | ported/top/calculation_field_formatting_test.exs | 1 |
| codegen_check_test | adapted | ported/top/codegen_check_test.exs | 8 (codegen_check_gap: 4 manifest, 4 multi-file) |
| custom_types_test | adapted | ported/top/custom_types_test.exs | 0 |
| embedded_generic_action_return_test | adapted | ported/top/embedded_generic_action_return_test.exs | 4 (embedded_generic_action_return_gap) |
| embedded_resource_field_formatting_test | adapted | ported/top/embedded_resource_field_formatting_test.exs | 2 |
| empty_manifest_codegen_test | adapted | ported/top/empty_manifest_codegen_test.exs | 0 |
| error_formatter_test | ported | ported/top/error_formatter_test.exs | 0 |
| field_formatter_atom_safety_test | adapted | ported/top/field_formatter_atom_safety_test.exs | 0 |
| field_formatter_struct_clause_test | adapted | ported/top/field_formatter_struct_clause_test.exs | 0 |
| field_formatting_comprehensive_test | adapted | ported/top/field_formatting_comprehensive_test.exs | 8 (7 codegen TS text + 1 reference-skipped) |
| filter_formatting_test | adapted | ported/top/filter_formatting_test.exs | 2 |
| filter_mapped_fields_test | adapted | ported/top/filter_mapped_fields_test.exs | 4 |
| non_field_calculation_test | adapted | ported/top/non_field_calculation_test.exs | 0 |
| relationship_field_formatting_test | adapted | ported/top/relationship_field_formatting_test.exs | 1 |

Per-test mapping (reference test -> counterpart or skip) is in each row's `changes` and in the
test file moduledocs. Shared helper: `test/ash_surface/ported/top/support/t1.exs` (real compiled
`AshSurface.Ported.Domain` artifact, cached; real node+zod acceptance).

## Gate output (`mix ash_surface.parity.tests --summary`, re-run after my last ledger edit)

`parity-tests: files=264 ported=9 adapted=132 skipped_gap=73 non_goal=16 unaccounted=34
broken=0 shallow=50` (exit 1: other lanes' rows still unaccounted; counts include other lanes'
concurrent edits). My 15 rows: ported=1, adapted=14, broken=0. SHALLOW warnings on my rows
(warning only, Elixir runtime-pipeline ports with no node/zod reference): codegen_check,
error_formatter, field_formatter_atom_safety, field_formatter_struct_clause,
field_formatting_comprehensive.

## Commands and results (MIX_BUILD_ROOT=_build-t1 MIX_ENV=test)

| command | result |
|---|---|
| `mix test` 18 T1 files + `codegen_task_test.exs` + `ash_surface_mock_discipline_test.exs` | 197 tests, 0 failures, 32 skipped (all 32 are the loud gap skips: 8 + 4 + 20) |
| `mix ash_surface.parity.tests --summary` | counts above, broken=0 |
| `mix format` on all T1 files and the two edited lib files | clean |
| grep `Process.sleep`/mock tokens over T1 test files | zero matches |

(Exit codes were observed from the ExUnit summary line; the shell pipe discarded `mix`'s own rc.)

## lib / shared-test edits (disclosed)

1. `lib/mix/tasks/ash_surface.codegen.ex`: `regenerate?` is now `opts[:dev] == true and
   Config.always_regenerate()` (was `or`), moduledoc updated. Reference semantics: `--check`
   alone always gates; only `--dev --check` with `always_regenerate: true` regenerates.
2. `test/ash_surface/codegen_task_test.exs` (another lane's file): the two tests that pinned the
   old bypass ("--dev bypasses --check", "always_regenerate bypasses --check") replaced by three
   tests pinning the new law (dev-only raises; dev+always regenerates; check+always raises).
3. `lib/ash_surface/field_name.ex`: added `format_fields/2` (shallow key formatting, port of
   `FieldFormatter.format_fields/2`); `parse_input/2` now raises `ArgumentError "Unsupported
   formatter: ..."` for an unsupported built-in formatter (was silently camel_case).

No other lib file touched. A concurrent lane's syntax-broken `rpc/pipeline.ex` blocked compile for
roughly 10 minutes mid-lane; not edited, waited out.

## Operator decisions / registered gaps (no README quote supports non_goal)

- Artifact keys do not follow `output_field_formatter` or resource `field_names` (the JS
  artifact emits Ash names verbatim; Task filter enumerates `archived?`, not `isArchived`).
  Affects 14 reference tests (loud skips); same debt as w3-15 "FieldName wiring into the
  compiler". Capabilities: `codegen.module.Codegen.SchemaFormatter`,
  `config.key.output_field_formatter`.
- No response schema for generic-action return types (IR `response_zod` nil,
  `no_record_schema`); embedded resources reachable only via a return type are not projected
  (4 skips).
- No per-embedded-resource filter schema, no relationship-typed (`related`) filter terms in the
  read filter (4 skips).
- No JSON/Markdown manifest emission and no multi-file namespace output in codegen (8 skips;
  `manifest_file`, `json_manifest_file`, `enable_namespace_files`, `namespace_output_dir` are
  accessor-only).
- String fields expose `contains/starts_with/ends_with` but not `gt/lt` (reference
  `greaterThan?: string`): pinned in filter tests, not implemented.
- Custom `{m, f}` formatters have no hand-written inverse in ash_surface (inverse derived from
  the admitted set): the reference's `parse_input_with_prefix` tests are replaced by
  derived-inverse tests (witnessed, arguably better).
- `Rpc.Support.output_field_formatter/0` is hard-coded `:camel_case` (T6-owned module).

## Verification ladder / standing

Narrow (per-file runs) -> grouped run of all 18 T1 files + mock-discipline court + codegen task
tests (above) -> parity gate summary. Standing PARTIAL: every T1 file is accounted and runs,
but the formatter-artifact, generic-return, embedded-filter, manifest and namespace
capabilities are not implemented. Falsifiers: any T1 row whose listed test file gains a skip
(gate breaks it); `codegen_task_test.exs` failing under the new `--check` law.

## See Also

`TEST-PORT-CONTRACT.md` · `TEST-PORT-PLAN.md` · `wave3-t0.md`
