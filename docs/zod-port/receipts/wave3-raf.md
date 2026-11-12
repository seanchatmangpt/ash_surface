# wave3-raf

Standing: PASS

Lane RAF. Repairs thin single-mutation coverage reported in
`docs/zod-port/receipts/wave3-skmute2.md` (repair requests, last bullet) plus the
`runtime_source_of_truth_guard_test.exs` design question. Lib code was not edited.

## Files touched (tests only)

- `test/ash_surface/ported/rpc/d/run_typed_query_surface_test.exs` (+3 tests)
- `test/ash_surface/ported/rpc/a/error_redaction_surface_test.exs` (+4 tests)
- `test/ash_surface/ported/rpc/d/struct_argument_test.exs` (+6 tests)
- `test/ash_surface/ported/ts/root/entry_points_test.exs` (+5 tests)
- `test/ash_surface/ported/ts/root/custom_zod_overrides_test.exs` (+4 tests)
- NEW `test/ash_surface/ported/rpc/d/runtime_source_of_truth_ast_guard_test.exs` (13 tests)

## Shim-court (scratch `/tmp/raf`, build root `_build-scratch`, node_modules and deps symlinked)

Scratch = explicit-path tar of the live repo (lib test mix.* config parity priv scripts
conformance ontology.ttl README.md ...). Each row: BEFORE green, SHIM red, RESTORE sha256
byte-equal to baseline (script `/tmp/raf_court.py`, output `/tmp/raf_court.out`).
Format: tests/failures.

| id | lib mutation | file | before | shim | restore |
|---|---|---|---|---|---|
| TQ1 | typed_query.ex miss carries :x | run_typed_query | 5/0 | 5/3 | eq |
| TQ2 | error_builder vars name literal | run_typed_query | 5/0 | 5/2 | eq |
| TQ3 | error_builder short_message | run_typed_query | 5/0 | 5/1 | eq |
| TQ4 | lookup resources forced empty | run_typed_query | 5/0 | 5/1 | eq |
| ER1 | errors.ex generic message text | error_redaction | 10/0 | 10/5 | eq |
| ER2 | errors.ex details.error_id literal | error_redaction | 10/0 | 10/7 | eq |
| ER3 | errors.ex exception exposed w/o show_raised | error_redaction | 10/0 | 10/1 | eq |
| ER4 | errors.ex NotFound short message | error_redaction | 10/0 | 10/1 | eq |
| SA1 | type_facts resource kind resource? false | struct_argument | 15/0 | 15/2 | eq |
| SA2 | type_facts struct resource? true | struct_argument | 15/0 | 15/1 | eq |
| SA3 | input_formatter unknown key value nil | struct_argument | 15/0 | 15/1 | eq |
| SA4 | type_facts instance_of literal | struct_argument | 15/0 | 15/2 | eq |
| EP1 | zod_type max bound emits min | entry_points | 9/0 | 9/3 | eq |
| EP2 | zod_type max_length emits min | entry_points | 9/0 | 9/2 | eq |
| EP3 | zod_type regex dropped | entry_points | 9/0 | 9/2 | eq |
| EP4 | zod_type integer without .int() | entry_points | 9/0 | 9/3 | eq |
| CZ1 | zod_type overrides lookup disabled | custom_zod | 11/0 | 11/5 | eq |
| CZ2 | zod_type override emits z.any() | custom_zod | 11/0 | 11/5 | eq |
| CZ3 | zod_type integer without .int() | custom_zod | 11/0 | 11/1 | eq |
| AG1 | field_selector grouped-alias `Info.zz()` call | ast_guard | 13/0 | 13/1 | eq |
| AG2 | field_selector `Ash.read!` call | ast_guard | 13/0 | 13/2 | eq |
| AG3 | field_selector `Map.get(.., :show_metadata)` | ast_guard | 13/0 | 13/1 | eq |

Post-court `diff -q` of the mutated scratch lib files against live: no differences.

## runtime_source_of_truth_guard design question

The string-grep guard flips only on a literal token: it misses an aliased call
(`alias AshSurface.{Info}` then `Info.x()`, AG1) and cannot see actuation. It is a guard, so
behaviour mutations not flipping it is expected. Replacement is small (about 60 lines of
`Code.string_to_quoted` + alias resolution), so it was implemented as an additional file; the
old test is kept. The new guard: resolves aliases (plain, `as:`, grouped), forbids calls to
`AshSurface.Resource.Info`/`AshSurface.Info` and `Map.get` on retired rpc_action keys in the
7 guarded files, forbids `Ash.read/create/update/destroy/bulk_*` across every file under
`lib/ash_surface/runtime_parity/**`, and includes 5 non-vacuity self-tests (known-bad source
flips it; comments, strings and `Ash.Resource.Info` do not). Verdict: replace-in-effect, keep
both. The 7-file list still omits pipeline.ex and result_processor.ex from the module-call
law (unchanged; they are covered by the non-actuating law only).

## Gates (live tree, `MIX_BUILD_ROOT=_build-raf`, rc un-piped)

- `mix test` on the 7 files (5 repaired, AST guard, old guard): rc=0, 70 tests, 0 failures.
- `mix ash_surface.parity.tests`: rc=0, `files=264 ported=9 adapted=203 skipped_gap=33
  non_goal=19 unaccounted=0 broken=0 shallow=90`.

Not run: full `mix test` suite, `--check-inventory`. UNVERIFIED.
