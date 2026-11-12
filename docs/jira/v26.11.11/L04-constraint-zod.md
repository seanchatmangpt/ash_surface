# L04-constraint-zod

Standing: ALIVE

## Charter

Constraint-aware Zod fragment rendering in the schema section builder
(`lib/ash_surface/compiler/schema.ex`), coded against the L02 IR contract
(`constraints %{min:, max:, min_length:, max_length:, match:, one_of:}`,
`subtype_of`, `subtype_constraints`; accepted in both string-keyed discovery
form and atom-keyed IR.Input form).

## Ordering law

Superseded by `ZodType.fragment/2` (wave 2, receipt `wave2-zt`): enum is `z.enum([...sorted])`
standalone, `uuid` is `z.uuid()`, `allow_nil?` -> `.nullable()` and omittable -> `.optional()`
(split, not chained), `greater_than`/`less_than` -> `.gt/.lt`. The original L04 chain:
base type → `.enum(...)` → `.min/.max` → length → `.regex(/…/)` → `.optional().nullable()`.

## Rules

- `one_of` non-empty → `.enum("a", "b")` (JSON-encoded members); empty list or
  absent → nothing rendered.
- `min`/`max` render only on numeric kinds (`integer`, `float`, `decimal`).
- `min_length`/`max_length` and `match` render only on string-ish kinds
  (`string`, `uuid`, `utc_datetime`, `datetime`).
- `match` renders as a regex literal with backslashes NOT doubled (`^\d{5}$` →
  `/^\d{5}$/`); only unescaped `/` is escaped (`wave2-zt`). Doubled output was a defect.
- NewType: `subtype_of` names the base kind from the same `@zod_kinds` table;
  `subtype_constraints` ride the identical chain.
- Absent/empty constraints render an empty chain — byte-identical to the
  pre-L04 emission (golden tests in schema_section_test.exs unchanged, pass).

## Examples (hand-rendered)

- integer + `one_of [1,2,3]` + `max 10` → `z.number().int().max(10)` plus enum per `ZodType` (historical L04 form shown)
- string + `min_length 2` + `match "^\d{5}$"` + `allow_nil? true` →
  `z.string().min(2).regex(/^\d{5}$/).nullable()`
- NewType `subtype_of "string"` + `max_length 5` → `z.string().max(5)`

## SLA unblocks applied (disclosed)

1. L21's compile unblock added `@numeric_kinds`/`@string_kinds` as ATOM sigils
   (`~w(...)`a) — kinds are binaries in discovery, so the guards never
   matched; superseded by the owning lane with string sigils.
2. L23's in-flight `test/ash_surface/compiler/filter_schema_test.exs` never
   compiled: paren-delimited `~s(...)` closes at the first `)` in this
   Elixir (verified: `~s(a(b)[c]d)` is a syntax error), and every multi-paren
   literal in that file hit it. Rewrote the literals quote-delimited
   (`~s'...'`), content unchanged from the author's intent.

## See Also

`receipts/L04.md` · `schema_section_test.exs` golden tests · L02 IR contract
