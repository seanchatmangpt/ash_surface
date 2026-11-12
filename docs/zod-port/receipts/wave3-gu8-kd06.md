# wave3-gu8-kd06

Standing: PASS

Scope: the KD-06 court only (hand-rolled custom Ash type storage derivation and refusal). Lane-wide
standing is in `wave3-gu8.md`.

- Court: `test/ash_surface/ported/rpc/a/custom_type_schema_test.exs` (node+zod for derived storage;
  refusal assertion plus `ZodType.unmappable_kinds` verifier view for opaque storage).
- Command: `MIX_ENV=test MIX_BUILD_ROOT=_build-gu8 mix test
  test/ash_surface/ported/rpc/a/custom_type_schema_test.exs
  test/ash_surface/ported/rpc/a/embedded_argument_test.exs` -> exit 0, `22 tests, 0 failures`.

## See Also

`wave3-gu8.md` · `docs/KNOWN_DIVERGENCES.md`
