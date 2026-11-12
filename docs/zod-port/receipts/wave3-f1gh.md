# Wave 3 Lane F1-gh: Gate Hardening

Standing: PASS

Gate hardening is landed and proven by non-vacuity courts. The gate itself stays red (exit 1):
tightening exposed weak map entries owned by the G lanes (listed below, map not edited).

## Failure classes: present vs only pinned (read our code first)

| class | present in Q1 code before F1? | action |
|---|---|---|
| 1 KD parser fixed columns | YES: regex `KD-\d+` dropped KD-KIN-*/KD-SQ-*, positional cells, naive pipe split | `Register.parse` is header-name driven (aliases, reorder, extra columns, escaped pipes, namespaced ids); `header_problems/1` refuses headerless registers |
| 2 Standing-only receipt closes row | YES: only the Standing line was read | `receipt_evidence_problems/2`: needs a PASS evidence line and must name the court file; court must exist (not run) |
| 3 closed row launders FAIL | YES | FAIL/FAILED/SKIP/SKIPPED/BLOCKED token in receipt body refuses closure |
| 4 comment/string/skip tokens | YES: line-prefix text match, no skip handling | new `TestIndex` (AST via Code.string_to_quoted): comments/strings never match; skip forms refused (multi-line `@tag skip:`, `[:skip]`, `@moduletag`, `@describetag`, inline `skip:`, JS `.skip/.todo`) |
| 5 generic tokens | YES | tokens < 4 chars or matching > 25 test files are broken, listed as GENERIC |
| 6 exit 0 on skip/unreadable | PARTIAL: fatal paths existed; empty inventory, headerless register, unreadable court file, unknown CLI args were not refused | all exit 1; strict OptionParser |
| 7 strict skips, summary | absent | `--strict-skips` default on (`--no-strict-skips` relaxes failure only; cells still printed/counted); `--summary` line |

SK-gate holes also closed: pointer must be `test/**/*_test.exs` or `*.test.mjs` (lib pointers
refused); `.mjs` needs package.json script or mix-court reachability; `contains` must hit an
assertion call or title (not data list/import); describe-only match refused; `any_of` needs >= 2
alternatives; tests with no `assert*/refute*` are VACUOUS; `Code.ensure_loaded?`-guarded tests
refused; one literal test line closes at most 3 rows unless the entry sets `"shared": true`.
Not closed: ExUnit excludes in test_helper/mix.exs unread; tests asserting only through helper
functions (no literal assert) read as VACUOUS (F1-deepen/G lanes re-pin).

## Commands and results (MIX_BUILD_ROOT=_build-f1gh)

- `mix test test/ash_surface/parity test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs` -> exit 0, 56 tests, 0 failures
- `mix format --check-formatted` on changed files -> exit 0
- `mix ash_surface.parity --check-inventory` -> inventory identical: 403 capabilities
- `mix ash_surface.parity --summary` -> exit 1; court_map.json moves under G lanes, value at
  last run: `parity: total=403 pass=206 divergence=0 non_goal=78 broken=39 missing=80`
- Before (Q1 receipt): pass 144 broken 0 missing 187 of 403 (coordinator-observed mid-wave
  146/0/185). Skipped cells at last run: 0.

## Ids refused by tightening (current map), per section

### KD-01
- duplicate register row (1): KD-01
### config
- test/ash_surface/config/parity_keys_test.exs: no test titled like "con (2): config.key.require_tenant_parameters, config.key.warn_on_missing_rpc_config
- token only in data/comment/string, not an assertion or title (3): config.key.import_into_generated, config.key.manifest, config.key.policies
### dsl
- test has no assert/refute (4): dsl.resource.section.typescript.option.argument_names, dsl.resource.section.typescript.option.field_names, dsl.resource.section.typescript.option.type_name, dsl.rpc.entity.resource.option.namespace
### error
- any_of with a single reference (17): error.impl.Ash.Error.Action.InvalidArgument, error.impl.Ash.Error.Changes.InvalidArgument, error.impl.Ash.Error.Changes.InvalidAttribute, error.impl.Ash.Error.Changes.InvalidChanges, error.impl.Ash.Error.Changes.Required, error.impl.Ash.Error.Forbidden.ForbiddenField, error.impl.Ash.Error.Forbidden.Policy, error.impl.Ash.Error.Invalid.InvalidPrimaryKey, error.impl.Ash.Error.Invalid.TenantRequired, error.impl.Ash.Error.Page.InvalidKeyset, error.impl.Ash.Error.Query.InvalidArgument, error.impl.Ash.Error.Query.InvalidPage, error.impl.Ash.Error.Query.InvalidQuery, error.impl.Ash.Error.Query.NotFound, error.impl.Ash.Error.Query.ReadActionRequiresActor, error.impl.Ash.Error.Query.Required, error.impl.Ash.Error.Unknown.UnknownError
- shared test closes >3 rows (4): error.impl.AshAuthentication.Errors.AuthenticationFailed, error.impl.AshAuthentication.Errors.InvalidToken, error.type.authentication_failed, error.type.invalid_token
### tstype
- token only in data/comment/string, not an assertion or title (3): tstype.create, tstype.on, tstype.unsubscribe
### type
- generic token (<4 chars or >25 files) (4): type.constraint.fields, type.constraint.match, type.constraint.max, type.constraint.min
### verifier
- test has no assert/refute (2): verifier.VerifyFieldNames, verifier.VerifyMetadataFieldNames

## Courts

`test/ash_surface/parity/gate_hardening_test.exs`: each class has a refused shim plus green
baseline (VACUOUS GATE on acceptance). `gate_test` and `gate_non_vacuity_test` fixtures were
updated to the stricter law (header row, receipt PASS evidence, real assertions).

## Files changed

lib/mix/tasks/ash_surface.parity.ex, lib/ash_surface/parity/{register,court_map,report}.ex,
lib/ash_surface/parity/test_index.ex (new), test/ash_surface/parity/{gate_test,
gate_non_vacuity_test,gate_hardening_test}.exs, scripts/parity_inventory.exs (new), this
receipt. KNOWN_DIVERGENCES.md unchanged (no rows). `_build-f1gh` deleted.
