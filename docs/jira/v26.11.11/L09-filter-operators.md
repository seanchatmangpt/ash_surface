# L09 — Zod-Executable Filter Operator Catalog

Renders ash_typescript's typed-filter operator surface as a runtime-admission
zod expression: `AshSurface.Compiler.FilterSchema.render_filter_schema/1` is a
pure string renderer over an action's inputs (IR-shaped entries with
`name`/`type`, string- or atom-keyed), in the same contract family as L10's
`QuerySchema` renderers.

## Emitted shape

```
z.union([
  z.object({field: z.enum(["name"]), op: z.literal("contains"), value: z.string()}),
  ...
])
```

Fields are grouped by type kind; each group renders one union member per
admitted operator, keyed on the `op` literal. The container is `z.union`, not `z.discriminatedUnion`:
zod 4 throws "Duplicate discriminator value" at first `safeParse` when `op` repeats across
kinds (executed court: `filter_schema_executed_test.exs`, receipt `wave2-fl`).

## Operator catalog per kind

| kind | operators |
|---|---|
| string | eq, neq, contains, starts_with, ends_with, in |
| integer / float / decimal | eq, neq, gt, gte, lt, lte, in |
| boolean | eq, neq |
| uuid | eq, neq, in |
| array | has, has_any |
| unknown kinds | eq, neq, in with `value: z.unknown()` |

Value fragments:

- `in` / `has_any` wrap the base fragment in `z.array(...)`; array `has_any`
  wraps the ELEMENT fragment (`z.unknown()`), never the already-array base
  (double-wrap is a defect — caught by this lane's own court).
- array `has` uses the element fragment directly.
- every other operator uses the base fragment from the TWIN `@zod_kinds`
  table (duplicated from `schema.ex:45` per the lane contract — no
  cross-lane imports; drift between the tables is a contract break).

## Grammar confinement

The whole catalog renders as data inside `ZodGuard`'s expression grammar:
member/call chains over literals only. Field names enter as Jason-encoded
JSON string literals inside `z.enum([...])`, so untrusted names (quotes,
backslashes) cannot break out; a `bad"name` field renders admitted as
`z.enum(["bad\"name"])`. Every emitted string is self-checked against
`ZodGuard.expression/1` before `{:ok, ...}` — a renderer/grammar
disagreement surfaces as `{:error, {:guard_rejected, text, reason}}`, never
as unadmitted embedded text.

## Errors (fail-closed)

`:filter_inputs_not_a_list`, `:no_filterable_fields`,
`{:filter_input_missing_name, entry}`, `{:filter_input_missing_type, entry}`,
`{:filter_input_missing_kind, name}`, `{:filter_input_malformed, entry}`,
`{:guard_rejected, text, reason}`.

See receipts/L09.md for the gate output and rendered example.
