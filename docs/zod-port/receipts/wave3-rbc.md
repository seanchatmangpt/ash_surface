# wave3-rbc

Standing: PASS

Lane RBC repairs skeptic survivors Z-e, Z-f, Z-g, Z-h (receipt wave3-skmuth.md).

## Tests added
test/ash_surface/rpc/rbc/zod_branches_test.exs (4 tests, real emitted text plus node+zod):
- Z-e: "any" emits exactly z.any().
- Z-f: `s` flag kept; dotAll accepted under zod ("a\nb" passes, "ab" fails).
- Z-g: ci_string base is exactly z.string(); zod rejects 1 and nil.
- Z-h: RouteSchema.build refuses non-binary match_flags, accepts "i".

## Shim-court (in-memory recompile of scratch copies in /tmp/rbc; shared lib never mutated)
Baseline rc=0, 4 tests, 0 failures. Each mutation: 1 failure (killed). Restore:
sha256sum -c OK for zod_type.ex and fold.ex; rerun 4 tests, 0 failures.
No equivalents. Z-e is killed by exact-source assertion (z.any vs z.unknown both accept
every payload at runtime).

## Gate
`mix ash_surface.parity.tests`: rc=0 (unaccounted=0, broken=0). Build root _build-rbc deleted.
