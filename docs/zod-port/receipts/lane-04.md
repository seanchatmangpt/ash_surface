# Lane 04 Receipt: filter_schema

Standing: PASS

## Files changed
- lib/ash_surface/compiler/filter_schema.ex (private @zod_kinds removed; uses ZodType.base/1, kinds/0)
- test/ash_surface/compiler/filter_schema_test.exs (uuid expectation now z.uuid(); 3 new tests)

## Behavior
- Operators from input `"operators"` metadata (fallback: kind catalog); `is_nil` (z.boolean()) added
  when `"allow_nil?" => true` or listed.
- and/or (z.array(inner)) / not (inner) wrappers, pre-expanded to depth 2, no z.lazy.
- Relationship facts: `"relationship" => %{"filter_inputs" => [...]}` -> `op: "related"` variant with
  destination union (leaf-only, depth-capped).
- Output self-checked with ZodGuard.expression/1.

## Commands
- `MIX_BUILD_ROOT=_build-lane04 mix test test/ash_surface/compiler/filter_schema_test.exs`
  -> 8 tests, 0 failures. Build dir removed after.
- Compile warning observed from another lane's file (projectors/js/inference.ex:14 heredoc indent), not mine.

## Requests
- Lane 17: FilterSchema is still unwired into IR.Schema; wire render_filter_schema there.
- Lane 17/06: relationship inputs need the `"relationship"."filter_inputs"` fact shape above.

## Falsifiers
- Output admitted by ZodGuard but Zod 4 rejects nested discriminatedUnion: not run under real node (lane 19).
- Size grows ~4x per depth level; large field sets not size-capped.
