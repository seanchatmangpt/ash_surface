# wave3-gu9-kd07

Standing: PASS

Witness receipt scoped to the KD-07 court only (native action manifest
`AshSurface.Manifest.ActionManifest`). Lane-level standing is in `wave3-gu9.md`.

| item | value |
|---|---|
| court | test/ash_surface/ported/rpc/b/json_manifest_generator_surface_test.exs |
| command | `MIX_BUILD_ROOT=_build-gu9 MIX_ENV=test mix test test/ash_surface/ported/rpc/b/json_manifest_generator_surface_test.exs` |
| exit / result | 0 / PASS: 27 tests, 0 failures, 0 skips |
| non-vacuity | shim `inputs == [] -> "none"` replaced by `inputs == [] or true -> "none"`: 27 tests, 2 failures; file restored byte-exact (sha256 equal), rerun 27 tests, 0 failures |
| format | `mix format --check-formatted` on the lib file and rpc/b tests: exit 0 |

## See Also

`wave3-gu9.md` · `docs/KNOWN_DIVERGENCES.md` (KD-07)
