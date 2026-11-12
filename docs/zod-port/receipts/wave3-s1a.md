# Wave 3 S1-A receipt: calculation and relationship schema defects

Standing: PASS

Scope: H1, M5, M6, L7 (skeptic review w3-20). Own files only.

## Commands (MIX_BUILD_ROOT=_build-s1a, dir deleted afterwards)

- `mix test test/ash_surface/compiler/calculation_schema*_test.exs
  test/ash_surface/compiler/relationship_*_test.exs` -> exit 0, 37 tests, 0 failures
  (36 before the added L7 relationship test).
- `mix test test/ash_surface/no_local_do_test.exs` -> exit 0, 5 tests, 0 failures.
- `mix format --check-formatted` on all owned files -> exit 0.
- Wider `mix test test/ash_surface/compiler` -> 210 tests, 9 failures, all in files
  outside this lane (EmbeddedSchemaTest, SchemaConstraintTest, S1GSchemaCourtsTest,
  SchemaSectionTest, FilterSchemaSizeTest, AshSectionTest); none touch calculation,
  relationship or selection schema. Not triaged here (other lanes' in-flight edits).

## Files changed

- lib/ash_surface/compiler/calculation_schema.ex
- lib/ash_surface/compiler/relationship_schema.ex
- test/ash_surface/compiler/calculation_schema_s1a_test.exs (new)
- test/ash_surface/compiler/relationship_schema_s1a_test.exs (new)
- test/ash_surface/compiler/calculation_schema_args_test.exs (assertions re-pinned)
- test/ash_surface/compiler/relationship_selection_schema_test.exs (assertions re-pinned)

## Defects fixed (courts run real zod 4 under node)

- H1: envelope is now `z.object({"a": <calc>.optional(), ...}).strict()`; `{"a":{}}`
  for calcs [a,b] passes, `{}` passes, unknown key fails.
- M5: per-calculation args binding (each name bound to its own args schema, no union);
  calc A rejects B's args, B rejects A's args. No divergence registered.
- M6: descriptors/1 and jsdoc/1 exclude exposed:false; non-integer or negative
  :max_depth returns `{:error, {:invalid_max_depth, v}}`; many-cardinality base is
  rendered once (strict object + strict exclusivity-union intersection; zod 4
  intersection only reports unknown keys rejected by both sides, so guards are strict
  and name base keys as z.unknown()) removing the 2^d duplication; limit/offset vs page
  exclusivity and unknown-key rejection verified under zod; filter restricted to
  `z.partialRecord(z.enum(known primitive fields), z.unknown())` when primitive_fields
  is present.
- L7: agg_line and RelationshipSchema.jsdoc neutralize `*/` and line breaks; court with
  name `x */ import('//e') /*` asserts no `*/` in output.

## Registered divergences / residuals

- sort remains any string (or array of strings) even when primitive_fields are known:
  Ash sort strings carry direction prefixes (`-name`), so an enum would refuse lawful
  input. Not fixed.
- fields without primitive_fields remains `z.array(z.string()).min(1)` (no field facts
  to restrict to; discovery-side wiring is outside this lane).
- Nested filter without primitive_fields remains `z.record(z.string(), z.unknown())`.

## Blockers

None for this lane.
