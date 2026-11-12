# Lane 17 Receipt: IR wiring

Standing: PARTIAL

## Files changed
- lib/ash_surface/ir.ex: `IR.Schema` gains `filter, sort, page, capability_flags, response_zod, error`.
- lib/ash_surface/compiler/ir.ex: new `AshSurface.Compiler.IR.Fragments.enrich/2` (read actions only:
  filter via FilterSchema, sort via QuerySchema (input names), page via QuerySchema.render_pagination_schema/1,
  string-keyed flags get/offset/keyset/required/countable, `error` ref = catch_all+shape+types+ErrorSchema.union()).
  `response_zod` stays nil (no record zod carried).
- lib/ash_surface/compiler.ex: normalized action carries `get?` and `pagination` facts; assemble calls `Fragments.enrich`.
- lib/ash_surface/ir/codec.ex: `@schema_fields` extended (sorted) so round-trip stages the new fields.
- lib/ash_surface/projector/ir_entry.ex: entry exposes filter_zod/sort_zod/page_zod/response_zod/capability_flags/error.
- compiler/capability.ex: unchanged (flags live in IR.Schema, since IR.Capability is unowned).

## Commands
- `MIX_BUILD_ROOT=_build-lane17 mix compile` exit 0.
- `mix test` (ir_codec, compiler, compiler_coverage, ir_*, digest_parity, determinism, fuzz codec,
  projectors_coverage, compiler_sections, discovery): 133 tests, 6 failures, all golden pins of the old
  field set/digest (ir_test.exs:24 field list; ir_codec_golden_test: field set, frozen digests, golden JSON x3).
- Full `mix test` aborts mid-run with `NotificationExtension.Dsl.Channel.__struct__/0 undefined` (other lane's
  in-flight channel work), so no full-suite totals. ash_section_truth_test (5 failures) and schema_section_test
  (6) fail from other lanes' edits (Input constraints struct, ZodType array items), not this lane.
- Fragments.enrich smoke on a read action with offset+keyset pagination: all fragments present, error zod emitted.

## Note for lane 20 (digest/vectors)
Every IR digest changes (schema section has 6 new keys; non-read actions get nil fragments plus `error`).
Regenerate ir_codec golden/digest vectors, conformance vectors, reference.mjs; update ir_test field pin
`[:aria,:capability_flags,:error,:filter,:input,:output,:page,:response_zod,:sort,:zod]`.

## Unintegrated
Selection/Relationship (need resource field sets, not in normalized action), Embedded, Route, Channel
(not per-action IR). `response_zod` awaits a record schema.

## Requests
- Lane 20: update golden tests above. Lane 05: sort fragment currently uses input names, not sortable attributes.

## Falsifiers
Two compiles of the same action yield identical Schema structs (inputs pre-sorted; flags/types are fixed-order).
