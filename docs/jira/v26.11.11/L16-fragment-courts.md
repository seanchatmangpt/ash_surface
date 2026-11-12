# L16-fragment-courts

Court tests freezing the constraint-aware zod fragment rendering implemented
by L04/L05 in `AshSurface.Compiler.Schema` (`lib/ash_surface/compiler/schema.ex`).

## Contract under court

- `one_of` (non-empty) -> `.enum("a", "b")` on any base kind; empty list
  renders nothing.
- `min`/`max` -> `.min(n)`/`.max(n)` on numeric kinds only.
- `min_length`/`max_length` -> `.min(n)`/`.max(n)` on string kinds only.
- `match` -> `.regex(/<source>/)` on string kinds only, backslashes escaped.
- Frozen chain order: enum -> min -> max -> min_length -> max_length -> regex,
  applied after the base type and before `.optional().nullable()` (allow_nil).
- Absent/empty constraints -> byte-identical legacy fragment.
- NewType inputs: `subtype_of` base fragment + `subtype_constraints` on the
  same chain.
- Constraint maps accepted string- or atom-keyed.

## Courts

`test/ash_surface/compiler/schema_constraint_test.exs` — 16 tests, Chicago
style: every case is a real `Schema.build/1` call over concrete discovery
state, asserted against exact golden input-block lines extracted from the
rendered `IR.Boundary.zod`. No mocks, no stubs, no `lib/` edits by this lane.

One court finding worth noting: numeric `min`/`max` keys present on a string
kind are correctly dropped by the kind gate (only length bounds render) — the
frozen-order golden string encodes this.
