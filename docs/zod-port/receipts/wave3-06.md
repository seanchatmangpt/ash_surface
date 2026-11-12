# Wave 3 Lane 06 Receipt (TS tsc / zod test tree)

Standing: PASS

## Files

- test/ash_surface/ts/inference_tsc_test.exs (new; fixture = real `Inference.emit/1` output)
- test/ts/inference/shouldPass/*.ts (16) and test/ts/inference/shouldFail/*.ts (8)
- test/ash_surface/ts/zod_runtime_features_test.exs (new)
- test/ts/cases/{constraints,filters,sort_page,relationships_load,calculations,identities,
  errors_union,unions}.json
- Untouched: test/ts/shouldPass/todo_input.ts, shouldFail/todo_input_misuse.ts, cases.json, runners.

## Commands

- `ls node_modules/.bin/tsc` -> present.
- `MIX_BUILD_ROOT=_build-w306 mix test test/ash_surface/ts` -> 18 tests, 0 failures, exit 0
  (build root seeded by copying `_build`, deleted afterwards).
- mock grep (Mox|mockall|:meck|Mock(|patch(|monkeypatch) over test/ash_surface/ts, test/ts -> 0.

## Coverage

- shouldPass: calculations, relationships, identities, sortFields, conditionalPagination,
  embeddedResources, keywordTuple, typedMaps, typedStructs, unionTypes, compositePrimaryKey,
  loadRestrictions, nestedQueryOpts, noFields, operations, inputOptionality.
- shouldFail (each line marked `// @error`; test requires tsc error count >= markers):
  invalidFields, invalidSort, wrongPaginationTypes, loadRestrictions, unionValidation,
  typeMismatches, noFieldsReadActions, invalidStructure.
- Zod: constraints runs the real emitted artifact (Constraints fixture domain); the other 7
  run real renderer output under node+zod via fragment_runner.mjs, each asserting both
  accept and reject outcomes occur.

## UNVERIFIED / skipped

- Reference suites not ported (types ash_surface does not emit): none skipped by type; but
  case bodies are original (reference files not diffed line-by-line); "identities" and
  "compositePrimaryKey" TS cases test only field typing since Inference emits no identity types.
- Zod feature facts are hand-built for 7 of 8 features (wave3-05 fixtures exist but only the
  Constraints domain was consumed); relation/calc fixtures not wired.
- IdentitySchema aliases `by_id` (the PK) into `primary_key`, so a separate by_id key never
  exists; asserted in test.
- Fixture resource meta (Todo/User/...) is hand-authored through `Inference.resource_meta`, not
  compiled from an Ash domain (README no-.d.ts stance: inference not wired into js.ex).
- Non-goals: Valibot, hooks, channel-hook TS suites.

## Requests

- None.
