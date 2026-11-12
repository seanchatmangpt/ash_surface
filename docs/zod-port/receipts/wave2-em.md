# Wave 2 Receipt: em (EmbeddedSchema)

Standing: PARTIAL

## Files

- lib/ash_surface/compiler/embedded_schema.ex (owned)
- test/ash_surface/compiler/embedded_schema_test.exs (owned)
- DISCLOSED UNBLOCK (not owned): lib/ash_surface/projectors/js/zod_guard.ex line 74, the
  `~r{...\x{2028}...}u` regex used `{}` delimiters containing `\x{..}` and failed to compile
  (SyntaxError) for ~10 min; changed delimiters to `~r'...'u` only. Owner lane should supersede.

## Changes

1. struct + non-resource instance_of + no fields => `z.object({})`. Non-resource is declared
   by `"resource?" => false` on the type or `opts[:non_resources]` (list of names); default
   (unflagged instance_of => `<Name>Schema`) unchanged.
2. One `.optional()`: omittable = omittable | optional | required?==false | default key;
   suffix-checked so ZodType's own `.optional()` is never doubled.
3. `array` with container `items` (or `item`, bare type map or definition) => `z.array(<c>)`,
   nests; `container?/1` true for such arrays.
4. Map-form fields: sorted by name; list-form: declared order. Documented in moduledoc.
5. `union` delegates to `UnionSchema.render_members/2` (called as `(type, opts)`, expects
   `{:ok, str}`) when `function_exported?`; else falls back to ZodType.fragment.
6. `opts[:schema_suffix]` (default "Schema").

## Commands

- `MIX_BUILD_ROOT=_build-em mix test test/ash_surface/compiler/embedded_schema_test.exs`
  -> `24 tests, 0 failures` (exit 0). Includes node + real zod execution of an emitted
  nested object/array schema (good passes; extra key, bad nested, bad array, missing fail),
  ZodGuard.admit on every emitted string, no literal ZodType bytes pinned.

## UNVERIFIED

- `render_members/2` delegation never exercised with a real UnionSchema.render_members (absent
  at run time); signature `(type_map, opts)` is an assumption.
- Full `mix test` not run (pre-existing VM-exit abort).

## Requests to other lanes

- ZodType/compiler routing: route kinds embedded_resource/typed_struct/typed_map/struct/array-of-
  container/union through `EmbeddedSchema.render/2` (`container?/1` is the predicate).
- Discovery must carry `fields`, `instance_of`, `resource?`/non-resource flag, array `items`.
- UnionSchema lane: export `render_members(type, opts)` returning `{:ok, zod}`; opts carry
  `:resources`, `:cycle_depth`, `:schema_suffix`.
