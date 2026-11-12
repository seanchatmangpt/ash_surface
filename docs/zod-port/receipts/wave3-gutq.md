# Wave 3 Lane GU-TQ Receipt

Standing: PASS

Scope: typed_query fixture plus non-actuating runner; convert the 12 loud skips of
`run_typed_query_gap_test.exs` (reference `~/ash_typescript/test/ash_typescript/rpc/run_typed_query_test.exs`).
README "it never actuates" kept: no `Ash.read` in lib, `no_local_do` allowlist untouched.

## Converted vs still skipped

Converted 12 of 12 (plus the T11-ported `typed_query_not_found` case: 13 of 13). Still skipped: 0.
The gap file was deleted; the cases live in
`test/ash_surface/ported/rpc/d/run_typed_query_runner_surface_test.exs` (+1 extra nested-field case
and 1 unknown-name case). Filter / sort / page / input are asserted as the parsed `Request` the action
would receive; the caller supplies the already filtered/sorted/paged result (real Ash structs,
`Ash.Page.Offset` for paged cases). Row selection by an Ash read is not exercised (no data layer
read). `otp_app` has no counterpart (lookup is manifest/entry-table keyed). Parse facts observed:
sort stays the client string, input values stay uncast (Ash casts later).

## lib files

- NEW `lib/ash_surface/runtime_parity/rpc/typed_query.ex`: `lookup/2`, `client_fields/1`, `parse/3`,
  `run/4`. Resolves the typed query via `AshSurface.Resource.Projections.typed_query/2`, finds the
  entry for the same resource/action, expands declared fields (atoms, keyword nesting, `%{calc: %{args,
  fields}}`) to camelCase client fields, runs `Pipeline.parse_request` / `process_result` /
  `format_output`. `pipeline.ex` not edited.

## Test files

- NEW `test/support/ported/typed_query_fixture.ex`: private `TqTodo` (typed_query
  `list_todos_user_page`), `TqComment`, `TqDomain`, `TypedQueryRpc` (own manifest, own entry table).
- NEW `run_typed_query_runner_surface_test.exs`; DELETED `run_typed_query_gap_test.exs`.
- `parity/test_ledger.json`: run_typed_query row `skipped_gap` -> `adapted`, `changes` set, gap/skip_tag
  cleared (targeted edit, JSON re-validated).

## Commands (MIX_BUILD_ROOT=_build-gutq MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test` runner_surface + run_typed_query_surface + mock_discipline + no_local_do_bang_court | 0 | 20 tests, 0 failures |
| `mix test test/ash_surface/ported/rpc/d` (run mid-wave) | 2 | 277 tests, 7 failures, 46 skipped; failures in other lanes' files (e.g. `sort_and_filter_types_ir_surface_test.exs`); a re-run printed no failing tests |
| `mix format --check-formatted` on the 3 new files | 0 | clean |

grep for `Process.sleep|Mox|mock(` over the new files: zero matches. `_build-gutq` deleted after the last run.
