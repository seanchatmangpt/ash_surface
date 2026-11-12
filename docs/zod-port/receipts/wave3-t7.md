# Wave 3 Lane T7 Receipt

Standing: PARTIAL

All 9 T7 rows accounted as `skipped_gap` (139 reference tests, 139 loud per-test skips).
Exotic type-facts gap found and fixed (vector, ltree kinds). Gate remains exit 1 only because
other lanes' rows are unaccounted.

## Per-file disposition

| reference file | tests | disposition | ash_surface file |
|---|---|---|---|
| rpc_run_action_ltree | 13 | skipped_gap | ported/rpc/run_action/rpc_run_action_ltree_gap_test.exs |
| rpc_run_action_relationships | 17 | skipped_gap | ..._relationships_gap_test.exs |
| rpc_run_action_sort_filter | 37 | skipped_gap | ..._sort_filter_gap_test.exs |
| rpc_run_action_tuple | 9 | skipped_gap | ..._tuple_gap_test.exs |
| rpc_run_action_union_calculation | 7 | skipped_gap | ..._union_calculation_gap_test.exs |
| rpc_run_action_union_types | 42 | skipped_gap | ..._union_types_gap_test.exs |
| rpc_run_action_untyped_maps | 6 | skipped_gap | ..._untyped_maps_gap_test.exs |
| rpc_run_action_user | 3 | skipped_gap | ..._user_gap_test.exs |
| rpc_run_action_vector | 5 | skipped_gap | ..._vector_gap_test.exs |

Gap: each reference test creates/reads through `Rpc.run_action` (actuation); ash_surface never
actuates (README), same basis and skip tag family as T6. Gap files were generated from the
reference AST (every `describe` kept as a comment, every `test` name preserved).
Capabilities: runtime.module.Rpc.Pipeline, runtime.module.Rpc.ResultProcessor,
runtime.module.Rpc.ValueFormatter. ltree additionally: fixtures drop `AshPostgres.Ltree`.

## Type-facts coverage (implemented under divergence law)

`Ash.Type.Vector` resolved to kind `term` (Ash resolver folds it); ZodType's `vector` kind was
unreachable. `TypeFacts.kind_string/1` now yields `vector` for `Ash.Type.Vector` and `ltree` for
`AshPostgres.Ltree` (module-name match, no ash_postgres dep). Tuple, union, map were already
correct. Test: `test/ash_surface/ported/rpc/run_action/exotic_type_facts_test.exs` (2 tests,
zero skips; not listed in a ledger row).

## Commands

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/run_action` | 0 | 301 tests, 0 failures, 299 skipped (all loud) |
| `mix test mock_discipline + test/ash_surface/projector` | 0 | 93 tests, 0 failures |
| `mix format --check-formatted` (changed files) | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes) | `files=264 ported=8 adapted=101 skipped_gap=56 non_goal=11 unaccounted=88 broken=0 shallow=41` |

## Lib edits

`lib/ash_surface/compiler/type_facts.ex`: two `kind_string/1` clauses (vector, ltree).

## Ledger note

Rows were written with a whole-file JSON rewrite (read-modify-write in one step, not Edit);
another lane's edit in that instant could have been lost. Re-check T7 rows if the gate disagrees.

## Operator decisions

- A non-actuating `Rpc.Pipeline.run_with_result/4` has since landed (F1RP lane); T7 reference
  tests could be re-adapted over caller-supplied results (create via Ash directly) to convert
  gap rows into adapted rows. Not done here.
