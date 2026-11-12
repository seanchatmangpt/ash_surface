# Wave 3 Lane OPD2 Receipt

Standing: PARTIAL

Scope: docs + verification; no lib/ edits, no git state commands.

## Operator decisions

Rows D15-D22 appended to `docs/jira/v26.11.11/OPERATOR-DECISIONS.md` (append-only). D15 T15
non_goal basis, D16 typed-map z.record, D17 relationship_query_capabilities, D18 run_action
pipeline, D19 no_local_do `[:Rewrite, :Source]`, D20 Interception, D21 g3b, D22 atom flake.
README quote re-verified: `grep -n -o -F 'no generated `.ts`, no `.d.ts`, no `tsc` build step'
README.md` -> README.md:29. wave3-t6b.md and wave3-sknodo.md did not exist at run time.

## Atom flake closure

`mix compile` (MIX_BUILD_ROOT=_build-opd2): rc 0 (pipeline.ex compiles now). Combined set
(runtime_parity, parity_deepen, naming_test, field_name_test, compiler, compiler_test,
projector_*, projectors*) x3, MIX_ENV=test: each run 567 tests, 7 failures, 2 skipped, rc 2.
The atomizer test ("atomizing never mints atoms") passed 3/3: no flake observed.

The same 7 failures every run (not atom-related; owners inferred, UNVERIFIED):

| file | failures | cause |
|---|---|---|
| test/ash_surface/compiler/filter_schema_test.exs:98 | 1 | operator sets: `lt` enum now `["note","title"]`, test expects `["title"]` |
| test/ash_surface/parity_deepen/schema_courts_test.exs:172 | 4 | `ZodType.base` yields `z.record(z.string(), z.unknown())`, court expects `z.any()` (D16 area) |
| test/ash_surface/projectors_coverage_test.exs:180 and neighbor | 2 | Expo `{:error, {:unknown_resource, "Help.Ticket.read", "Help.Ticket"}}` |

## Commands

- `mix compile` rc 0; `mix test <set>` x3 rc 2 each (logs /tmp/opd2-run{1,2,3}.log).
- `_build-opd2` deleted.

## Falsifier

A run of the set with an atomizer failure would reopen the flake; none in 3 runs.
