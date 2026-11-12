# Wave 3 S1-B Receipt

Standing: PARTIAL_ALIVE

## Commands
`MIX_BUILD_ROOT=_build-s1b mix test test/ash_surface/errors_s1b_test.exs
test/ash_surface/error*_test.exs test/ash_surface/no_local_do_test.exs` -> exit 0, 71 tests,
0 failures. `mix format --check-formatted` on errors.ex, error_formatter.ex, error_schema.ex,
config.ex, errors_s1b_test.exs -> exit 0. Build root deleted.

## Files changed
lib/ash_surface/errors.ex, error_formatter.ex, compiler/error_schema.ex,
test/ash_surface/errors_s1b_test.exs (new), errors_test.exs (row 16 re-pinned).

## Fixed
- H2: only @table structs go through known/2; any other struct -> unhandled_error (UUID,
  logged) unless show_raised_errors; module atoms in vars -> last segment (no "Elixir.").
- M14: printable-int lists stay lists; map keys via key/1 (tuple -> inspect); ErrorFormatter
  formats structural + first-level vars/details keys only, user data untouched; handler nil
  drop is logged; whole render/format/output_format path is fail-closed to a generic UUID
  error; ErrorSchema error objects (base/variants) are .passthrough(); field_errors/2 and
  action_field_errors/2 take :formatter, keys match wire (apply_field_names formats via
  formatter).

## Registered, not fixed
- M12: ash_typescript rpc.ex:301 default of require_tenant_parameters is FALSE, so
  config.ex default false already matches. identity_schema.ex:99 (not owned) treats missing
  as required (!= false) and its doc says default true: divergence, owner to align.
- zod_object_mode is read only by config/verifier.ex; no render consumer in owned files:
  registered divergence (unwired).
- Handler nil still drops the error (ErrorHandler documents it); now logged only.

## Collisions
w3-12 receipt existed at start (no wait). Concurrent edits by session ash-surface-39
(errors.ex table() fix, errors_test.exs); preserved. During my run someone re-added
`or Ash.Error.ash_error?` in transform, re-opening H2; I removed it again.
errors_test.exs also edited by another lane (unformatted there; not mine).
