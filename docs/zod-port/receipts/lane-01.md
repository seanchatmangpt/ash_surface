# Lane 01 Receipt: ZodType core

Standing: PASS

## Files changed
- lib/ash_surface/compiler/zod_type.ex (new; `fragment/1,2`, `base/1,2`, `kinds/0`, `unmappable_kinds/2`)
- lib/ash_surface/compiler/schema.ex, projector/expo.ex, compiler/union_schema.ex (private tables removed, delegate to ZodType)
- test/ash_surface/zod_type_core_test.exs, zod_type_parity_test.exs (new)
- test/ash_surface/compiler/schema_section_test.exs, schema_constraint_test.exs (re-pinned to new lawful output; owned via schema.ex)

## Behavior
one_of -> standalone sorted `z.enum([...])` (numeric kinds: literal union; other constraints dropped as Zod cannot chain them);
regex escapes `\` and `/`; uuid `z.uuid()`; decimal/binary/atom string; date/time/datetime/duration `z.iso.*`;
term `z.any()`; vector `z.array(z.number())`; array item recursion via `items`/`item_type`;
allow_nil? -> `.nullable()`, omittable (`optional`/`required?: false`/`default`) -> `.optional()`.
Override hook: `overrides:` opt or `:ash_surface, :zod_mapping_overrides`; verifier `unmappable_kinds/2`
(not yet wired into a compile-time verifier; lane 14/12 may call it).
UnionSchema now emits regex literals (was JSON string) and passes ZodGuard.

## Commands
- `MIX_BUILD_ROOT=_build-lane01 mix test test/ash_surface/compiler test/ash_surface/zod_type_core_test.exs test/ash_surface/zod_type_parity_test.exs` -> 120 tests, 0 failures
- Full `mix test` (earlier run) failures outside lane: ir_test, ir_codec_golden (lane 17 in-flight), ash_r2rml, formatter canary, no_local_do, path_truth.

## Requests
- Lane 20: conformance vectors (constraints.json, ir_codec.json via schema zod) pin old `z.string().enum(...)`; regenerate. conformance_replay_test fails until then.
- Lane 17/14: wire `ZodType.unmappable_kinds/2` into verifier; new `.optional()` semantics change IR schema digests.
- Lane 13/others: expo.ex only delegates; no other changes.

## Falsifiers
Any kind in `ZodType.kinds()` whose fragment fails `ZodGuard.admit/1` (tested for all kinds).
