# wave3-skmutb

Standing: PARTIAL

Lane SK-mutB (skeptic, read-only on lib/ and test/). Subject: ported rpc surface tests
(`test/ash_surface/ported/rpc/{run_action,a,b,c,d}/*_surface_test.exs`), `typed_controller/`,
`typed_channel/`, `ts/`. Method: shim-court on SCRATCH copies (`/tmp/skmb/p0..p4`, each with its
own `MIX_BUILD_ROOT=<copy>/_build-skmb`; lib/test/mix/config/priv rsynced, deps and node_modules
symlinked; no worktree, no git state command, real tree untouched). Each mutation is a literal
string replace applied from the pristine real file, test run, file restored.

## Scope and honesty bounds

- Mutation matrix = file x mutation over 34 mutations. Round 1 (20 mutations over all
  rpc/typed_* dirs) ran on a snapshot taken at lane start; 18 surface files landed afterwards
  by other lanes and were re-run on a fresh sync (n_* and x_* rows). Fresh-sync baselines:
  rpc/a three previously excluded files 64 tests 0 failures; ts+typed_*: 359 tests,
  4 failures (all `ts/should_fail/typed_controller_results_fail_test.exs`, pre-existing,
  flaky between runs: baseline 4, some mutated runs 1 failure).
- Excluded from scratch: `zz_probe_test.exs` (rpc/a, rpc/c; 60 s timeout, in-flight probes),
  `gu8d_probe_test.exs`, `codegen_determinism_test.exs` (minutes-long).
- tsc `@ts-expect-error` negatives: the ts/ tests are zod-under-node (no tsc cases exist);
  `grep -c ts-expect-error`: struct_field_selection 4, inference_cases 1, inference_fail 4.
  Not mutated individually (UNVERIFIED).
- Machine load average 90-190 during runs (fleet); no timing assertions were relied on.
- Load-contaminated set discarded: runs `r_*`/`z_*`/`v_*` on p4 had a lib snapshot out of
  step with p3 (111-failure floor in ts/zod); superseded by the `s_*` rows on a fresh sync.

## Mutations (all RED = at least one failure in the run)

| id | file mutated | mutation | files RED (of ported surface set) |
|---|---|---|---|
| camel_snake | field_name.ex | `:camel` formatter -> snake (no camelize) | 14 + n_camel rows |
| pascal_camel | field_name.ex | pascal -> camel | 0 surface files (3 other tests) |
| input_pass | field_formatter.ex | parse_input_fields -> passthrough | most rpc files |
| out_nofmt | output_formatter.ex | ValueFormatter bypassed on output | 125 failures |
| union_id / tuple_id / keyword_id / array_id | value_formatter.ex | kind branch returns value | 52/13/16/26 failures |
| tuple_extract | field_extractor.ex | tuple normalization -> `%{}` | 4 failures |
| drop_fields | pipeline.ex | field selection template -> `[]` | 128 failures |
| swallow_err | pipeline.ex | `{:error,_}` -> `{:ok, %{}}` | 13 failures |
| identity_off | pipeline.ex | update/destroy identity resolution off | 22 failures |
| has_more | result_processor.ex | page `has_more` forced false | 7 failures |
| err_type / err_short | error_builder.ex | rename `type` value / `short_message` key | 8 / 10 failures |
| sort_pass | field_formatter.ex | format_sort_string -> passthrough | 14 failures |
| x_errtbl | errors.ex | InvalidChanges type string altered | error_protocol RED |
| x_nfe | resource_facts.ex | global `not_found_error?` -> true | global_config RED |
| x_qopt_all | requested_fields/atomizer.ex | no query-opt atomization | nested_query_opts RED |
| x_qopt | same | drop only `:offset` from atom keys | GREEN (see weak list) |
| x_tq | error_builder.ex | typed_query_not_found type string | run_typed_query RED |
| x_present | action_manifest.ex | `present/1` -> nil | json_manifest, namespace_manifest RED |
| s_nullable | route_schema.ex | `allow_nil?: false` treated nullable | base_path, codegen, fold_arg, ts route RED |
| s_coerce | route_schema.ex | numeric path/query coercion off | codegen_test RED |
| s_int | zod_type.ex | integer -> `z.number()` | constraint_validation_fail RED |
| s_min | zod_type.ex | drop explicit `.min(n)` | channel_verify RED |
| s_null | zod_type.ex | drop `.nullable()` | channel_payload, codegen, ts pass/route RED |
| s_dup / s_names | route_schema/verifier.ex | duplicate-name / invalid-name check off | verify_typed_controller RED |

