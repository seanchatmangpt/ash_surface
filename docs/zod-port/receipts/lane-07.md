# Lane 07 Receipt

Standing: PASS

## Files changed
- lib/ash_surface/compiler/calculation_schema.ex (private kind table removed; args via
  `ZodType.fragment/1`; `fields` envelope member; `result_kinds/0`; `render_aggregate_schemas/1`)
- test/ash_surface/compiler/calculation_schema_test.exs (new)

## Commands
- `MIX_BUILD_ROOT=_build-lane07 mix test test/ash_surface/compiler/calculation_schema_test.exs`
  exit 0: `2 tests, 0 failures`. `_build-lane07` deleted.

## Requests
- Lane 17: wire `render_aggregate_schemas/1` / calc envelope into IR if desired.
- Aggregate result kinds use ZodType kinds "integer", "float", "boolean"; sum/avg are
  `z.number()` only if ZodType maps "float" so.

## Falsifiers
- Only two tests; no ZodType-constraint edge cases or full `mix test` run (UNVERIFIED).
