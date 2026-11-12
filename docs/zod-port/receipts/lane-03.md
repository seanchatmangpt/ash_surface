# Lane 03 Receipt

Standing: PASS

## Files changed

- lib/ash_surface/compiler/embedded_schema.ex (new)
- test/ash_surface/compiler/embedded_schema_test.exs (new)

## Commands

- `MIX_BUILD_ROOT=_build-lane03 mix format <both files>` rc=0
- `MIX_BUILD_ROOT=_build-lane03 mix test test/ash_surface/compiler/embedded_schema_test.exs`
  rc=0, tail: `12 tests, 0 failures` (real ZodType from lane 01, real ZodGuard.admit/1)
- `_build-lane03` deleted.

## Behavior

`EmbeddedSchema.render(definition, opts)` -> `{:ok, zod} | {:error, {:cyclic_schema, path}}`.
Fields -> `z.object({...}).strict()`; none -> `z.record(z.string(), z.unknown())`;
allow_nil? -> `.nullable()`; omittable -> `.optional()`; instance_of/resource -> `<Name>Schema`
reference. Embedded cycles via `opts[:resources]`: typed error by default, `cycle_depth: n`
bounds expansion with a record terminal. No z.lazy. Scalars delegate to `ZodType.fragment/1`.

## Requests

- Lane 01/17: route container kinds (embedded_resource, typed_struct, typed_map, keyword,
  tuple, struct with fields) from `ZodType.fragment/1`/schema.ex to `EmbeddedSchema.render/2`;
  `container?/1` is the predicate. Field definitions use `"omittable"` (boolean) for `.optional()`.

## Falsifiers

- Cycle test: removing detection makes `cyclic_schema` test hang/overflow.
- Only unit-level; not wired into IR (lane 17) and not run against real Ash manifests.
