# L22 Calculations

## Scope

Calculation + aggregate capability parity with ash_typescript: their typed
calculation arguments and loadable calculated fields project to a
Zod-executable load envelope; aggregates contribute nullability metadata
for the output descriptor (JSDoc, not types), via
`AshSurface.Compiler.CalculationSchema`.

## Contract

Facts (atom- or string-keyed; serialized discovery arrives string-keyed):

- calculation: `%{name: String.t(), arguments: [%{name: String.t(),
  kind: base kind atom, constraints: map()}], return_kind: base kind atom}`
- aggregate: `%{name: String.t(), kind: :count|:avg|:max|:min|:sum|:first|
  :exists|:list, field: String.t() | nil}`

`render_calculation_schema/1` emits

    z.record(z.enum(["<name>", ...]),
      z.union([z.object({args: z.object({<arg>: <fragment>, ...})
                             .strict().optional()}).strict(), ...]))

- Unknown calculation fails at the record key; bad or extra argument fails
  via `.strict()`; a zero-argument calculation validates with `args`
  omitted.
- Names/arg names are embedded as JSON string literals (`Jason.encode!`),
  matching SelectionSchema/UnionSchema — non-identifier names are lawful
  and injection-safe; empty/duplicate names are refused.
- Argument fragments reuse the SHARED CONTRACT frozen ordering
  (base -> one_of/min/max/length -> match -> optional().nullable()) and
  base-kind table from `lib/ash_surface/compiler/union_schema.ex`.
- `match` renders through `ZodType.fragment/2` as a regex literal (single
  backslash; only unescaped `/` escaped; PCRE-only patterns omitted with a typed
  warning, `wave2-zt`/`wave3-s1f`). `ZodGuard` admits the regex token (`wave2-zg`).
- Unknown argument kinds degrade to a `z.unknown()` member, never a guess.
- Disclosed limit: `z.record` admits ONE value schema for all keys, and
  per-key discrimination needs function combinators outside the ZodGuard
  grammar — the value is a union of strict per-calculation arg objects
  (two calculations admitting the same arg shape are cross-satisfiable;
  this is narrower than a merged args object, which the charter sketch
  implied).

`render_aggregate_metadata/1` is NOT zod — it emits JSDoc lines surfacing
`T | null` semantics for the output descriptor:

- `:count` -> `{number}` (never null); `:exists` -> `{boolean}` (never null)
- `:avg | :max | :min | :sum | :first` -> `{T | null}` (empty relationship)
- `:list` -> `{T[]}` (possibly empty, never null)

Every zod binary is checked against `ZodGuard.admit/1` before it is
returned (fail-closed, `{:error, {:zod_guard_refused, _}}`).

## Errors

`:calc_facts_empty`, `{:calc_name_invalid, name}`,
`{:calc_name_duplicate, name}`, `{:calc_arguments_not_a_list, name, args}`,
`{:arg_name_invalid, calc, arg}`, `{:arg_name_duplicate, calc, name}`,
`{:calc_facts_not_a_list, other}`, `:agg_facts_empty`,
`{:agg_name_invalid, name}`, `{:agg_name_duplicate, name}`,
`{:aggregate_kind_unknown, kind}`, `{:agg_facts_not_a_list, other}`.

## See Also

`receipts/L22.md` · `lib/ash_surface/compiler/union_schema.ex` (shared
fragment contract) · `lib/ash_surface/compiler/selection_schema.ex`
(JSON-encoded names law) · `lib/ash_surface/projectors/js/zod_guard.ex`
