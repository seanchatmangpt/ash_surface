# Wave 3 S3-B2 Receipt

Standing: PASS

## Subject

Repo /Users/sac/ash_surface, working tree (uncommitted, no git state commands run).
Files: lib/ash_surface/compiler/zod_type.ex, test/ash_surface/compiler/zod_type_s3b_test.exs,
test/ash_surface/zod_type_wave2_test.exs.

## Changes this lane

- zod_type_wave2_test.exs: stale uuid_v7 expectation `z.guid()` re-pinned to `z.uuid()`
  (matches ash_typescript; source already carried this). Divergence law: z.guid() would
  loosen, not improve, so no divergence.
- Verified already in place from S3-B: s3b `~w(...)` sigil fixed, `ZodGuard.admit` asserted
  as `{:ok, :expression, _}`, regex scan and coercion tests, and the real-zod uuid_v7 court
  (v7/v4 accepted, non-RFC `12345678-1234-1234-1234-123456789abc` and "nope" refused;
  uuid kind stays guid and accepts the odd one).

## Commands

- `MIX_BUILD_ROOT=_build-s3b2 mix test` on zod_type_s3b, wave2, core, parity, wave3 test
  files (real node + zod 4.6.5, no mocks): exit 0, 61 tests, 0 failures.

## Falsifier

uuid_v7 court fails if z.uuid() stops rejecting the non-RFC odd UUID in real zod.
