# Wave 3 Lane GU-T11 Receipt

Standing: PARTIAL

Scope: convert the loud-skip gap tests of lane T11 (`test/ash_surface/ported/rpc/d/*_gap_test.exs`,
210 skips on the wave3-t11 receipt, plus 4 in `struct_argument_gap_test.exs`) into real tests
using the non-actuating RPC pipeline (`lib/ash_surface/runtime_parity/rpc/`, `Rpc.parse/run/error`
in `test/support/ported/rpc.ex`). Reference `~/ash_typescript`; README "it never actuates" kept.

## Counts (re-read from the files at write time)

Before: 222 skipped in `ported/rpc/d` (`mix test` of the dir). After: 58 skipped, 0 failures.
Converted 164 of 222 skips; 58 remain loud skips with corrected reasons.

| reference file | converted | still skipped | reason for the remainder |
|---|---|---|---|
| rpc_integration (19) | 19 | 0 | - |
| rpc_pipeline (35) | 35 | 0 | - |
| rpc_metadata (35) | 35 | 0 | - |
| rpc_optional_fields (8) | 8 | 0 | - |
| rpc_validate_action (12) | 12 | 0 | - |
| rpc_validation_error_structure (14) | 14 | 0 | - |
| rpc_identities (21) | 17 | 4 | TS-text codegen regexes (README: no generated .ts) |
| rpc_mapped_identity_fields (4) | 2 | 2 | TS-text codegen regexes |
| struct_argument_integration (8) | 5 | 3 | TS-text (UserInputSchema) |
| struct_argument (gap file, 4) | 1 | 3 | 2 TS-text, 1 no `find_struct_argument_resources` module |
| sort_and_filter_types (47) | 15 | 32 | TS SortField/FilterField text and generators |
| run_typed_query (13) | 1 | 12 | no typed_query fixture, no typed-query lookup/runner in Pipeline; data assertions need an Ash read |
| rpc_validate_action_read_action (2) | 0 | 2 | needs execution: `Ash.Get` with the rpc action's read_action against a data layer |

Per-test notes for dropped assertions (post-destroy `Ash.get`, "record untouched" follow-up read,
stored not-found) are in each ledger row's `changes`.

## Moved files (gap -> surface, zero skips)

`rpc_integration_surface_test.exs`, `rpc_pipeline_surface_test.exs`, `rpc_metadata_surface_test.exs`,
`rpc_optional_fields_surface_test.exs`, `rpc_validate_action_surface_test.exs`,
`rpc_validation_error_structure_surface_test.exs`, `rpc_identities_surface_test.exs`,
`rpc_mapped_identity_fields_surface_test.exs`, `struct_argument_integration_surface_test.exs`,
`sort_and_filter_types_surface_test.exs`, `run_typed_query_surface_test.exs`; the InputFormatter test was
added to `struct_argument_test.exs`. Gap files kept (leftover skips only): rpc_identities,
rpc_mapped_identity_fields, rpc_validate_action_read_action, run_typed_query, sort_and_filter_types,
struct_argument, struct_argument_integration. Gap files deleted (fully converted): rpc_integration,
rpc_metadata, rpc_optional_fields, rpc_pipeline, rpc_validate_action, rpc_validation_error_structure.

## lib edit (disclosed; file owned by lane T6b)

`lib/ash_surface/runtime_parity/rpc/pipeline.ex`: added public `resolve_identity/1` plus private
helpers (`build_identity_filter`, `expected_identity_keys`, `primary_key_filter`, `parse_identity_input`,
`validate_scalar_identity_filter`, `named_identity_filter`), inserted after `scalar_identity_value?/1`.
It is the pure half of the reference `maybe_apply_identity_filter/4` (no query built, no Ash call beyond
manifest lookups): returns the equality filter or typed `missing_identity` / `invalid_identity` refusals.
Defect proved: the pipeline carried `identity` raw with no resolution, so the 15+ identity tests had
no non-actuating path. No other lib file changed; `no_local_do` allowlist untouched.
`mix format` was also run on pipeline.ex (idempotent on already formatted code).

New test support: `test/support/ported/rpc_validate.ex` (validate_action counterpart: parse in
validation mode, then real `Ash.Query.for_read` / `Changeset.for_*` / `ActionInput.for_action` error
collection, rendered through `AshSurface.Errors`; update/destroy targets are caller-built records).

## Divergences found (documented in tests, ledger `changes`)

- `AshSurface.Errors` renders `fields` / `vars.field` as snake_case attribute names (reference:
  camelCase) and `message` in the long form; validation-structure tests accept both spellings.
- Sort/filter field parsing uses `String.to_existing_atom` (no atom minting); tests materialize the
  atoms the reference domain defines (`@sort_atoms`, `@field_atoms`).
- Shared `Rpc.entries/0` has no entries for the two unconstrained-map metadata actions; the metadata
  test installs extra entries itself.

## Commands (MIX_BUILD_ROOT=_build-gu11 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/d test/ash_surface_mock_discipline_test.exs test/ash_surface/no_local_do_bang_court_test.exs` | 0 | 246 tests, 0 failures, 58 skipped |
| `mix format --check-formatted test/ash_surface/ported/rpc/d/*.exs test/support/ported/rpc_validate.ex` | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (gate; other lanes' rows) | `parity-tests: files=264 ported=9 adapted=168 skipped_gap=44 non_goal=19 unaccounted=17 broken=7 shallow=72` |

Gate rows of this lane: adapted=13, skipped_gap=2 (rpc_validate_action_read_action, run_typed_query),
broken=0 (the 7 broken rows belong to lanes GU7 / wave3 c; the summary line is as of the last re-run, other lanes move it). `grep` for `Process.sleep`, `Mox`, `mock(` over
`ported/rpc/d` and `rpc_validate.ex`: zero matches. `_build-gu11` deleted after the last run.

## Ledger

`parity/test_ledger.json`: T11 rows only, text-level block replacement per row after re-reading the
file in the same step (13 rows now adapted listing the surface file; leftover skips live in unlisted
`*_gap_test.exs` files, same pattern as the pre-existing `struct_argument` row; 2 stay skipped_gap
with corrected `gap`/`skip_tag`).

## Operator decisions

- No `non_goal` recorded. TS-text skips (58 total, 43 of them TS-text) remain `skipped_gap`-style loud
  skips pending an operator decision (README has no sentence covering generated-TS text tests per-test).
- Whether to build a typed-query fixture plus `find_typed_query`/`run_typed_query` in Pipeline
  (unlocks 12 skips only partially: data-shape assertions still need a data layer).
- Whether to camelCase `fields`/`vars.field` in `AshSurface.Errors` (parity with the reference).

Falsifiers: any converted test passing with the shim of its lib path removed (not run: UNVERIFIED);
the 164 count is the delta of skipped counts from `mix test` output, not an independent census.
