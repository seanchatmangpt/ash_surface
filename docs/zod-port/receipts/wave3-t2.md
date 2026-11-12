# Wave 3 Lane T2 Receipt

Standing: PARTIAL_ALIVE

Lane T2: ported/adapted the 10 `test/ash_typescript/*_test.exs` reference files
`resource_schema_mapped_fields .. verifier_checker` (ledger rows with `owner_lane = T2`) into
`test/ash_surface/ported/top/`. All 10 rows are accounted (2 `ported`, 8 `adapted`, 0 `unaccounted`,
0 broken). Behaviors with no ash_surface counterpart are loud skips in `*_gap_test.exs` files
(24 skips) that are intentionally not listed on the rows. Reference: `~/ash_typescript`
HEAD `5d6e80aec1afcbabaf0831768c210fecd81bd869`.

## Per-file disposition

| reference file | disposition | ash_surface test (dir `test/ash_surface/ported/top/`) | tests | loud-skip gap file |
|---|---|---|---|---|
| resource_schema_mapped_fields_test | adapted | resource_schema_mapped_fields_test.exs | 21 | resource_schema_mapped_fields_gap_test.exs (4 skips) |
| ts_action_call_extractor_test | ported | ts_action_call_extractor_test.exs (+ support/ts_action_call_extractor.exs) | 21 | - |
| type_mapping_overrides_test | adapted | type_mapping_overrides_test.exs | 9 | - |
| typescript_codegen_test | adapted | typescript_codegen_test.exs | 43 | typescript_codegen_gap_test.exs (6 skips) |
| typescript_field_names_precedence_test | adapted | typescript_field_names_precedence_test.exs | 13 | typescript_field_names_precedence_gap_test.exs (4 skips) |
| typescript_filter_test | adapted | typescript_filter_test.exs | 24 | typescript_filter_gap_test.exs (5 skips) |
| typescript_sort_test | adapted | typescript_sort_test.exs | 9 | typescript_sort_gap_test.exs (2 skips) |
| union_field_formatting_test | adapted | union_field_formatting_test.exs | 7 | union_field_formatting_gap_test.exs (3 skips) |
| union_types_test | ported | union_types_test.exs | 3 | - |
| verifier_checker_test | adapted | verifier_checker_test.exs | 8 | - |

Per-test notes (what changed and why) are in each row's `changes` in `parity/test_ledger.json`.
Shared private helper: `support/t2.exs` (real node+zod eval, real compile of the ported domain
once per VM, scoped `:ash_surface` env edits, inline resource compile). Private port of the
reference `TsActionCallExtractor` test helper: `support/ts_action_call_extractor.exs`.
Fixtures used: `test/support/ported/**` (read-only) and `AshSurface.ZodFixtures.CalcAgg`.

