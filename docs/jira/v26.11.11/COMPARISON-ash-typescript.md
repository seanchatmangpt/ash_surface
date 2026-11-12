# COMPARISON-ash-typescript

Standing: PARTIAL — framing only; verdicts live in `PARITY-REGISTER.md`.

## Framing

Two projects answer the same question — "how does a client know a request
shape is lawful against an Ash resource?" — with opposite mechanisms.

- **ash_typescript = static claims.** Its guarantees are TypeScript types.
  Those types vanish at runtime: a `.ts`-compiled client carries none of them
  on the wire, so the contract cannot be battle-tested against real input.
  A malformed payload that satisfies `tsc` still ships.
- **ash_surface = the only side with an executable runtime contract.** The
  same shapes exist as Zod schemas projected from the IR; admission is an
  executed `safeParse` at runtime, from plain `.mjs`, producing typed refusal
  envelopes. The contract is falsifiable by feeding it input.

This is the milestone's transposition law in comparative form: their
compile-time selectivity becomes our runtime admission (see `OVERVIEW.md`).

## Per-dimension verdicts

Status, evidence and receipts per capability: `PARITY-REGISTER.md` (single source; no
counts or statuses are restated here). Rows where ash_surface is better, each with an
executed court: filter unions are `z.union` because zod 4 throws on repeated
`z.discriminatedUnion` discriminators (`wave2-fl`); `uuid` renders `z.uuid()` (`wave3-s1f`);
Elixir `ConstraintValidator` agrees with real zod on 424/424 cases (`wave3-14`).

## What ash_typescript has that we do not port

Per `README.md` non-goals: no generated `.ts`/`.d.ts`, no `tsc` step, no
AshTypescript dependency. Its static guarantees are deliberately not
reproduced — the runtime admission schema subsumes the check the types were
performing, and remains executable where the types are absent.

## See Also

`PARITY-REGISTER.md` · `OVERVIEW.md` · `README.md` · `_LANES.md` · `receipts/`
