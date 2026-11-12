# Wave 3 CY Receipt

Standing: PASS

## Subject

`mix test test/ash_surface/compiler test/ash_surface/adversarial` (MIX_BUILD_ROOT=_build-cy).

## Findings

- Baseline on the tree at lane start: 437 tests, 2 failures (embedded_schema_test
  "non-identifier field names are quoted"; struct_argument_zod_court_test allow_nil).
- (a) Premise rot, confirmed: default :camel_case emission (`FieldName.emitted/1`, `clean/1`)
  turns `default?` into `default` (no collision, no renderer defect). Re-pinned
  embedded_schema_test.exs to a verbatim `field_names` wire mapping
  (`"default" => "default?"`), which the formatter cannot normalise; still asserts
  `"default?": ` quoted and guard-admits the expression.
- (b) Not reproducible after the baseline: the test is unchanged (I tried a camelCase re-pin,
  reverted; input keys stay `maybe_node` under the verbatim formatter option). The failure
  (member validation of `maybe_node` accepted `{label: 1}`) appeared only while
  F1-fieldwire's `field_name.ex` was mid-edit; passes in isolation and in the full run.
  Classified as transient concurrent-edit state, not a lib defect. No lib edits.

## Commands

- `mix test <compiler> <adversarial>` baseline: 437 tests, 2 failures.
- `mix test embedded_schema_test.exs struct_argument_zod_court_test.exs --seed 491389`:
  30 tests, 0 failures.
- Final: `mix test test/ash_surface/compiler test/ash_surface/adversarial`
  rc=0 (un-piped), 447 tests, 0 failures.

## Disclosure

`lib/ash_surface/field_name.ex` not edited (F1-fieldwire owns it). Only
embedded_schema_test.exs changed.
