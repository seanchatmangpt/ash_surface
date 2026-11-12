# Wave 3 Lane 14: Elixir constraint validator

Standing: PASS

## Files (new)

- lib/ash_surface/compiler/constraint_validator.ex
- test/ash_surface/compiler/constraint_validator_test.exs
- test/js/constraint_validation_agreement.test.mjs (node driver; no-op without args)

## Commands

- `MIX_BUILD_ROOT=_build-w314 mix test test/ash_surface/compiler/constraint_validator_test.exs
  test/ash_surface/no_local_do_test.exs` -> exit 0, `7 tests, 0 failures`,
  `AGREEMENT 424/424` (real zod 4.6.5 under node; static table plus 300 seeded
  property cases over string length / int+float bounds).
- `node test/js/constraint_validation_agreement.test.mjs` -> exit 0 (no-op).

## Findings during agreement

- Zod 4.6.5 counts string length in code points, not UTF-16 units; validator fixed to match.
- Unmapped kinds render `z.unknown()`; atom values JSON-encode to strings; validator matched.
- No ZodType emission defects found (no requests).

## UNVERIFIED

- Issue code/path agreement with zod beyond verdict (shape asserted only on Elixir side).
- PCRE-vs-JS regex semantic differences beyond simple patterns; custom overrides.
- Not run: full `mix test` (VM-exit abort).

## Requests

- Wire into conformance Tier B vectors (lane w3-04 owns conformance/**).
