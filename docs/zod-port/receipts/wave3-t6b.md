# wave3-t6b

Standing: PARTIAL_ALIVE

Lane T6b: non-actuating RPC pipeline core (`lib/ash_surface/runtime_parity/rpc/`) and upgrade of
the 7 T6 `rpc_run_action_*` gap files (160 reference tests). 153 of 160 reference tests now run
as real surface tests (zero skips); 7 stay loud-skipped. Execution of actions is not ported
(README.md:55, `grep -F "it never actuates"` matches); no `non_goal` was recorded.

## Counts

| reference file | tests | converted | still skipped | row |
|---|---|---|---|---|
| rpc_run_action_aggregates_test.exs | 21 | 21 | 0 | adapted |
| rpc_run_action_calculations_test.exs | 37 | 37 | 0 | adapted |
| rpc_run_action_crud_test.exs | 10 | 10 | 0 | adapted |
| rpc_run_action_embedded_test.exs | 23 | 23 | 0 | adapted |
| rpc_run_action_field_mapping_test.exs | 12 | 11 | 1 | skipped_gap |
| rpc_run_action_generic_actions_test.exs | 42 | 38 | 4 | skipped_gap |
| rpc_run_action_keyword_test.exs | 15 | 13 | 2 | skipped_gap |
| total | 160 | 153 | 7 | 4 adapted, 3 skipped_gap |

Surface files (`test/ash_surface/ported/rpc/run_action/`): `*_surface_test.exs` x7 (154 tests =
153 converted + 1 added search-input-parsing test) and
`*_gap_test.exs` x3 (7 loud skips). The four fully converted gap files were deleted.

Still skipped (reason):
- field_mapping 1: "validation error with missing required argument" (needs Ash changeset
  validation, i.e. execution). Tag `T6b gap: the reference test executes the action through a data layer`.
- keyword 2: the two `Ash.create!`/`Ash.read_one!` direct tests (data-layer execution). Same tag.
- generic_actions 4: assert generated TypeScript text (`InferGetCustomDataListTodoResult`,
  `GetSuggestionFields`, `ListSuggestionsFields`). Tag `T6b gap: asserts generated TypeScript text`.

## Conversion method and deltas

Each reference test calls `Rpc.run_action` (parse -> execute -> process -> format). Here stage 1
(`Pipeline.parse_request/2`) and stages 3-4 (`process_result/2`, `format_output/2`) run for real;
stage 2 is replaced by a hand-built real Ash struct (`struct/2` over the fixture resources, no data
layer, no mocks), via `AshSurface.Ported.Rpc.run/3`. Refusal tests (`unknown_field`,
`requires_field_selection`, `invalid_calculation_args`, ...) run `Rpc.error/2` (parse-time).
Disclosed weakening: tests whose reference assertion is persistence after an executed create/update
assert the fed result only (crud "updates non-nil attribute to nil" renamed accordingly;
aggregates update test; embedded update test). Additions: input-mapping tests assert parsed
`request.input` / `request.load` (field_mapping, calculations, embedded, generic bulk/search).
Details per row are in `parity/test_ledger.json` `changes`.

## lib files created (no existing lib file edited)

`lib/ash_surface/runtime_parity/rpc/`: `pipeline.ex`, `request.ex`, `input_formatter.ex`,
`output_formatter.ex`, `result_processor.ex`, `value_formatter.ex`, `field_extractor.ex`,
`error_builder.ex` (ports of the reference modules; Reactor clause dropped), `field_formatter.ex`,
`support.ex` (manifest handle + entry table + `Custom`/`Helpers`/`ActionIntrospection` shims).
Test support: `test/support/ported/rpc.ex`, `test/support/ported/rpc_fixtures.ex`.
Docs: `docs/zod-port/RPC-PIPELINE-CORE.md`.

## Commands (MIX_BUILD_ROOT=_build-t6b MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test` the 7 run_action files + `*_gap_test.exs` x3 + `no_local_do_test.exs` + `ash_surface_mock_discipline_test.exs` | 0 | 168 tests, 0 failures, 7 skipped |
| `mix test test/ash_surface/ported/rpc/run_action/ test/ash_surface/ported/rpc/rfp test/ash_surface/no_local_do_test.exs test/ash_surface_mock_discipline_test.exs test/ash_surface/runtime_parity` | 0 on the final run (one earlier run showed 1 failure in another lane's file in flight; not reproduced) | 658 tests, 0 failures on the final run, 146 skipped (other lanes' gap files) |
| `mix format --check-formatted` on my lib, support and 7 surface files | 0 | clean (other lanes' surface files are unformatted, not mine) |
| `mix ash_surface.parity.tests` | 1 | `files=264 ported=9 adapted=136 skipped_gap=56 non_goal=16 unaccounted=34 broken=13 shallow=54`; my 7 rows not in BROKEN; 4 adapted rows SHALLOW (warning: pure Elixir, no node/zod); the 13 BROKEN rows are T11/B-lane rows in flight |

`no_local_do_test.exs`: 5 tests, 0 failures, allowlist not widened (no test or lib file edited; the
file's existing uncommitted diff is not mine). `mix compile` of the new lib files: warnings none
from `runtime_parity/rpc`. No `Process.sleep`, no mocks (grep over my files: zero matches).
`_build-t6b` deleted.

## Operator decisions

- D18 (README.md:55 reading, `docs/jira/v26.11.11/OPERATOR-DECISIONS.md` D7/D18): the pipeline core
  was built, so the T6 rows are not `non_goal`; the 7 residual skips are execution-needing (3) or
  TypeScript-text (4). Whether execution-only tests become `non_goal` after D7's tightened README
  sentence is the operator's call.
- The 4 TypeScript-text tests need an IR/Zod adaptation (outside this pipeline).

## Falsifiers

A converted test passing while the pipeline is wrong would require the fed struct to encode the
expected output; refusal tests and `request.input`/`request.load` assertions do not. A stale
`Support.install/2` entry table (persistent_term is global) would surface as `action_not_found`.

## See Also

`RPC-PIPELINE-CORE.md` · `wave3-t6.md` · `wave3-t5.md` · `TEST-PORT-CONTRACT.md`
