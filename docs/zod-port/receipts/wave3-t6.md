# wave3-t6

Standing: PARTIAL

Lane T6 (`rpc/rpc_run_action_*` aggregates .. keyword, 7 files, 160 tests). All 7 rows are
`skipped_gap`; zero tests ported. Reason: ash_surface has no in-process `Rpc.run_action`
pipeline (`AshTypescript.Rpc.Pipeline` 1575 lines, `ResultProcessor`, `ValueFormatter`,
`InputFormatter`/`OutputFormatter`, and the domain `typescript_rpc` action table the tests call
by name, e.g. `create_user`, `list_todos`). T5's `RuntimeParity.RequestedFieldsProcessor` covers
field selection only; execution in ash_surface is JS runtime -> transport -> Ash consequence.
Implementing the pipeline was judged infeasible within this lane.

## Per-file disposition

| reference file | tests | disposition | ash_surface file |
|---|---|---|---|
| rpc_run_action_aggregates_test.exs | 21 | skipped_gap | `ported/rpc/run_action/rpc_run_action_aggregates_gap_test.exs` |
| rpc_run_action_calculations_test.exs | 37 | skipped_gap | `..._calculations_gap_test.exs` |
| rpc_run_action_crud_test.exs | 10 | skipped_gap | `..._crud_gap_test.exs` |
| rpc_run_action_embedded_test.exs | 23 | skipped_gap | `..._embedded_gap_test.exs` |
| rpc_run_action_field_mapping_test.exs | 12 | skipped_gap | `..._field_mapping_gap_test.exs` |
| rpc_run_action_generic_actions_test.exs | 42 | skipped_gap | `..._generic_actions_gap_test.exs` |
| rpc_run_action_keyword_test.exs | 15 | skipped_gap | `..._keyword_gap_test.exs` |

Capabilities on every row: `runtime.module.Rpc.Pipeline`, `runtime.module.Rpc.ResultProcessor`,
`runtime.module.Rpc.ValueFormatter`. Each reference `test` (extracted by AST, describe structure
preserved) has a counterpart with `@tag skip: "T6 gap: ..."` (the row's `skip_tag` is a verbatim
prefix of that text). Skip bodies are `:ok` placeholders, not behavior assertions.

## Commands

| command | rc | result |
|---|---|---|
| `elixir /tmp/t6gen.exs` (generator, not committed) | 0 | 7 files |
| `mix format --check-formatted` on the 7 files | 0 | clean |
| `mix test` the 7 gap files (MIX_BUILD_ROOT=_build-t6) | 0 | 160 tests, 0 failures, 160 skipped |
| `mix ash_surface.parity.tests --summary` (shared tree, other lanes in flight) | 1 | `files=264 ported=0 adapted=76 skipped_gap=26 non_goal=10 unaccounted=152 broken=0 shallow=29` |

My 7 rows validate (no `broken`). Gate exit 1 is other lanes' unaccounted rows. A run of the whole
`run_action/` dir showed 1 failure in T7's `exotic_type_facts_test.exs` (vector kind
`term` != `vector`), not mine.

## lib edits

None. Ledger: 7 T6 rows rewritten in `parity/test_ledger.json` (line-targeted, one-row-per-line
format preserved).

## Operator decisions / follow-up

- Port the run_action pipeline (Pipeline, ResultProcessor, ValueFormatter, Input/OutputFormatter)
  into `AshSurface.RuntimeParity` plus an entrypoint table over the T5 fixtures, then convert
  these gap files to real tests. This unblocks T7/T8/T9 gap files too.
- `_build-t6` deleted.
