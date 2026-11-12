# wave2-rs: relationship + selection schema (census lanes 03+08)

Standing: PASS

## Files

- lib/ash_surface/compiler/relationship_schema.ex
- lib/ash_surface/compiler/selection_schema.ex
- test/ash_surface/compiler/relationship_selection_schema_test.exs (exact-string
  assertions updated for `.min(1)`)
- test/ash_surface/compiler/relationship_load_behaviour_test.exs (new; real zod under node)

## Changes

- `pagination` fact: offset | keyset | mixed | none (absent = legacy arms); `count`
  boolean added to many envelope and page objects; `filterable`/`sortable` gating;
  sort admits string | string[]; `fields` `.min(1)`; `exposed:false` omitted at every
  depth; invalid facts give `{:invalid_pagination|:invalid_flag, name}`.
- `z.literal(true)` shorthand kept (divergence documented in moduledoc).
- SelectionSchema: `calculations:`, `aggregates:` (names enum), `allowed_loads`,
  `denied_loads` over relationship paths (prefix semantics, nested paths).
- Facts-shape contract frozen in RelationshipSchema moduledoc.

## Commands

`MIX_BUILD_ROOT=_build-rs mix test test/ash_surface/compiler/relationship_selection_schema_test.exs test/ash_surface/compiler/relationship_load_behaviour_test.exs`
-> `13 tests, 0 failures`. An earlier run was blocked by another lane's transient
compile error in test/support/channel_fixtures.ex (not touched here); it cleared.

## UNVERIFIED

- Aggregates nest as name enum only (not a per-aggregate result schema).
- Offset/keyset pagination for `many` top-level keyset arm omits limit/offset by design.

## Requests

- Discovery producer for relationship facts: `Ash.Resource.Info.public_relationships`
  mapping belongs_to/has_one => "one", has_many/many_to_many => "many", plus
  pagination/filterable/sortable/exposed facts.
