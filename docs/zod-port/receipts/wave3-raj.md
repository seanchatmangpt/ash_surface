# Wave 3 Repair: Mutation-Killing Assertions (RAJ)

Standing: PASS

Lane RAJ repairs vacuous tests named in `wave3-skmute1.md` (repair-request section). Live tree
`/Users/sac/ash_surface` (HEAD e3b5d7ffe plus uncommitted lane edits); build root `_build-raj`
(live runs), `/tmp/raj/b` (scratch). Only test files edited; no lib change.

## Files edited (assertions added, existing tests untouched except one pinned value)

- test/ash_surface/ported/rpc/e/tuple_newtype_input_test.exs
- test/ash_surface/ported/rpc/run_action/exotic_type_facts_test.exs
- test/ash_surface/ported/rpc/run_action/rpc_run_action_untyped_maps_surface_test.exs
- test/ash_surface/ported/rpc/run_action/rpc_run_action_aggregates_surface_test.exs
- test/ash_surface/ported/rpc/run_action/rpc_run_action_ltree_surface_test.exs
- test/ash_surface/ported/rpc/run_action/rpc_run_action_vector_surface_test.exs

New assertions run real TypeFacts/ZodType/ValueFormatter/FieldExtractor/Pipeline and real
node + zod (accepted and rejected samples). Observed behaviour pinned: an untyped map is passed
through verbatim on output (atom keys kept).

## Shim-court (scratch copy of live repo at /tmp/raj/w, node_modules and deps symlinked)

Harness `/tmp/raj/court.sh`: sha256 BASELINE, mutate, `mix test` the six files, RESTORE,
sha256 compare. Scratch baseline (unmutated): 90 tests, 0 failures, rc=0. Every row restore
sha256 == baseline (SHA-OK).

| id | lib file | mutation | rc | result |
|---|---|---|---|---|
| m1 | rpc/value_formatter.ex | tuple `elem(value, index)` -> `elem(value, 0)` | 2 | RED 1 fail |
| m2 | rpc/value_formatter.ex | `format_vector(%Ash.Vector{})` returns struct | 2 | RED 1 fail |
| m3 | rpc/value_formatter.ex | packed-binary vector list reversed | 2 | RED 4 fail |
| m4 | rpc/field_extractor.ex | tuple index -> `elem(tuple, 0)` | 2 | RED 2 fail |
| m5 | rpc/result_processor.ex | Decimal `to_string` -> raw value | 2 | RED 1 fail |
| m6 | compiler/zod_type.ex | ltree `escape?` branch disabled | 2 | RED 1 fail |
| m7 | compiler/zod_type.ex | vector kind -> `z.array(z.string())` | 2 | RED 3 fail |
| m8 | compiler/zod_type.ex | ltree base -> `z.string()` | 2 | RED 3 fail |
| m9 | compiler/zod_type.ex | array items -> `z.array(z.unknown())` | 2 | RED 3 fail |
| m10 | compiler/zod_type.ex | map kind -> array | 2 | RED 2 fail |
| m11 | compiler/type_facts.ex | `:items` constraint dropped | 2 | RED 1 fail |
| m12 | compiler/type_facts.ex | array item_type dropped | 2 | RED 3 fail |

Logs: `/tmp/raj/m*.log`.

## Live-tree gates (un-piped rc)

- `MIX_BUILD_ROOT=_build-raj mix test <six files>`: rc=0, 90 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-raj mix ash_surface.parity.tests`: rc=0, unaccounted=0, broken=0.

## Not covered (UNVERIFIED)

Keyword-branch of ValueFormatter, `Ash.NotLoaded` extract branch (aggregates cover omission
of unloaded values only), `extract_resource_field`: no mutation tried.
