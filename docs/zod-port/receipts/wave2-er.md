# Wave 2 ER: error contract census lane 14

Standing: PARTIAL

## Files

- lib/ash_surface/errors.ex, error_handler.ex, ir/error_shape.ex, compiler/error_schema.ex
- NEW lib/ash_surface/compiler/validation_error_schema.ex
- tests: error_schema_test.exs, error_runtime_test.exs (updated); NEW errors_test.exs,
  error_schema_deep_test.exs

## Changes

- Wire shape: generic error is type `unknown_error`, id under `details.error_id`
  (`errorId` camel), no top-level `error_id`; every type goes through
  `ErrorShape.normalize_type/1`; `details` defaults to `%{}`.
- Private type table (no protocol) for 19 struct rows; others resolve to `unknown_error`.
  Policy -> forbidden, message and vars redacted unless `show_policy_breakdowns: true`.
  ReadActionRequiresActor -> forbidden. `Errors.classify/1` exported.
- ErrorShape: +invalid_identity, missing_identity, sort_not_supported,
  pagination_not_supported, invalid_pagination (20 types).
- error_handler.ex: `apply/3` replaced by `Function.capture/3` + fixed-arity calls (0..3 extra
  args); no_local_do_test no longer flags the file.
- ErrorSchema: `formatter:` opt on every renderer (camel default); `carry/2` per-action
  `{errors, fieldErrors}`; render returns `carry`.
- ValidationErrorSchema: arrays, embedded (resources opt, cycle -> record), union, typed
  containers, resource refs; leaf via `ZodType.fragment`; `render/2` is ZodGuard-proven.

## Commands (MIX_BUILD_ROOT=_build-er, deleted afterwards)

`mix test` over error_schema_deep, errors, error_runtime, error_schema, no_local_do,
ash_surface_mock_discipline: 58 tests, 3 failures, none in owned files:

- no_local_do: `Rewrite.Source.update` in lib/ash_surface/installer/{package_json,tsconfig}.ex;
  `apply` in compiler/calculation_schema.ex and compiler/embedded_schema.ex (other lanes).
- mock_discipline: unparseable test/ash_surface/compiler/union_schema_test.exs:49 (other lane).

Owned files alone: errors_test.exs 26 tests 0 failures (includes node/zod round trip with
negative control: extra `error_id` key and `internal_error` are refused). Deep test 
file passed in the combined run.

## Recorded

`Exception.message/1` of `Ash.Error.Forbidden.Policy` in Ash 3.33.11 with no policies is
`"forbidden"`; breakdown text comes from `Policy.report/2`.

## UNVERIFIED

- A real `Ash.Policy.Authorizer` flow: "No SAT solver available" in this repo; the Policy
  error is constructed directly.
- AshAuthentication rows (module not a dependency; table entries only).
- Full `mix test` (VM-exit abort, pre-existing).

## Requests

- Config lane: keys `show_raised_errors`, `show_policy_breakdowns`, `error_handler`
  (resource/domain handlers) to forward into `Errors.to_errors/2` opts.
- IR lane: carry per-action field_errors via `ErrorSchema.carry/2`.
- Allowlist: none requested.
