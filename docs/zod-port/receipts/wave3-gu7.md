# Wave 3 Lane GU-T7 Receipt

Standing: PARTIAL

Converts T7 loud-skip gap tests to real tests over the non-actuating pipeline (caller-built real
Ash structs, no data layer, no mocks, no Process.sleep). 139 reference tests: 101 converted,
38 still skipped (loud, accurate reasons). Gate still exits 1 only from other lanes' BROKEN rows.

## Per-file disposition

| reference file | tests | converted | still skipped | ledger row |
|---|---|---|---|---|
| rpc_run_action_vector | 5 | 5 | 0 | adapted |
| rpc_run_action_tuple | 9 | 9 | 0 | adapted |
| rpc_run_action_union_calculation | 7 | 7 | 0 | adapted |
| rpc_run_action_union_types | 42 | 42 | 0 | adapted |
| rpc_run_action_relationships | 17 | 17 | 0 | adapted |
| rpc_run_action_ltree | 13 | 12 | 1 | skipped_gap (partial) |
| rpc_run_action_sort_filter | 37 | 6 | 31 | skipped_gap (partial) |
| rpc_run_action_untyped_maps | 6 | 2 | 4 | skipped_gap (partial) |
| rpc_run_action_user | 3 | 1 | 2 | skipped_gap (partial) |
| total | 139 | 101 | 38 | 5 adapted, 4 skipped_gap |

Surface files (all in `test/ash_surface/ported/rpc/run_action/`, zero skips): `*_vector_surface`
(5: 4 result-shaping + dimensions rejection via a real `Ash.Changeset.for_create` rendered by
`Pipeline.error_response`, no `Ash.create`), `*_tuple_surface` (9), `*_union_calculation_surface`
(7), `*_union_types_surface` (42), `*_relationships_surface` (17), `*_ltree_surface` (12),
`*_sort_filter_surface` (6 converted + 2 added request-parse tests that are not reference tests),
`*_untyped_maps_surface` (2 converted + 1 added), `*_user_surface` (1). Counts above exclude the
3 added tests. Gap files deleted when emptied: vector, tuple, union_calculation, union_types,
relationships.

## Still skipped (38) and why

- ltree (1): `strict hierarchy rejects string input` is `AshPostgres.Ltree`'s own escape? cast error;
  ash_postgres is not a dependency, the in-test fixture type is not the real type.
- sort_filter (31): assertion is order/membership/pagination computed by the data layer (sort
  string/list, isNil/eq/aggregate filters, aggregate sorts, offset pages); no read executes.
- untyped_maps (4): the `update_with_untyped_data` merge is the action change function over
  persisted `custom_data` (execution).
- user (2): pascal_case/snake_case set the global formatter env; the pipeline formatter is fixed
  camelCase (`RuntimeParity.Rpc.Support`).

## Private ltree fixture

T5 dropped the ltree attributes. `rpc_run_action_ltree_surface_test.exs` defines a real `Ash.Type`
module named `AshPostgres.Ltree` (matched by name by TypeFacts' ltree clause; list-of-labels value),
resources `LtreeFixture.User/Todo` + domain, builds a private manifest, and installs a private
entry table into the global `Rpc.Support` in a non-async module with `Ported.Rpc.install/0`
re-asserted in `on_exit`. The module name `AshPostgres.Ltree` will collide if ash_postgres is ever
added as a dependency (compile redefinition); rename or drop then.

## Commands

| command | rc | result |
|---|---|---|
| `MIX_BUILD_ROOT=_build-gu7 mix test test/ash_surface/ported/rpc/run_action test/ash_surface_mock_discipline_test.exs` | 0 | 307 tests, 0 failures, 45 skipped (38 are this lane's gap files; the rest other T6/T7 lanes) |
| `mix format --check-formatted test/ash_surface/ported/rpc/run_action/*.exs` | 0 | clean |
| grep Process.sleep/Mox/mockall/:meck over run_action surface + gap tests | 1 (no match) | zero matches |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes) | `files=264 ported=9 adapted=181 skipped_gap=41 non_goal=19 unaccounted=0 broken=14 shallow=81`; 0 of the 14 BROKEN rows are T7 (they are rpc/a T8 rows) |
| `python3 -c json.load(parity/test_ledger.json)` | 0 | valid |

## Lib edits

None.

## Ledger

9 T7 rows edited with targeted Edits (re-read before each). Five became `adapted`; four stay
`skipped_gap` with `ash_surface_tests` listing only the gap file (the gate requires each listed
file to contain the skip_tag) and the surface file named in `changes`. New skip tags carry the
`GU7 gap:` prefix and match the gap files.

## Operator decisions

None. The 38 remaining skips need either a data layer (README: it never actuates), the real
AshPostgres.Ltree, or a configurable pipeline formatter.
