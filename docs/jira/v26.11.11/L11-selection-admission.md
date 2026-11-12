# L11-selection-admission

L11: executable field-selection admission — the `allowed_loads`/`denied_loads`
decision rendered as a Zod schema so a consumer's field selection is validated
mechanically at a boundary instead of by prose policy.

## Law

`AshSurface.Compiler.SelectionSchema.render_selection_schema/2` takes
`admitted_fields` and `denied_fields` (lists of binaries) and returns
`{:ok, binary} | {:error, reason}`:

- denied fields are subtracted from the (order-preserving dedup of the)
  admitted set;
- a non-empty result renders
  `z.object({fields: z.array(z.enum([...]))}).strict()` with field names
  embedded as JSON string literals (`Jason.encode!`), so non-identifier
  names are lawful and injection-safe;
- an empty result (empty admitted set, or a denial that empties it) renders
  the grammar's lawful `z.array(z.never())` equivalent:
  `z.object({fields: z.array(z.never())}).strict()`;
- every emitted binary is checked with
  `AshSurface.Projectors.JS.ZodGuard.admit/1` before it is returned; a
  refusal is `{:error, {:zod_guard_refused, reason}}` — fail-closed, never a
  silent pass;
- non-list inputs or non-binary entries are typed errors
  (`:fields_must_be_binaries` / `:denied_must_be_binaries`).

`.strict()` rejects any key other than `fields`, so the selection object
shape itself is part of the admission.

## Examples

```elixir
render_selection_schema(["name", "email", "notes"], ["notes"])
#=> {:ok, "z.object({fields: z.array(z.enum([\"name\", \"email\"]))}).strict()"}

render_selection_schema(["secret"], ["secret"])
#=> {:ok, "z.object({fields: z.array(z.never())}).strict()"}
```

## See Also

`lib/ash_surface/compiler/schema.ex` (zod emission idiom),
`lib/ash_surface/projectors/js/zod_guard.ex` (admission grammar),
`receipts/L11.md`.
