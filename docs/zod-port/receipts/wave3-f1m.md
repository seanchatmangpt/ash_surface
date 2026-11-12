# Wave 3 F1-missing Receipt

Standing: PASS

Scope: remaining MISSING/BROKEN ids after F1-repin, minus running-lane and operator-decision ids.

## Counts (mix ash_surface.parity --summary, exit 1)

| point | pass | divergence | non_goal | broken | missing |
|---|---|---|---|---|---|
| before (this lane start) | 295 | 0 | 79 | 1 | 28 |
| after | 303 | 11 | 79 | 0 | 10 |

Codegen section after: 28 pass / 1 divergence / 13 non_goal / 0 broken / 1 missing.
The 6 type.* ids (kinds time/time_usec, constraints min/max/greater_than/less_than) and the
KD-02 id moved from missing to divergence during the lane (F1-kindiv receipt lint, plus the
KD-02 re-witness below); the error and flag ids were closed here.

## Closed

| id(s) | how | court |
|---|---|---|
| 11 error.impl.* (Changes.InvalidChanges, Query.InvalidQuery, Query.NotFound, Forbidden.ForbiddenField, Changes/Query/Action.InvalidArgument, Page.InvalidKeyset, Query.InvalidPage, Invalid.TenantRequired, Invalid.InvalidPrimaryKey) | per-leaf tests with the leaf in the title, asserting wire type and short message; third any_of file added to `error.impl.*` | test/ash_surface/errors_impl_leaf_test.exs |
| task.codegen.flag.dev (BROKEN) | court_map test title re-pointed to the existing test | test/ash_surface/codegen_task_test.exs "--dev --check with Config.always_regenerate bypasses --check and regenerates" |
| codegen.module.Codegen.ZodSchemaGenerator (KD-02 unwitnessed) | PASS evidence line appended to wave3-f1rw.md | test/ash_surface/projectors/js_named_refs_test.exs |

## Left open (owner / reason)

| id | owner |
|---|---|
| route.option.valibot_schema_name, Codegen.ValibotSchemaGenerator | operator D1 |
| typed_controller option module_name, namespace | operator D8 |
| Installer.Inertia, LandingPage, Layout | operator D2 |
| task.codegen.flag.run_endpoint, validate_endpoint | operator D3 |
| runtime.module.TypedChannel.Interception | operator D6/D20 |

No non_goal added (no verbatim README quote available for these; docs/jira/v26.11.11/OPERATOR-DECISIONS.md).

## Commands

- PASS: `mix ash_surface.parity --json` exit 1 (census), `--summary` exit 1 (after counts above).
- PASS: `mix test errors_impl_leaf_test.exs js_named_refs_test.exs codegen_task_test.exs` exit 0, 28 tests, 0 failures.
- PASS: `mix test test/ash_surface/no_local_do_test.exs` exit 0, 5 tests, 0 failures; allowlist unchanged.
