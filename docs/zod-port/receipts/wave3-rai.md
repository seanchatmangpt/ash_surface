# wave3-rai

Standing: PARTIAL

Lane RAI (repair of vacuous tests from `wave3-skmute1.md`). Live build root `_build-rai`; shim-court
in scratch `/tmp/rai` (explicit-path tar copy, node_modules+deps symlinked, build root `/tmp/rai/_b`).

## Files

- `test/ash_surface/ported/rpc/c/output_field_formatting_surface_test.exs`
- `test/ash_surface/ported/rpc/c/private_arguments_ir_surface_test.exs`
- `test/ash_surface/ported/rpc/c/rpc_field_argument_mapping_surface_test.exs`
- `test/ash_surface/ported/rpc/e/ts_runtime_validation_surface_test.exs`
- lib (disclosed): `lib/ash_surface/error_formatter.ex` `format_name/2` gained `{m,f}` / `{m,f,args}`
  clauses delegating to `FieldName.compute/2` (a custom formatter raised CaseClauseError there).

## Baseline red cause (private_arguments_ir)

The 2 reds (`assert error_schema =~ camel(pub)`) were the test, not lib: `setup_all` compiled under
`AshNames.with_verbatim` (identity formatter pin), so `validation_error` keys are snake_case while
the test expected camelCase. Fix: validation-error cases now compile per formatter
(camel/snake/pascal/custom) and assert the exact formatted public key plus absence of the private
name in every spelling. The reference omits `public?: false` arguments; that still holds.

## Verification (live, rc un-piped)

- `mix test <4 files>` exit 0, 66 tests, 0 failures (`/tmp/rai_live.log`).
- `mix ash_surface.parity.tests` exit 0, `unaccounted=0 broken=0` (`/tmp/rai_parity.log`).

## Shim-court (scratch, sha256 baseline == restore for every row, scratch baseline 66/0)

| id | mutation | result |
|---|---|---|
| A | field_formatter mapped name downcased | RED 6 |
| B | output_formatter key -> `to_string(internal_key)` | RED 13 |
| C | FieldName camel -> pascal | RED 19 (incl. private-args key test) |
| D | FieldName snake -> camel | RED 3 (incl. private-args key test) |
| F | ErrorFormatter custom clauses removed | RED 1 |
| G | zod integer `.int()` dropped | RED 1 (node+zod) |
| H | zod `.regex` dropped | RED 1 (node+zod) |
| E | `mapped_argument_name` lookup disabled | SURVIVED (green) |
| L | validation_error formatter -> `to_string/1` | SURVIVED (green; formatter applied upstream, likely equivalent) |
| P | FieldName pascal -> camel | RED 3 (incl. private-args key test) |

Argument-name mapping coverage is PARTIAL: `format_input_name` / `mapped_argument_name` is not
exercised by these tests (input parse resolves `isActive` through another path).

## Observations (not fixed)

- Under `with_formatter(:snake_case | :pascal_case)` a mapped field name (`"addressLine1"`) is
  refused as unknown field; under `:pascal_case` mapped argument `"isActive"` is dropped from input.
  Tests pin only the camel/snake cases that hold. A custom `{m,f}` formatter has no input inverse
  by design; covered output-side only.

## Cleanup

`_build-rai` deleted; `/tmp/rai` scratch retained for coordinator.
