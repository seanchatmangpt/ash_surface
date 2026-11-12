# Wave 3 Lane 05 Receipt (test fixtures)

Standing: PASS

## Files (all new)

- test/support/zod_fixtures/{relations,calc_agg,identity_tenant,paging,mapped_names,typed_containers,harness_ext,routes_router}.ex
- test/ts/fragment_runner.mjs
- test/ash_surface/fixtures/{relations,calc_agg,identity_tenant,paging,mapped_names,typed_containers,harness_ext,routes_router}_fixture_test.exs

## Commands

- `MIX_ENV=test MIX_BUILD_ROOT=_build-w305 mix test test/ash_surface/fixtures` -> 19 tests, 0 failures, exit 0
- `mix test test/ash_surface/no_local_do_test.exs` -> 5 tests, 0 failures
- mock grep over owned files: only hit is Phoenix `patch` route verb (not a mock)

## UNVERIFIED

- Fixtures not yet run through the full compiler/Zod projection for every domain except
  Relations (harness_ext smoke compiles Relations.Domain only).
- Phoenix-absent branch of routes_router untested (Phoenix is present in deps).
- Calc-arg `match` constraint surfaces as `{Spark.Regex, :cache, [src, opts]}`, not `Regex`.

## Requests

- None. HarnessExt.artifact!/1 sets app env `:ash_surface_zod_fixtures_ext`.
