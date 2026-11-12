# L06-zodguard-courts

## Scope

Prove `AshSurface.Projectors.JS.ZodGuard` admits the constraint chains lanes
L04/L05 emit (`.enum`, `.min`, `.max`, `.int`, `.regex`, `.optional()`,
`.nullable()`) and still refuses the injection vectors, extending the grammar
only where a lawful chain was refused.

## Findings

- Enum, numeric bounds, optional/nullable chains: already admitted.
- `z.string().regex(/^[a-z]+$/)` was REFUSED — the grammar had no regex
  literal token. Extended `lib/ash_surface/projectors/js/zod_guard.ex`
  minimally: new `:regex` tokenizer pattern (`/` begins no other token in the
  grammar, so it is unambiguous) plus a `value/1` clause admitting it; zod
  `.regex/1` is the only consumer of a bare regex in the emitted surface.
- Everything in the refusal set refused with typed reasons.

## Grammar extension (disclosed)

```elixir
{:regex, ~r{\A/(?:\\.|\[(?:\\.|[^\]])*\]|[^/\\])*/[a-zA-Z]*}}
```

and `defp value([{:regex, _} | rest]), do: {:ok, rest}`. No other grammar
rule changed.

## Courts

`test/ash_surface/projectors/js/zod_guard_test.exs` — admitted set (plain and
`.optional().nullable()`-suffixed), refusal set (constructor, `__proto__`
member + bare/escaped object key, function literals, arrow literal, template
literals with and without `${`, computed access, non-z root, operators).

## Gate

`mix test test/ash_surface/projectors/` — 66 tests, 0 failures, exit 0.

## See Also

`receipts/L06.md`
