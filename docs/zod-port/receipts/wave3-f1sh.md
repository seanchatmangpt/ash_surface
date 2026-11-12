# Wave 3 Lane F1-shorthand Receipt

Standing: PASS

Subject: bare calculation selection shorthand (`self: ["id", ...]`), reference parity. Implemented,
not registered as a KD row.

## Changes

- `lib/ash_surface/projectors/js/inference.ex`: `ComplexFieldSelection` accepts the bare fields
  array for a ComplexCalculation with no `__args` or with `{} extends Args` (no required args);
  required-args calculations keep `{args, fields}` only. `InferFieldValue` reads
  `Field[K] extends any[] ? Field[K] : Field[K]["fields"]`.
- `lib/ash_surface/compiler/calculation_schema.ex`: calculations with declared `fields` and no
  required args render `z.union([z.array(z.enum([...])), z.object({...}).strict()])`; objects stay
  strict; required-args calculations render the object form only.
- `test/ts/inference_t17/shouldPass/{structFieldSelection,testStructFieldSelection}.ts`: adapted
  cases use the shorthand (explicit `{args: {}, fields}` form kept as an extra case).
- `test/ash_surface/ported/ts/root/struct_field_selection_test.exs`: new tsc negative-control test
  (shorthand rejected when args required; unknown field rejected; extra key rejected).
- `test/ash_surface/compiler/calculation_schema_shorthand_test.exs` (new): node + real zod courts.
- `parity/test_ledger.json`: `test/ts/structFieldSelection.ts` row `changes` text.

## Commands (MIX_BUILD_ROOT=_build-f1sh, deleted)

- `mix test test/ash_surface/no_local_do_bang_court_test.exs test/ash_surface/ported/ts/root
  test/ash_surface/ts`: 37 tests, 0 failures, exit 0.
- `mix test` calculation_schema{,_args,_s1a,_shorthand}_test.exs: 11 tests, 0 failures.
- `mix test test/ash_surface/compiler` (before the final fix): 291 tests, 2 failures: the shorthand
  test (fixed, rerun green above) and `filter_schema_test.exs:98` (not touched by this lane;
  UNVERIFIED whether pre-existing).

## Conformance (not regenerated)

`conformance/vectors/relationship_loads.json` and `selection_admission.json` contain
`fields: z.array(z.enum` calculation envelopes and may move for calculations without required
args. Not diffed or regenerated; FINAL-REGEN owns.

## See Also

`wave3-t17.md`
