# Lane 16 Receipt

Standing: PARTIAL

## Files
- lib/mix/tasks/ash_surface.install.ex (edited: `--bun` switch, zod/tsconfig steps, npm_install task queued when assets/ exists)
- lib/ash_surface/installer/package_json.ex, lib/ash_surface/installer/tsconfig.ex (new, wrapped in `Code.ensure_loaded?(Igniter)`)
- lib/mix/tasks/ash_surface.npm_install.ex (new; `--bun` selects bun)
- test/ash_surface/installer/installer_test.exs (new)

## Commands
- `MIX_BUILD_ROOT=_build-lane16 mix test test/ash_surface/installer/installer_test.exs` exit 0:
  `3 tests, 0 failures` (create, run-twice identical content, no-assets no-op). _build-lane16 deleted.

## Requests
- Lane 14: lib/ash_surface/config.ex did not exist at run time, so no `configure_new` calls were added
  (no real keys to reference). Add them after config.ex lands (e.g. zod_import_path).
- Not run: the full `mix ash_surface.install` subprocess court (ash_surface_igniter_idempotence_court_test)
  was not re-run after the install.ex edit; UNVERIFIED.

## Falsifiers
- Second run changing assets/package.json or assets/tsconfig.json fails the idempotence test.
- tsconfig with comments (non-JSON) is left untouched, not patched.
