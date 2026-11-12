# Wave 3 Lane T16 Receipt

Standing: PASS

Scope: `test/ts/shouldFail/` (17) + `test/ts/zod/{shouldPass,shouldFail}` (8). All 25 T16 rows
accounted: 14 adapted + 3 non_goal under shouldFail (8 of the 14 were seeded by wave3-06 and left
untouched), 4 adapted zod/shouldFail, 4 adapted zod/shouldPass. 0 unaccounted, 0 broken, 0
shallow among T16 rows (gate output below). Six loud gap skips live in unlisted `*_gap_test.exs`.

## Per-file disposition

| disposition | files |
|---|---|
| adapted, seeded wave3-06 (8, untouched) | invalidFields invalidSort invalidStructure loadRestrictions noFieldsReadActions typeMismatches unionValidation wrongPaginationTypes |
| adapted, tsc (5, this lane) | firstAggregates invalidCalcArgs nestedQueryOpts nonFieldCalculations operations |
| adapted, zod values (1) | typedControllerResults |
| non_goal (3) | customFetchErrors invalidChannelUsage invalidTypedChannelUsage |
| adapted, zod (8) | zod/shouldFail: complexInvalidSchemas constraintValidation customTypeSchemas invalidZodUsage; zod/shouldPass: basicZodUsage complexSchemaValidation constraintValidation customTypeSchemas |

Per-test notes live in each row's `changes`.

- tsc cases: `test/ts/inference_t16/shouldFail/*.ts` over `Inference.emit/1` +
  `Inference.action_types/1` (private fixture in `inference_fail_cases_test.exs`). Each refused
  line carries `// @ts-expect-error` (unused directive fails tsc). Mutation control per file: a
  tmp copy with every directive stripped must yield at least one tsc error per directive
  (measured 4/4, 7/7, 13/13, 4/4, 10/10 errors/directives).
- zod cases: real artifact of `AshSurface.Ported.Domain` (`HarnessExt.artifact!`) with scoped
  `zod_mapping_overrides` (CustomIdentifier `z.string().min(3)`, GeoPoint lat/lng object, Money
  object, PriorityScore `z.number()`), run under node + real zod by the new
  `test/ts/zod_t16_runner.mjs`; issues asserted as typed `path: code` (union branch errors
  flattened). zod/shouldFail `constraintValidation` (51 functions) and shouldPass (all but
  `testUpdateTaskAllOmittable`) each have a test named after the reference function.
- non_goal quote (verified `grep -cF` count 1 in README.md): ``no generated `.ts`, no `.d.ts`, no
  `tsc` build step``.

## Commands (MIX_BUILD_ROOT=_build-t16, MIX_ENV=test; build root deleted after)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/ts/should_fail test/ash_surface/ported/ts/zod test/ash_surface_mock_discipline_test.exs` | 0 | 180 tests, 0 failures, 6 skipped (the 6 gap skips) |
| `mix format --check-formatted` on all my .exs | 0 | clean |
| `grep -rnE "Process\.sleep\|Mock\|mockall\|:meck\|Mox"` over my test dirs | 1 | zero matches |
| `mix ash_surface.parity.tests --summary` | 1 (other lanes' rows) | `parity-tests: files=264 ported=9 adapted=182 skipped_gap=40 non_goal=19 unaccounted=0 broken=14 shallow=81`; test/ts/shouldFail adapted=14 non_goal=3; test/ts/zod/shouldFail adapted=4; test/ts/zod/shouldPass adapted=4; all unaccounted=0 broken=0 |

The 14 broken and 81 shallow in the global line are other lanes' rows (none under
`test/ts/shouldFail` or `test/ts/zod`; checked via `--json` `shallow_files` / `broken`).

## Loud gaps (unlisted `*_gap_test.exs`, 6 skips)

`zod/constraint_validation_gap_test.exs`: update schema all-omittable (`Task.update` requires
`title`); PriorityScore and Money emit `z.unknown()` without an explicit override.
`should_fail/typed_controller_results_gap_test.exs`: route response `fields` not enforced
(`z.record(z.string(), z.unknown())`): wrong field type, unmapped key, array member nullability.
No lib implementation was feasible in-lane (the omittable rule lives in a section adapter other
lanes are editing; typed route response objects need a ZodType map-fields renderer).

## Lib edits

None. New non-test files: `test/ts/zod_t16_runner.mjs`, `test/ts/inference_t16/shouldFail/*.ts`,
`test/ash_surface/ported/ts/zod/support/zod_cases.exs`. Ledger: only the 17 T16 rows without a
prior disposition were rewritten (textual block replacement; other rows byte-identical).

## Observations (O, not admitted fixes)

- Mid-lane, another lane changed `Inference` utility types (args union) and the Task.update key
  mapping (`archived?` -> `isArchived`); tsc error locations are layout-sensitive, so every
  refusal is a single-line expression with its directive directly above.
- zod 4 defines `.validate`; the reference's "not a method" assumption is pinned as
  `typeof s.validate == "function"` in `zod_usage_test.exs`.

## Operator decisions

1. customFetchErrors / invalidChannelUsage / invalidTypedChannelUsage are non_goal on the
   general no-`.ts` sentence only. `.mjs` counterparts exist for fetch and channel transport
   (`test/js/http_transport*.test.mjs`, `test/js/channel_transport.test.mjs`); confirm non_goal
   vs skipped_gap.
2. Money / PriorityScore / CustomIdentifier / GeoPoint are tested through explicit
   `zod_mapping_overrides` (inline zod, no TS-authored schemas); confirm that is the accepted
   adaptation versus building default mappings (gap rows above).

## Falsifiers

A tsc case that compiles with its directive removed shows a vacuous refusal (the mutation control
fails the lane); a zod case whose `issues` lack the pinned `path: code` fails its test; a gap skip
whose capability lands makes its `flunk` body the work item.
