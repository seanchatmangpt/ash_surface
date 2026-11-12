# Wave 3 F1-kindiv receipt

Standing: PASS

Subject: divergence decisions for the F1-kinds candidates and the F1-floatfmt-b spelling, under
real zod 4.6.5 (node) and real tsc.

## Decisions

- `time`/`time_usec`: accept/reject identical to the reference; reference form
  `z.string().time()` is `@deprecated Use z.iso.time() instead` in zod typings. KEPT
  `z.iso.time()` as KD-03. PASS: court `test/ash_surface/divergence_close/time_kind_divergence_test.exs`.
- `map`/`keyword`/`tuple`/`struct`: runtime identical to reference `z.any()` values, but real
  tsc --strict shows `unknown` values force narrowing where `any` does not. KEPT
  `z.unknown()` as KD-05. PASS: court
  `test/ash_surface/divergence_close/record_value_divergence_test.exs` (3 tests). Matching the
  reference was tried first and rejected: it broke the frozen schema-section canon goldens.
  zod_type.ex and type_kinds_test.exs are therefore unchanged.
- Float constraint spelling `min(0)` vs reference `min(0.0)` (F1-floatfmt-b, wave3-f1ff.md):
  KD-04. PASS: new real-zod test in `test/ash_surface/compiler/number_literal_test.exs`.
- KD ids 03/04/05 taken because both existing rows are currently numbered KD-01.
- parity/court_map.json: divergence entries `type.kind.time|time_usec` (KD-03),
  `type.constraint.min|max|greater_than|less_than` (KD-04),
  `type.kind.map|keyword|tuple|struct` (KD-05).

## Commands

- `mix test test/ash_surface/parity_kinds test/ash_surface/divergence_close
  test/ash_surface/compiler/number_literal_test.exs`: exit 0, 59 tests, 0 failures (final run, incl. the
  KD-05 court); `mix test test/ash_surface/divergence_close/record_value_divergence_test.exs`:
  exit 0, 3 tests.
- Wider run (schema_section tests included): 6 errors in `test/ash_surface/schema_section_test.exs`
  (enum-values goldens); uncommitted edits by other lanes, not touched by this lane.
- `mix ash_surface.parity`: re-run after this file landed; divergence=10 (all 10 KD-03/04/05 ids close); remaining 11 missing are other lanes.

## Files changed

docs/KNOWN_DIVERGENCES.md, parity/court_map.json,
test/ash_surface/divergence_close/time_kind_divergence_test.exs,
test/ash_surface/divergence_close/record_value_divergence_test.exs,
test/ash_surface/compiler/number_literal_test.exs, this receipt.
