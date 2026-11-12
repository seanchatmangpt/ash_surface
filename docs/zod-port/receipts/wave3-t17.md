# Wave 3 Lane T17 Receipt

Standing: PASS

Coordinator note: the lane did not write this file; the coordinator transcribed the lane's final
report. Counts below are the lane's, not re-run by the coordinator (UNVERIFIED by coordinator).

All 18 T17 rows accounted: 0 unaccounted, 0 broken, 0 shallow among them.

## Per-file disposition

| disposition | files |
|---|---|
| adapted (8) | `custom/nestedZodSchemas`, `customZodSchemas`, `customTypes`, `runZodTests`, `shouldPass` (entry), `shouldFail` (entry), `structFieldSelection`, `testStructFieldSelection` |
| non_goal (3) | `channelHooks`, `routeHooks`, `rpcHooks` |
| skipped_gap (7) | `runValibotTests`, `customValibotSchemas`, `custom/nestedValibotSchemas`, `valibot/shouldPass/{constraintValidation,customTypeSchemas}`, `valibot/shouldFail/{constraintValidation,customTypeSchemas}` |

non_goal quote: "no generated `.ts`, no `.d.ts`, no `tsc` build step" (grep -F count 1 in README.md).

## Tests added

- `test/ash_surface/ported/ts/root/custom_zod_overrides_test.exs`
- `test/ash_surface/ported/ts/root/entry_points_test.exs`
- `test/ash_surface/ported/ts/root/struct_field_selection_test.exs`
- `test/ts/inference_t17/shouldPass/{structFieldSelection,testStructFieldSelection}.ts`
- `test/ash_surface/ported/ts/valibot/valibot_gap_test.exs` (4 loud skips, tag `T17-VALIBOT-GAP`)

## Commands

- `mix test test/ash_surface/ported/ts/root test/ash_surface/ported/ts/valibot`: 19 tests,
  0 failures, 4 skipped (exit code not captured).
- `mix ash_surface.parity.tests`: exit 1 (other lanes' rows):
  `files=264 ported=8 adapted=109 skipped_gap=60 non_goal=14 unaccounted=70 broken=3 shallow=41`.

## Lib edits

None.

## Operator decisions

1. Valibot (7 rows): README has no Valibot sentence; skipped_gap. Build a Valibot projector, or
   add a README non-goal sentence.
2. Hook files (3 rows) rest on the generic no-generated-`.ts` sentence (as T15/T9 hook rows).
3. Struct selection shorthand: ash_surface accepts only `{args, fields}` for calculation
   selection; the reference's bare `self: [...]` is rewritten in adapted cases. Divergence, not a
   registered KD row.

## See Also

`TEST-PORT-CONTRACT.md` · `wave3-t15.md`