Per-file kill counts from the 34-mutation matrix: every file below that is not in the lists
that follow was RED under at least two mutations.

## VACUOUS (green under every applicable mutation or structurally subject-less)

1. `rpc/d/rpc_pipeline_surface_test.exs` test "provides clear error for tenant requirement"
   (lines ~427-451): all three case branches are `assert true`; any returned shape other than
   the three listed raises CaseClauseError, so it can only fail on an unlisted shape, never on
   wrong behaviour. Mutation-independent by construction. Owner: GU-T11 (wave3-gu11.md).
2. `rpc/c/private_arguments_surface_test.exs` (4 tests): never references any `AshSurface.*`
   module (`grep` count 0); asserts `Ash.Resource.Info.action(OrgTodo, ...)` arguments declare
   `public?: false`. It verifies the fixture DSL, not the pipeline; NEVER RED under all 34
   mutations. Owner: GU-T10 (wave3-gu10.md).
3. `rpc/b/manifest_generator_surface_test.exs` (9 tests): NEVER RED, including `x_present`
   which turned two sibling ActionManifest files RED. Owner: GU-T10/T11 manifest lane
   (not named in receipts; UNVERIFIED which).

## WEAK (green for a specific mutation; whole-file not vacuous)

- `rpc/c/nested_query_opts_surface_test.exs`: `x_qopt` (drop `:offset` from atomized query
  opts) stays GREEN because helper `fetch/2` returns `Map.get(map, :k) || Map.get(map, "k")`;
  the offset/limit assertions cannot distinguish atom from string keys. Full atomization
  removal (`x_qopt_all`) is RED. Owner: GU-T10.
- Pass-only zod files (`ts/zod/constraint_validation_pass_test.exs`, `zod_usage_test.exs`,
  `custom_type_schemas_test.exs`) are GREEN under loosening mutations (`s_int`, `s_min`) by
  design; tightening mutations were not run (UNVERIFIED).

## UNVERIFIED (no applicable mutation run; not claimed vacuous)

- NEVER RED, by targeting gap only: `typed_channel/channel_runtime_gap_test.exs`,
  `typed_controller/request_handler_gap_test.exs` (loud-skip gap files),
  `typed_controller/router_introspection_test.exs`,
  `typed_controller/codegen_enforcement_test.exs` (needs node+zod; no zod-emission mutation
  reached it). Next mutation candidates: Introspector path-param extraction; zod
  `.strict()` emission.
- `s_chkind` (channel_discovery `resolved_kind`) was still running at write time; no result.
- Static greps: `assert true` appears only in item 1 (plus a comment in
  `rpc/b/load_restrictions_test.exs:261`, non-surface). Files lacking RuntimeParity/Pipeline/
  ErrorBuilder references that nonetheless have RED mutations: none beyond item 2.
- 45/80/127 skipped tests in run_action/b/c baselines are loud skips (gap files); skipped
  tests are not coverage.

## Commands and exits

- baseline rpc/run_action: `mix test test/ash_surface/ported/rpc/run_action` rc=0, 305 tests,
  0 failures, 45 skipped. rpc/b rc=0 210/0/80. rpc/c rc=0 (after zz removal) 269/0/127.
  rpc/d rc=0 241/0/58. typed_controller rc=0 92/0/13. typed_channel rc=0 38/0/8.
- mutated runs: every row above exited rc=2 (test failures), except `x_qopt` rc=0 and the
  first-pass `r_*` rows on the contaminated set (rc=0 on 8-file subset = those 8 files GREEN,
  later explained by targeting mismatch). Raw outputs: `/tmp/skmb/out-*.txt`,
  `/tmp/skmb/o1-*.txt`; harness: `/tmp/skmb/mut.py`, `run.sh`, `run1.sh`.
- topology note: a first `rsync` of the whole repo root was REFUSED by the topology guard;
  re-done as an explicit-path subset copy.

## Falsifier

A file marked VACUOUS/WEAK is refuted if any mutation on the code it claims to cover turns it
RED; a file counted RED is refuted if the same mutation also fails on an unmutated fresh copy
(baselines above: only the pre-existing ts/should_fail flake).
