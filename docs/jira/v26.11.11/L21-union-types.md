# L21 Union Types

## Scope

Union type parity with ash_typescript: their `__type: "Union"` wrappers
project to Zod-executable discriminated unions via
`AshSurface.Compiler.UnionSchema.render_union_schema/1`.

## Contract

Facts: list of `%{tag: String.t() | nil, kind: base kind atom, constraints: map()}`
(atom- or string-keyed).

- Primary form (`render_members/2`, ash_typescript wire form): member-keyed
  `z.union([z.object({<member>: <fragment>}).strict(), ...])`; empty -> `z.any()`.
- Tagged API retained (`render_union_schema/1,2`): `z.union([z.object({<discriminator>:
  z.literal("<tag>"), value: <fragment>}).strict(), ...])`. `z.discriminatedUnion` is no
  longer emitted (zod 4 throws on repeated discriminators; see `L09`, receipt `wave2-fl`).
- No common discriminator (untagged primitive members) -> plain `z.union([<fragment>, ...])`.
- Unknown member kinds -> `z.unknown()` member.
- Fragments come from `ZodType.fragment/2` (receipt `wave2-un`): `uuid` -> `z.uuid()`,
  `match` -> regex literal (single backslash), enum -> `z.enum([...sorted])`.
- `render_union_schema_admitted/1` renders then proves the text against
  `ZodGuard.expression/1`, fail-closed (`{:error, {:zod_guard_refused, _}}`).

## Errors

`:union_facts_empty`, `{:invalid_union_fact, fact, index}`,
`{:union_facts_not_a_list, other}`.

## See Also

`receipts/L21.md` · `lib/ash_surface/compiler/schema.ex` (shared fragment
contract) · `lib/ash_surface/projectors/js/zod_guard.ex`
