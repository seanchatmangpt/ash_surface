# Wave 2 lane ca receipt

Standing: PASS

## Files

- lib/ash_surface/compiler/calculation_schema.ex (edited)
- test/ash_surface/compiler/calculation_schema_errors_test.exs (new)
- test/ash_surface/compiler/calculation_schema_kinds_test.exs (new)
- test/ash_surface/compiler/calculation_schema_args_test.exs (new)
- test/ts/calculation_schema_runner.mjs (new, real zod executor)

## Changes

- Required args: `args` member is not `.optional()` when any argument is required
  (no allow_nil, no default/has_default; explicit `required` fact wins).
- Aggregates: added `:last`, `:custom` (z.any(), nullable per allow_nil?); sum/avg
  nullable; count/exists/list never nullable; unknown kinds are typed errors.
- `render_calculation_result_schemas/1`: return_kind + allow_nil?; return_ref renders
  the generic resource record (nullable per allow_nil?).
- Complex first/last/min/max/list: `field_definition` delegates to
  EmbeddedSchema.render/2; `union_facts` to UnionSchema.render_union_schema_admitted/1,
  both behind function_exported?.

## Command

`MIX_BUILD_ROOT=_build-ca mix test test/ash_surface/compiler/calculation_schema_test.exs
 .../calculation_schema_errors_test.exs .../calculation_schema_kinds_test.exs
 .../calculation_schema_args_test.exs` -> `16 tests, 0 failures` (exit 0).
First attempt aborted compiling another lane's test/support/channel_fixtures.ex
(pub_sub transform error); passed on retry once that lane fixed it.
`_build-ca` deleted.

## UNVERIFIED

- Complex-result delegation tested only for the EmbeddedSchema map path; the
  union_facts path is not exercised.
- The first-aggregate field_definition kinds beyond map are not covered.

## Requests

- IR/discovery wiring owner: supply aggregate facts (name, kind, field, field_kind,
  allow_nil?, field_definition, union_facts) from Ash.Resource.Info.public_aggregates
  / the manifest; calculation facts need per-argument allow_nil?, has_default,
  return_kind, allow_nil?, return_ref.
