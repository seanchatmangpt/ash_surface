# Lane 06 Receipt

Standing: PASS

## Files changed
- lib/ash_surface/compiler/relationship_schema.ex
- lib/ash_surface/compiler/selection_schema.ex
- test/ash_surface/compiler/relationship_selection_schema_test.exs (new)

## Behavior
- `RelationshipSchema.render_load_schema/2` (opts `max_depth`, default 2) and new
  `render_load_object/2`: per-relationship `z.object({...}).strict()` (no exhaustive z.record),
  inner `fields` = `z.array(z.enum(sorted primitive_fields))` or `z.array(z.string())` when the
  optional "primitive_fields" fact is absent; "one" = `{fields, load?}`; "many" adds
  `filter`/`sort` and a two-arm `z.union` (limit/offset arm vs page arm) so pagination keys are
  mutually exclusive; nested "relationships" facts expand statically to max_depth, no z.lazy.
  Output admitted by `ZodGuard.admit/1`; new errors `:invalid_primitive_fields`,
  `:invalid_nested_relationships`.
- `SelectionSchema.render_selection_schema/3`: optional `relationships:`/`max_depth:` adds
  `load`; 2-arity output unchanged.

## Commands
- `MIX_BUILD_ROOT=_build-lane06 mix test test/ash_surface/compiler/relationship_selection_schema_test.exs`
  exit 0 (tail: `5 tests, 0 failures`). Only that file was run; full suite not run.
- Build dir _build-lane06 deleted.

## Requests
- Lane 17: discovery should feed "primitive_fields" and nested "relationships" facts and pass
  results into IR; `descriptors/1` and `jsdoc/1` unchanged (do not carry primitive_fields).
- Pre-existing warning (not mine): projectors/js/inference.ex:14 heredoc indentation (lane 18).

## Falsifiers
- A many-relationship arm containing both limit and page would fail the test; depth 0 omits load.
