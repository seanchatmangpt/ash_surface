# L02 IR Contract

Standing: see `receipts/L02.md`.

## Charter

Carry the shared constraint contract through normalization and the IR: `IR.Input`
gains `constraints`/`subtype_of`/`subtype_constraints`; `normalize_action/2` passes
the keys through verbatim from the discovery entry (defaults otherwise); the codec
round-trips them nil-honestly (`%{}` stays `%{}`, `nil` stays `nil`) and stays
JSON-isomorphic. Digest changes are lawful (content-addressed).

## Design

- `lib/ash_surface/ir.ex` — `IR.Input` fields with defaults; `@enforce_keys`
  untouched; types + moduledoc updated.
- `lib/ash_surface/compiler.ex` — both `normalize_action/2` clauses. Manifest
  clause reads constraints from `%Manifest.Type{constraints: keyword()|nil}`;
  raw clause from `%Ash.Resource.Actions.Argument{constraints: []}`. Top-level
  keyword lists flatten to maps (`nil -> %{}`); nested values verbatim.
  `subtype_of`/`subtype_constraints` exist on neither source struct — pure
  `Map.get` passthrough (entry, then map-typed `:type`), honest `nil`/`%{}`
  defaults; nothing re-derived.
- `lib/ash_surface/ir/codec.ex` — ZERO diff: `staged/1` projects structs via
  `Map.from_struct` and `build_section/3` rebuilds generically, so the new
  fields serialize/deserialize structurally; nil-honesty and JSON-isomorphism
  verified by the round-trip and golden suites (no version bump — nothing pins
  codec shape against `@ir_version`; digests carry the change).

## Out-of-owned-file edits (disclosed)

- `test/ash_surface/compiler_coverage_test.exs` — pinned normalized inputs now
  carry the three keys; `constraints` pinned to the real witnessed Ash facts
  (`%{allow_empty?: false, trim?: true}`, array `items` keyword).
- `test/ash_surface/compiler_test.exs` — same three-key update.
- `test/ash_surface/ir_codec_test.exs` — staged Input pin gains the three
  string keys.

## Not done (owner boundaries)

- `Compiler.AshTruth.inputs/1` still constructs `%IR.Input{}` with the four old
  keys — compiles and passes with defaults; populating `constraints` from
  `argument.constraints` belongs to that file's owning lane.
- Nested constraint values may contain keyword lists (e.g. array `items:`) —
  not JSON-isomorphic if they reach `IR.Input.constraints` via a future
  AshTruth change; flagged for that lane.

## See Also

`receipts/L02.md` — gate output and the JS digest-flip check.
