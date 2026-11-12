# v26.11.11

## Charter

Capability parity with ash-project/ash_typescript by porting every pattern to
Zod-executable runtime admission. The transposition law of this milestone:

> **Their compile-time selectivity → our runtime admission.**

Every capability ash_typescript achieves by narrowing TypeScript types at compile
time (selection admission, filter/query shapes, constraint vectors) is ported as
a Zod schema that admits or refuses at runtime, executable from plain `.mjs`.

## Non-goals

- No generated `.ts`, no `.d.ts`, no `tsc` emission step. Cite: repo
  `README.md:29` — there is no TypeScript support contract in `ash_surface`;
  AshTypescript is prior art, not an input, authority, or artifact owner.
- No AshTypescript runtime dependency.

## See Also

`_LANES.md` · `receipts/`
