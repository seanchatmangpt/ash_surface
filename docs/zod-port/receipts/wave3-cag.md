# wave3-cag

Standing: PARTIAL

Lane CAG: embedded-filter gaps left by wave3-cae.

## Gates (build root _build-cag, deleted at end)

- `MIX_BUILD_ROOT=_build-cag mix test test/ash_surface/projectors test/ash_surface/compiler`
  rc=0 (un-piped capture), 418 tests, 0 failures, 2 skipped.
- `mix ash_surface.parity.tests`: rc=1 (`unaccounted=0 broken=45`); every BROKEN line seen
  is an `unindexable-dynamic-test` skip in ported test files this lane did not touch
  (e.g. `ported/rpc/a/error_redaction_surface_test.exs`). Pre-existing vs other-lane:
  UNVERIFIED (no baseline run; no stash allowed).
- `mix ash_surface.parity`: rc=1 (`missing=10`), not attributable to this lane's files;
  UNVERIFIED as pre-existing.

## (1) Aggregates on embedded resources

Real Ash (3.33.11) refuses them: compiling an embedded resource with
`count :kid_count, :kids` emits `CAG.Emb.kids is not aggregatable` (and the relationship
itself fails `expects destination field emb_id`); the module still loads with
`public_aggregates != []`. Defect found: `embedded_filter_entries/1` emitted such an
unfilterable `kidCount` entry. Fix: `resource_facts.ex` embedded path no longer includes
aggregate entries (resource-level `filter_entries` unchanged). Court (node+zod, in
`js_embedded_filter_export_test.exs`): Ash error captured from stderr, `n` filterable,
`kidCount` absent from entries and rejected by the zod filter, wrong-typed `n` rejected.

## (2) Parity vs ~/ash_typescript (`codegen/filter_types.ex`)

| behaviour | ash_typescript | ash_surface | verdict |
|---|---|---|---|
| embedded filter source | generic manifest per-resource `{Name}FilterInput`, embedded included | `embedded_filters:` export `<Name>EmbeddedFilterSchema` | equivalent |
| field value typing | `TypeMapper.map_type` TS type (static, erased) | real zod via `EmbeddedSchema` | stronger (runtime) |
| embedded/union/struct/map attr | mapped TS type, exact | typed zod, unrenderable withheld | equal |
| recursion | named TS types, exact at any depth | `cycle_depth: 2` then object-record | WEAKER, see (3) |
| calculations | included if `filterable?` | included | equal |
| aggregates | included if `filterable?` (manifest) | excluded on embedded (Ash cannot define them) | equal (unreachable) |
| same short name | `Helpers.build_resource_type_name` | qualified by module path / `namespace_names` | equal (CAE) |
| `filterable?: false` | skipped | skipped | equal |
| operators | per-field object keys (`notEq`, ...) | `{field,op,value}` union (KD-08) | registered KD |

Reference lib was read at `filter_types.ex` only; other codegen files not re-read
(UNVERIFIED for type-mapper corner cases).

## (3) Self-referential child past depth 2

Decision: KEEP as a documented limit, not a KD (a limit is not better_because, so no KD row).
Tightening needs `z.lazy`/getter declarations inside filter value expressions, which the
embedded filter renderer and ZodGuard do not carry (`render_program` is only wired for schema
declarations). Court (same test file): `child` bare scalar and scalar one level deep
rejected; 6-deep nested object accepted; scalar buried 6 deep accepted (pinned limit; flips
red if tightened, forcing a decision update).

## Files

`lib/ash_surface/compiler/resource_facts.ex`,
`test/ash_surface/projectors/js_embedded_filter_export_test.exs`, this receipt.
