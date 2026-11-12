# Wave 3 Lane T15 Receipt

Standing: PASS

Scope: `test/ts/shouldPass/` (42 files). T15 rows: 32 adapted, 10 non_goal, 0 unaccounted,
0 broken, 0 shallow (gate output below). Plus closure of
`dsl.rpc.entity.rpc_action.option.deprecated`.

## Per-file disposition

| disposition | files |
|---|---|
| adapted (16, prior wave3-06, untouched) | calculations compositePrimaryKey conditionalPagination embeddedResources identities inputOptionality keywordTuple loadRestrictions nestedQueryOpts noFields operations relationships sortFields typedMaps typedStructs unionTypes |
| adapted, tsc (14, this lane) | argsWithFieldConstraints complexScenarios customTypes firstAggregates genericActionTypedStruct get getBy hoistedSatisfiesFields metadata noArgCalculations noFieldsTypeInference precisePaginationTypes unionCalculationSyntax structArguments(+zod) untypedMaps(+zod) |
| adapted, zod (1) | typedControllerResults |
| non_goal (10) | channelLifecycleHooks channelNoFieldsTypeInference channelOperations channelTimeoutTest channelValidations typedChannelOperations rpcLifecycleHooks customFetch fetchOptionsAdvanced errorFields |

Per-test notes live in each row's `changes`. tsc cases:
`test/ts/inference_t15/shouldPass/*.ts` over `Inference.emit/1` + `Inference.action_types/1`
(private fixture in `inference_cases_test.exs`; no T5 fixture dependency). `// @ts-expect-error`
lines are negative controls (unused directive fails tsc); a separate control test shows a wrong
expectation is rejected.

non_goal quote (verified `grep -F` count 1 in README.md): ``no generated `.ts`, no `.d.ts`, no
`tsc` build step``.

## Commands (MIX_BUILD_ROOT=_build-t15, MIX_ENV=test; build root deleted after)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/ts/should_pass/inference_cases_test.exs` | 0 | 17 tests, 0 failures |
| `mix test test/ash_surface/ported/ts/should_pass/zod_route_cases_test.exs` | 0 | 8 tests, 0 failures |
| `mix test` rpc_action_deprecated + should_pass + mock_discipline + metadata_projection + dsl_runtime_courts | 0 | 72 tests, 0 failures |
| `mix format --check-formatted` on all my .ex/.exs | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes' rows) | `parity-tests: files=264 ported=0 adapted=48 skipped_gap=22 non_goal=10 unaccounted=175 broken=9 shallow=1`; test/ts/shouldPass: adapted=32 non_goal=10 unaccounted=0 broken=0 |

The 9 broken rows are T4 `verify_action_types/*` (skip_tag mismatch) and the 1 shallow is
T13 `verify_typed_channel_test.exs`; neither is a T15 row.

## rpc_action `deprecated` (was MISSING, ownerless)

- lib edit (targeted, `lib/ash_surface.ex`): `dsl_metadata_options/1` now calls new
  `put_deprecated/2`: `deprecated: true` -> action custom `ash_surface` entry carries
  `"deprecated" => true, "jsdoc" => "@deprecated"`; a string message ->
  `"@deprecated <msg>"` (`*/` neutralised); nil/false add no keys. The entry also enters the
  contract surface envelope via `decorate_manifest`.
- Court: `test/ash_surface/rpc_action_deprecated_test.exs` (4 tests: true, message, `*/`
  injection, unset/false) through real `Ash.Info.Manifest.generate` + `AshSurface.from_manifest`.
- `parity/court_map.json` (targeted Edit): third test added to
  `dsl.rpc.entity.rpc_action.option.deprecated`. `mix ash_surface.parity` lists no
  broken/missing line for that id (overall gate still FAIL from other lanes: broken=36
  missing=71).

## Operator decisions

1. The 10 non_goal rows rest on the general no-generated-`.ts` README sentence, not a
   hook/channel-specific one. The channel adapter (`phoenix_channel`) and fetch behavior have
   `.mjs` runtime counterparts (`test/js/channel_transport.test.mjs`, `http_transport*.test.mjs`);
   confirm non_goal vs a skipped_gap reclassification.
2. Zod renders typed-map/struct arguments as `z.record(z.string(), z.any())`, so
   `argsWithFieldConstraints` member constraints are enforced only by the TS inference path.

## Falsifiers

A case passing tsc with its `@ts-expect-error` removed would show a vacuous negative
control; a `deprecated: "msg"` projection whose manifest custom lacks `jsdoc` fails the court.
