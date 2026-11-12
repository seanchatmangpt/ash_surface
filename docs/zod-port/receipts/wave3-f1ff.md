# Wave 3 Lane F1-floatfmt-b: canonical JS numeric literal

Standing: PARTIAL

PARTIAL because one failure remains in test/ash_surface/compiler/ (filter_schema_facts_test,
`contains` operator ordering), outside this lane's owned files.

## Files

- lib/ash_surface/compiler/number_literal.ex (single JS spelling; wired at zod_type.ex:271)
- test/ash_surface/compiler/number_literal_test.exs (node court: literal parses to identical double)
- test/ash_surface/compiler/schema_constraint_test.exs (float bound now `min(0).max(1)`)
- conformance/vectors/*, conformance/MANIFEST.json (regenerated)

## Divergence decision

ash_typescript interpolates (`min(#{n})`, zod_schema_generator.ex:198), yielding `0.0`.
Ours renders ECMAScript Number::toString (`0`). Code kept; test re-pinned to `min(0).max(1)`.
Executed node+zod court in number_literal_test passes (old and new spellings accepted).

## Commands

- `mix test number_literal_test schema_constraint_test section_schema_constraints_test`: before fix 24 tests, 1 failure (min(0.0)); after fix the schema_constraint failure is gone.
- `MIX_ENV=test mix run scripts/conformance_regen.exs`: rc=0, 788 vectors in 21 files.
- sha256 recheck of MANIFEST.json against 21 vector files: 0 mismatches.
- `mix test test/conformance`: 28 tests, 0 failures. `node conformance/js/replay.mjs`: AGREEMENT 424/424.
- `mix test test/ash_surface/compiler/`: 289 tests, 1 failure (filter_schema_facts, not owned).
- `import Bitwise` not needed: the test uses no Bitwise operators and compiles.

## Notes

w3-01 (IR digest 52edac14) receipt is PARTIAL with the digest documented; regen ran on the
current tree. _build-f1ffb deleted.
