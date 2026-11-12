# Wave 3 Lane 07 Receipt

Standing: PARTIAL

## Files (new, test-only)

- test/ash_surface/manifest_type_dispatch_test.exs
- test/ash_surface/resource/validator_action_types_test.exs

## Commands

`MIX_BUILD_ROOT=_build-w307 mix test <both files> test/ash_surface_mock_discipline_test.exs`
Exit output: `52 tests, 1 failure, 10 skipped`. The one failure is the mock-discipline
court, caused by other lanes' unparseable files (`test/ash_surface/projectors/js_mapped_fields_test.exs:44`,
`test/ash_surface/ts/inference_tsc_test.exs:15`), not by this lane. My two files: 0 failures,
10 skipped (9 loud ash_typescript-has-no-counterpart skips + 1 known-bug skip).

## REAL BUG (lib/ not edited)

`lib/ash_surface/persist.ex:15-18` persists `%{surface:, metadata:}` with no `:resource`.
`Validator.admission_refusals/2` (validator.ex `public_action_set/1` -> nil) then returns
`invalid_surface_compilation` for every non-empty projection list, so a VALID projection on a
real resource warns at compile time (Spark 2.7.3 downgrades verifier errors to a compile
warning, so modules still compile and the verifier never actually rejects). Pinned by passing
tests (no `:resource` key; warning present); desired-behavior test is `@tag skip` (not
`:known_bug`, because test_helper.exs does not exclude it).

## Divergences pinned

- `show_metadata`/`metadata_field_names` are not validated (no ash_surface counterpart to
  verify_metadata_field_names).
- NewType subtype constraints include `allow_empty?: false`.
- Unmappable custom kinds are reported via `ZodType.unmappable_kinds/2` and render `z.unknown()`;
  no verifier raise.
- verify_action_types/* (9 files): no resource-validator counterpart; loud skips.
- decorator_test: covered by existing from_manifest_test.exs; persist_resource_lookups ->
  `Resource.Info` compiled/compiled!/compiled_result tests.

## UNVERIFIED

- Full `mix test` (aborts at VM exit per contract); other lanes' concurrent edits.

## Requests

- Owner of lib/ash_surface/persist.ex: add `resource: dsl_state module` to compiled state; then
  un-skip the desired-behavior test and flip the two pinned-bug tests.
- test_helper owner: exclude `:known_bug` if future known-bug tests are wanted.

_build-w307 deleted.
