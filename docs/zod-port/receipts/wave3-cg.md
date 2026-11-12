# Wave 3 lane CG receipt

Standing: PASS

I09: typed-controller routes in the native manifest.

- `ActionManifest.build/3` option `:routes` adds a `routes` section via `RouteSchema.build/2`.
- 14 route skips in `json_manifest_generator_gap_test.exs` converted to real tests.
- Command: `MIX_BUILD_ROOT=_build-cg mix test test/ash_surface/ported/rpc/b`
- Exit 0: 210 tests, 0 failures, 66 skipped (22 remaining gap skips in this file stay loud).
- Not run: full suite, conformance regen (UNVERIFIED).
