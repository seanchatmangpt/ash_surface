# Lane 08 Receipt

Standing: PASS

## Files
- lib/ash_surface/ir/error_shape.ex (closed 15-type enum, normalize_type, new/2)
- lib/ash_surface/compiler/error_schema.ex (base, variant/1, variants/0, union/0 with
  unknown_error last, field_errors/1, action_field_errors/1, render/1 ZodGuard-proven)
- test/ash_surface/error_schema_test.exs

## Commands
- `MIX_BUILD_ROOT=_build-lane08 mix test test/ash_surface/error_schema_test.exs` exit 0:
  `5 tests, 0 failures` (pre-existing heredoc warning from projectors/js/inference.ex, not mine).
- `_build-lane08` deleted.

## Requests
- Lane 17: add IR field for the error contract (e.g. `IR.Schema`/entry `errors` from
  `ErrorSchema.render/1`, per-action fields from action input names) and digest handling.
- Lane 09: runtime error `type` strings should go through `ErrorShape.normalize_type/1`;
  wire field is `shortMessage` (camelCase).

## Falsifiers
- Not run under real node/zod (no `parse` of error payloads); only ZodGuard admission + string checks.
