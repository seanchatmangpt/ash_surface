# L20 relationship loads

Lane L20 (v26.11.11): relationship/load capability parity with ash_typescript
(nested field selection + relationship loads), made Zod-executable.

## Law

- Pure renderer under the no-second-discovery law
  (`lib/ash_surface/compiler/schema.ex`): `RelationshipSchema` performs no
  `Ash.Resource.Info` introspection; relationship facts arrive as arguments in
  the established shape (`Projectors.LiveView` /
  `semantic.predicates["relationships"]`):
  `{"name", "destination", "cardinality" => "one" | "many"}`.
- The load envelope keys on `z.enum([relationship names])`, not `z.string()` —
  unknown relationship names fail Zod parse at the boundary (denied_loads
  executable, never reaching the query layer).
- Cardinality/destination exposed as a descriptor map + JSDoc rendering for
  projector consumption.

## Surface

`lib/ash_surface/compiler/relationship_schema.ex`:

- `render_load_schema/1` → `{:ok, zod, descriptors}` | typed errors
  (`:no_relationships`, `{:duplicate_relationship, n}`,
  `{:relationship_without_name, r}`, `:relationships_must_be_a_list`).
- `descriptors/1` → name => `%{cardinality, destination}`.
- `jsdoc/1` → one `// @typedef {SingleLoad|ManyLoad} <name>Load` line per
  relationship (plain comments; never routed through ZodGuard).

Emitted envelope:

```js
z.record(z.enum(["author", "comments"]),
  z.union([z.literal(true),
    z.object({fields: z.array(z.string())}).strict()])).optional()
```

`z.object({fields: ...}).strict()` rejects unknown envelope keys (nested field
selection only); `.optional()` admits an absent load.

## Wiring need (out of this lane's files)

Discovery-side producer: feed `Ash.Resource.Info.relationships/1` facts
(name / destination / cardinality, string-keyed) into
`render_load_schema/1` where the manifest is assembled. The compiler-side
consumption must live in the owning lane's discovery/module files.

## ZodGuard

Every emitted string passes `AshSurface.Projectors.JS.ZodGuard.expression/1`
(no grammar extension required: `z.record` / `z.enum` / `z.union` /
`z.literal` / `.strict()` / `.optional()` / `z.array(z.string())` are all
already admitted). Verified per emission in the receipt's fixture run.

## See Also

`receipts/L20.md` · `L06-zodguard-courts.md` · `L10-query-envelopes.md`
