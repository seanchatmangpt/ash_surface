# L05 Expo map_zod_type constraint mirror

Standing: ALIVE

Lane L05 (CONSTRUCT): keep `AshSurface.Projector.Expo.map_zod_type/1`
byte-mirrored with `AshSurface.Compiler.Schema.zod_fragment/1` after L04
extended schema.ex with constraint fragments.

## What changed

`lib/ash_surface/projector/expo.ex`:

- `map_zod_type/1` composes a constraint chain onto the base type BEFORE
  `.optional().nullable()`, in L04's frozen order: `one_of` -> `min`/`max`
  (numeric kinds only: integer/float/decimal) -> `min_length`/`max_length`
  (string kinds only: string/uuid/utc_datetime/datetime) -> `match` (string
  kinds only).
- Constraints ride the definition top level (`def["constraints"]`), accepted
  string- or atom-keyed (L04's canonical shape; my first cut put them under
  `type["constraints"]` and was reconciled to L04's shape after it landed).
- NewType clause mirrored: `%{"subtype_of" => kind, "subtype_constraints" => …}`
  renders the subtype base plus the same chain, no optional/nullable.
- `match` escapes backslash AND `/` (coordinator relay from L04/L14:
  `match: "a/b"` must render `.regex(/a\/b/)`; first cut escaped only
  backslashes — fixed and disclosed in the receipt).

## Byte-mirror court (throwaway, /tmp/l05_mirror.exs — scripts/ not owned)

12 representative constrained IR defs driven through BOTH public APIs:
`AshSurface.Compiler.Schema.build/1` (zod emission in the IR boundary) and
`AshSurface.Projector.Expo.project_ir/2` via a hand-built
`AshSurface.Surface` (digest verified through the real
`AshSurface.contract_digest/1` path). Result: 12/12 identical strings,
including enum, enum+allow_nil, length bounds, `^\\d+$` regex, `a/b` slash
regex, numeric bounds, kind-gated ignored constraints (min_length/match on
integer), float bound, plain uuid, empty one_of (renders nothing),
atom-keyed constraints, and the subtype_of NewType.

## Dedup suggestion (not extracted — shared helper lives outside owned files)

The kind table, guard kinds (`@numeric_kinds`/`@string_kinds`), and the whole
constraint chain are duplicated verbatim between `compiler/schema.ex` and
`projector/expo.ex`. A shared `AshSurface.ZodFragments` module both import
would collapse ~90 duplicated lines and make drift structurally impossible.
Coordinator owns that extraction; until then the mirror court above is the
drift detector.

## Pre-existing failure (not this lane)

`test/ash_surface/projector/expo_receipts_hash_test.exs`: the committed
`@golden_hash` (`bde4078a…`) does not equal the sha256 of the test's own
`@expected_preimage` literal (actual `9c93b831…`) — the setup self-assert
fails for all 5 tests. File unmodified since commit 061b1e9a6; my diff cannot
affect a pure-literal assert. Ticketed for the owning lane.

## See Also

`receipts/L05.md` · L04 (schema.ex constraint fragments) · schema.ex header
law ("drift between the two is a contract break")
