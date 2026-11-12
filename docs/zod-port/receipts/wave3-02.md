# Wave 3 Lane 02: js.ex Schema Emission

Standing: PARTIAL_ALIVE

## Files

- lib/ash_surface/projectors/js.ex (edited)
- test/ash_surface/projectors/js_schema_wiring_test.exs (new)
- test/js/generated_schema_wiring_runner.mjs (new)

## Changes

- filter/sort/page/response_zod each admitted via ZodGuard (fail-closed
  `{:unadmitted_zod, id, reason}`) and emitted as `<id>_filter_schema`,
  `_sort_schema`, `_page_schema`, `_response_schema`; descriptor gains
  filterSchema/sortSchema/pageSchema/responseSchema/capabilityFlags (frozen);
  new `QUERY_SCHEMAS` registry. Non-boolean flags refused `{:unadmitted_field,..}`.
- zod 4 string-arg `.regex("..")` (QuerySchema sort) converted post-admission at the
  embed site to `.regex(new RegExp("..."))`; proven by node execution.
- Import header reads `AshSurface.Config.zod_import_path/0` (default "zod").
  `zod_import_into_generated` ignored: single-artifact contract kept.

## Commands

`MIX_BUILD_ROOT=_build-w302 mix test test/ash_surface/projectors/js_schema_wiring_test.exs
test/ash_surface/projectors/js_projector_test.exs test/ash_surface/projectors/js_safeparse_test.exs
test/ash_surface/projector_ir_determinism_test.exs` -> 21 tests, 0 failures, exit 0.

## UNVERIFIED

- wave3-01.md not present at fill: tests use hand-built IR (IN-FLIGHT-AT-FILL for
  IR-field-dependent emission). Codegen task tests and no_local_do_test not run.
- Naming/FieldName not used: lib/ash_surface/field_name.ex exports format/compute/
  parse_input/parse_sort/client_to_internal, not yet wired.

## Requests

- w3-03: codegen task artifact assertions may need new descriptor fields.
- Producer (QuerySchema): optionally emit RegExp-native form; embed-site conversion suffices.