## Commands and results (MIX_BUILD_ROOT=_build-t2, MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test` the 16 T2 files (10 runnable + 6 gap) | 0 | 182 tests, 0 failures, 24 skipped |
| `mix test test/ash_surface/ported/top` (T2 + other lanes' files in the dir, before the final edit) | 0 | 262 tests, 0 failures, 24 skipped |
| `mix test test/ash_surface/compiler divergence_close projectors ir_test ir_codec_golden compiler_test` | 1 | 444 tests, 1 failure (see below) |
| `mix test test/ash_surface_mock_discipline_test.exs test/ash_surface/no_local_do_test.exs` | 0 | 7 tests, 0 failures |
| `mix format --check-formatted` on every T2 test file and the 3 edited lib files | 0 | clean |
| `grep -nE "Process.sleep|:timer.sleep|Mock|mockall|patch\(|monkeypatch"` over T2 files | 1 | zero matches |
| `mix ash_surface.parity.tests --summary` (full tree) | 1 | `parity-tests: files=264 ported=8 adapted=112 skipped_gap=60 non_goal=14 unaccounted=70 broken=0 shallow=43` |

The gate exits 1 only because other lanes' rows are still `unaccounted`; the 10 T2 rows are
`ported`/`adapted` with `broken=0`. One T2 file is reported SHALLOW (warning only):
`verifier_checker_test.exs` (its regex heuristic looks for node/zod/projector tokens; the test calls
the real `VerifierChecker` and compiles real resources).

Compiler-suite failure (not introduced by T2): `test/ash_surface/compiler/schema_section_test.exs:311`
(Expo vs section per-argument zod: `f8` map renders `z.record(z.string(), z.unknown())` vs Expo
`z.record(z.string(), z.any())`). The `lib` edits below are unreachable from that case (module overrides
need a configured `zod_mapping_overrides`, none is set in that run); UNVERIFIED against a baseline.

## lib edits (all small targeted edits, files untracked and shared with running lanes)

1. `lib/ash_surface/compiler/resource_facts.ex`: `field? false` calculations are excluded from
   `sortable_fields` and from calculation filter entries (the ported Todo `internal_score`, reference
   "excludes calculations with field?: false").
2. `lib/ash_surface/compiler/zod_type.ex`: module-keyed overrides. `zod_mapping_overrides`
   entries keyed by an Ash type module (`{CustomIdentifier, "z.string()"}`, key `inspect(Module)`)
   are now consulted through the definition's `"type" => %{"module" => ...}`; `unmappable_kinds/2`
   no longer reports a kind whose module is overridden (so the `unmappable_type` verifier refusal
   clears once an override is configured).
3. `lib/ash_surface/compiler/type_facts.ex`: `embedded_resources/1` now traverses union member
   definitions (`collect(member["type"])`); before, embedded resources reachable only through a
   union member (Todo `content` members TextContent/ChecklistContent/LinkContent) were missing from
   the compiler closure.

## Divergence-law ledger for this lane

- Better, with executed witness: runtime-only module calculations (`is_overdue`, `days_until_due`)
  are not offered as sort fields because `Ash.Resource.Info.sortable?/3` is false for them
  (`typescript_sort_test.exs` "runtime-only (module) calculations are excluded"); typed unmappable
  type is a typed verifier refusal (`unmappable_type`) rather than a raised `RuntimeError`
  (`type_mapping_overrides_test.exs`); `not` takes a single filter node (pinned in
  `typescript_filter_test.exs`).
- Capability gaps recorded as loud skips (no better-implementation receipt; Q1 should count each
  as MISSING until implemented): record-schema artifact per resource (`response_zod` nil);
  `output_field_formatter` applied to emitted Zod keys, union members, sort field names and filter
  operator names; resource `field_names` mapping applied to emitted embedded/action-input keys and
  `sortable_fields` (`is_active?` makes `QuerySchema.render_sort_schema` refuse with
  `sort_field_not_identifier`); string ordered filter operators; constrained-atom value narrowing
  in filters; relationship entries in the compiled filter (no `related` for Post author/comments);
  whole-array `eq`/`in` filters; selected-fields typed-map rendering and typed-query nested
  selection; `untyped_map_type` consumed by the compiler; valibot projection; typed controller
  result types; Rpc.run_action envelope.

## Operator decisions

- None of the gap tests were classified `non_goal`: no README sentence supports valibot,
  typed-controller or Rpc envelope as a non-goal (README has no valibot mention), so they remain gaps.
- `typescript_filter_test` "relationship filters": the fix (relationship entries in
  `ResourceFacts.filter_entries`) overlaps the `divergence_close/filter_divergence_test.exs` lane;
  left unimplemented to avoid colliding with it.

## Concurrency and cleanup

- Compile-freeze waits: the shared `test/support/ported` fixture compile (todo.ex accept list) and
  `lib/ash_surface/runtime_parity/rpc/pipeline.ex` were mid-edit by other lanes; this lane waited,
  made no unblock edits to them.
- `_build-t2` deleted at completion; no git state commands run.

## Falsifiers

- A T2 `adapted` row whose test file is not executed (`mix test` rc != 0 or a skip inside a listed file).
- A gap test that starts passing its capability silently: gap files assert nothing (`flunk` under a
  `@tag skip:` with the ledger-style capability text).
