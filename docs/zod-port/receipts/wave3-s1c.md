# Wave 3 S1-C: FilterSchema size bound and input hygiene

Standing: PASS

## Commands (MIX_BUILD_ROOT=_build-s1c, deleted after)

- `mix test test/ash_surface/compiler/filter_schema*_test.exs test/ash_surface/no_local_do_test.exs`
  exit 0, 35 tests, 0 failures.
- `mix format --check-formatted` on both owned files: exit 0.

## Sizes

- Before (wave-2 receipt): 10-field set at depth 2 = 151,254 bytes; 5 relationships est. ~10 MB.
- After: 10 scalars + 5 relationships (10 dest fields each), default depth 2 = 69,302 bytes
  (cap 1,000,000). ZodGuard.admit/1 returns {:ok, :expression, _} inside a 10 s Task deadline.
- Oversize fixture (120 relationships, depth 3) returns
  `{:error, {:filter_too_large, bytes, 1_000_000}}`.

## Fixed (H3, L5)

- H3: relationship destination rendered at depth 0 (leaves only); hard 1 MB cap with typed error.
- L5: atom `kind` accepted; array items read from entry top level and `type.items`;
  unmapped operators return `{:filter_input_unmapped_operators, name, names}`;
  `"related"` in operators returns `{:filter_input_related_operator, name}`;
  non-map destination entries return `{:filter_input_malformed, list}`.
- Real zod (node) accepts a nested and/not/related filter and rejects an unknown field.

## Files changed

- lib/ash_surface/compiler/filter_schema.ex
- test/ash_surface/compiler/filter_schema_size_test.exs (new)

## Registered, not fixed

- Destination-level logical wrappers (and/or/not inside `related`) are no longer emitted; a
  semantic narrowing, documented in the moduledoc. Leaf copies still repeat per logical arm.
