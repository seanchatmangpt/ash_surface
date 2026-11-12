# Playground agent notes

Governing doctrine: [../AGENTS.md](../AGENTS.md). The playground only compiles and validates;
it never actuates, never calls a backend, and never emits `.ts`/`.d.ts`. Do not edit the
parent `lib/` from here. Tests are Chicago style: real endpoint, real bun, real zod, no mocks,
no sleeps (bounded deadline polls).

## See Also

[README.md](README.md)
