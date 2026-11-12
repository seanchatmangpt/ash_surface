# L10 Query Envelopes

Runtime-admission zod envelopes for query pagination and sort, as pure string
renderers in `AshSurface.Compiler.QuerySchema`.

## API

- `render_pagination_schema/0` → `{:ok, zod}`:
  `z.object({limit: z.number().int().positive().max(500), offset:
  z.number().int().min(0).optional(), cursor: z.string().optional()}).strict()`
- `render_sort_schema/1(admitted_fields)` → `{:ok, zod} | {:error, reason}`:
  `z.string().regex(/<pattern>/)` where the pattern admits comma-separated
  `[+]field` / `-field` tokens over the admitted set. Fails closed on empty
  lists and non-identifier field names (never pattern-escapes untrusted
  fields).

## ZodGuard grammar constraint

`AshSurface.Projectors.JS.ZodGuard` admits z-rooted chains with literal
arguments and a lexed regex token (flags subset of `dgimsuvy`, no raw line
terminators; receipt `wave2-zg`). `.refine`/`.superRefine` are NOT admitted.
Zod 4 `.regex("string")` throws at parse, so the sort constraint renders a
regex literal (receipt `wave3-s1f` M2; `wave3-02` converts any residual
string-arg form to `new RegExp(...)` at the embed site, proven by node).

## See Also

- `lib/ash_surface/compiler/query_schema.ex`
- `lib/ash_surface/projectors/js/zod_guard.ex`
- `receipts/L10.md`
