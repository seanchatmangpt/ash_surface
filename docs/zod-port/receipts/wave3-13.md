# Wave 3 lane 13: FieldName / Naming / Mapping

Standing: PASS

## Files
- lib/ash_surface/field_name.ex (custom formatters, validate_formatter/1, :camel/:pascal/:snake aliases)
- lib/ash_surface/field_name/mapping.ex (new: resolve/2, build/1, verify/1, verify_names/2)
- test/ash_surface/field_name_test.exs, field_name_mapping_test.exs (new); naming_test.exs unchanged

## Commands
- `MIX_BUILD_ROOT=_build-w313 mix test test/ash_surface/naming_test.exs
  test/ash_surface/field_name_test.exs test/ash_surface/field_name_mapping_test.exs
  test/ash_surface/no_local_do_test.exs` -> 27 tests, 0 failures, exit 0
- _build-w313 deleted.

## Design
- Custom `{M, :f}` / `{M, :f, extra}` (<= 3 extras) via Function.capture fixed arities; no apply.
  Unknown/wrong-arity -> `{:error, {:invalid_formatter, reason, fmt}}`; compute/2 raises ArgumentError.
- Precedence: type typescript_field_names > resource field_names > formatter; mapped verbatim.
- Typed errors: field_not_found, field_not_invalid, replacement_not_string,
  replacement_invalid_identifier, collision, invalid_formatter.
- parse_input never mints atoms (custom formatters parse the string verbatim, existing atoms only).

## UNVERIFIED
- Mix format result not inspected; no ash_typescript reference suite run (ported by behavior, not
  ported test-for-test: resource-DSL/RPC/aggregate/union suites need resources ash_surface lacks).
- Custom formatters have no inverse: parse_input assumes client name == internal name.

## Requests
- Lanes w3-01/w3-02: wire FieldName/Mapping into js.ex (call `Mapping.build/1`, treat `{:error, _}` as
  a verifier error). Nothing in lib/ calls these yet.
