# wave2-un receipt

Standing: PASS

## Files

- lib/ash_surface/compiler/union_schema.ex (rewritten; header/moduledoc fixed)
- test/ash_surface/compiler/union_schema_test.exs (new, 13 tests)

## Change

- `render_members/2` and `render_members_admitted/2`: ash_typescript wire form
  `z.union([z.object({name: frag}).strict(), ...])`; empty -> `z.any()`; quoted
  non-identifier names; tag field as `z.literal`; opts `:storage`
  (`:map_with_tag` | `:type_and_value`), `:discriminator`, `:max_depth`.
- Members take string/atom kinds or nested definitions (arrays, nested unions with
  depth guard -> `{:error, {:union_depth_exceeded, n}}`); containers go through
  `EmbeddedSchema.render/2` only when `function_exported?/3`, else `z.unknown()`.
- `render_union_schema/1,2` and `_admitted/1,2` kept (tagged `{type, value}`),
  discriminator now configurable.
- Exactly-one-key approximated as union of single-key strict objects (no refine).

## Commands

- `MIX_BUILD_ROOT=_build-un mix test test/ash_surface/compiler/union_schema_test.exs`
  -> `13 tests, 0 failures` (includes real node + zod execution of valid/invalid payloads).
- `mix format` on both files: exit 0. `_build-un` deleted.
- Mock grep over the new test: 0 matches.

## Disclosures

- Compile was blocked ~25 min by another lane's in-flight syntax error in
  lib/ash_surface/projectors/js/zod_guard.ex; I waited (no edit to it), the owner fixed it.

## UNVERIFIED

- Behaviour with the real `EmbeddedSchema.render/2` for container members (only the
  `map` kind exercised; result depends on that lane's implementation at test time).
- Full `mix test` not run (pre-existing VM-exit abort).

## Requests

- test/ash_surface/schema_section_test.exs pins union to `z.unknown`; owner should
  re-pin if the compiler wires `UnionSchema.render_members/2` in (schema.ex/compiler
  integration is outside this lane).
