# Wave2 fl: FilterSchema census lane 04

Standing: PASS

## Files

- lib/ash_surface/compiler/filter_schema.ex
- test/ash_surface/compiler/filter_schema_test.exs (updated: union wording)
- test/ash_surface/compiler/filter_schema_executed_test.exs (new, node+zod)
- test/ash_surface/compiler/filter_schema_facts_test.exs (new)

## discriminatedUnion finding (executed)

Real zod 4.6.5 under node 26: the emitted `z.discriminatedUnion("op", [...])`
constructs, then THROWS at the first `safeParse`:
`Error: Duplicate discriminator value "eq"` (zod core schemas.js:1349). The old
renderer repeated `op` literals across kinds and nesting levels, so every
emitted filter schema was unusable at runtime. Fixed: every union is now
`z.union([...])`. Pinned by the executed test (dd throws, z.union accepts).

## Changes

- New kinds: date/time/utc_datetime/utc_datetime_usec/datetime/naive_datetime/atom
  (eq neq gt gte lt lte in), ci_string (string ops + gt..lte); boolean gains `in`.
- `has`/`has_any` element fragment from `items`/`item_type` (map with kind, or kind string).
- Public `operator_key/1` and `split_capabilities/1`; `functions` stays metadata.
- `render_filter_schema/2`: `connectives:`, `max_depth:` (0..3; 4 made the guard exceed 60s).
- `not` takes ONE inner filter (ash_typescript: array); documented.
- `filterable: false` / `filterable?: false` gates fields and relationships.
- Fixed latent bug: `field/2` lookup dropped `false` values.
- Relationship variants kept; error tuples: invalid_max_depth, unknown_connectives,
  invalid_connectives, filter_opts_not_a_list.

## Commands (MIX_BUILD_ROOT=_build-fl)

`mix test test/ash_surface/compiler/filter_schema_test.exs
test/ash_surface/compiler/filter_schema_executed_test.exs
test/ash_surface/compiler/filter_schema_facts_test.exs`
Output: `22 tests, 0 failures` (final run, rc 0 by ExUnit summary).
Size measured: depth 0..3 on a 10-field set = 4898, 26430, 151254, 1067778 bytes.

## UNVERIFIED

- Whole-suite run (aborts at VM exit, pre-existing); only targeted files run.
- Wire format here is a tagged tree; ash_typescript uses a nested map. No
  translator to `Ash.Query.filter_input` was built (non-goal).
- Behavior of z.union error messages for end users (less specific than discriminated).

## Requests

- Producer must build entries from resource fields including calculations and
  aggregates, with `operators` / `functions` / `filterable` / `items` facts.
- Other consumers of FilterSchema output expecting `discriminatedUnion` text must update.
