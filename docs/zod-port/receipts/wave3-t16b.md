# Wave 3 Lane T16b Receipt

Standing: PARTIAL

Scope: implement the capabilities behind T16's loud gap skips, then convert the tests.

## Converted vs remaining

| gap | status |
|---|---|
| update-action inputs omittable (`testUpdateTaskAllOmittable`) | converted (pass table row + 2 new fail courts) |
| typed route response fields: wrong field type, unmapped key, array member nullability | converted (3 tests + open-record control) |
| PriorityScore / Money auto-derive (2 loud skips) | remaining; GU-T8 receipt `wave3-gu8.md` absent, left untouched |

## Lib edits (small targeted)

- `lib/ash_surface/compiler.ex` `input_entry/3`: carries manifest `required?` as `required:`.
- `lib/ash_surface/compiler/section/schema.ex` `omittable?/1`: also true when `required == false`.
  Rule (reference `schema_core` `omittable = not required?`): Ash manifest `required?` is false
  for update-accepted attributes, so they omit; required arguments and create titles stay
  required. Nullability, types and strictness untouched.
- `lib/ash_surface/compiler/route_schema.ex` `response/1`: a declared `returns` map/typed_map/
  struct with fields (or an array of one) renders via `EmbeddedSchema.render` (strict object,
  member constraints, nullability); bare field types are wrapped; undeclared returns keep
  `z.record`. 

## Test edits

- zod pass: `testUpdateTaskAllOmittable` row; fail: `update rejects title 5`, `create still requires title`.
- `typed_controller_results_fail_test.exs`: testWrongFieldTypes, testUnmappedFieldName, testResultShape, undeclared control.
- `typed_controller_results_gap_test.exs` deleted; the 3 update-omittable/route skips removed from `constraint_validation_gap_test.exs` (2 skips remain).
- Ledger: 3 `changes` strings replaced by exact single-match edits (JSON re-parsed ok).

## Commands (MIX_BUILD_ROOT=_build-t16b, MIX_ENV=test; root deleted)

| command | rc | result |
|---|---|---|
| `mix test .../typed_controller_results_fail_test.exs test/ash_surface/ported/ts/zod` | 0 | 170 tests, 0 failures, 2 skipped |
| `mix test test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `mix test no_local_do_bang_court_test route_schema_test route_introspector_test` | 0 within 37-test run | only failures below |
| `mix test .../schema_section_test.exs` | 1 | 6 failures, all enum `z.enum` vs `z.unknown()` goldens; not from this lane (enum projection moved by another lane), UNVERIFIED against baseline |
| `mix format` on my files | 0 | |

## Notes

IR digest and conformance vectors may move (input `required` key; route response rendering): not regenerated (FINAL-REGEN). Allowlist unchanged.

## Falsifiers

Reverting the `omittable?` clause fails `testUpdateTaskAllOmittable`; reverting `typed_fragment` fails the three route tests.
