# Wave 3 Lane F1-persist Receipt

Standing: PASS

## Fix

`lib/ash_surface/persist.ex` now persists `resource: get_persisted(dsl_state, :module)`
in the compiled state, so `Validator.admission_refusals/2` admits valid projections and
refuses invalid ones through the real Spark verifier (surfaced as compile warning, Spark 2.7.3).

## Commands

- `MIX_BUILD_ROOT=_build-f1p mix test test/ash_surface/resource/
  test/ash_surface/manifest_type_dispatch_test.exs test/ash_surface/no_local_do_test.exs`
  exit 0: 97 tests, 0 failures, 9 skipped (the 9 loud ash_typescript no-counterpart skips).
- `mix format --check-formatted` on the 3 changed files: exit 0.
- grep `admission_refusals|invalid_surface_compilation` under test/: other uses
  (validator_test, validator_adversarial_test, obligation_validator_coverage_test) call
  `Validator.validate/1` with hand-built maps; all pass, none depended on the bug.

## Files changed

- lib/ash_surface/persist.ex (fix)
- test/ash_surface/resource/validator_action_types_test.exs (re-pinned to correct behavior,
  mix format applied, new real-verifier refusal test for unknown action / get_by /
  read_action / duplicate projection)
- lib/ash_surface/info.ex: DISCLOSED MINIMAL UNBLOCK outside owned files. Another lane's
  `Validator.naming_refusals/1` calls `Info.type_name/1` (plus namespace/field_names/
  argument_names, used by typed_query_fields_test) which did not exist; persisting
  :resource exposed it (34 failures). Added the four `get_opt` accessors; owner lane
  supersedes. test_helper.exs unchanged (`:known_bug` exclude not needed).

## Notes

Mock-discipline court still fails on js_mapped_fields_test.exs:44 and inference_tsc_test.exs:15
(other lanes; not touched). `_build-f1p` deleted.
