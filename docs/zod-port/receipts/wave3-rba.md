# wave3-rba

Standing: PARTIAL_ALIVE

Repair of skeptic survivors in errors.ex and config.ex. New files (landed files untouched):
`test/ash_surface/ported/rpc/rba/{config_defaults_test,error_pins_test}.exs`.

## Evidence

- `mix test test/ash_surface/ported/rpc/rba`: 5 tests, 0 failures (rc 0).
- Mutation by in-memory recompile (`mix do run -r /tmp/rba/mut.exs + test ...`), lib on disk
  unchanged (sha256 prefix before == after: errors.ex 6f13ff7790b6, config.ex 0b4153dd20c3).
  All RED: AuthenticationFailed short message (1 fail); `:key` dropped from Map.take (1);
  always_regenerate (1); not_found_error? (1); phoenix_import_path, typed_controller_mode,
  run_endpoint parity defaults (2 each). Restored: green.
- `mix ash_surface.parity.tests`: rc 0, unaccounted=0 broken=0.

## Notes

- `:key` pinned via Ash.Error.Page.InvalidKeyset (real struct).
- UNVERIFIED: AshAuthentication is not a dependency; the test builds a Splode struct under the
  reference module name, so the real module's behavior is not exercised.
- Equivalents: none claimed.
