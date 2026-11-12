# Wave 3 Lane RU Receipt

Standing: PASS

Lane RU (SK-fw2 defects 2, 3, 4). Scratch tree /tmp/ru (explicit-path tar, deps and node_modules
symlinked, `MIX_BUILD_ROOT=_build-ru` inside it). Court:
`test/ash_surface/divergence_close/formatter_scope_errors_tasks_test.exs` (12 tests).

## Changes

- `lib/ash_surface/field_name.ex`: `scoped_formatter/0` resolves the scope of the nearest scoped
  process in `$callers` then `$ancestors` (live process dictionary read, Ecto-sandbox style): Tasks
  and Task.Supervisor children inherit; nothing is copied, so the scope ends with the block or
  the owner. Added `capture_scope/0` + `with_scope/2` (explicit handle for bare spawns).
- `lib/ash_surface/errors.ex`: default formatter is `FieldName.output_formatter/0` (scope, then
  config); the resource-bound namer receives the raw kernel formatter (custom `{m,f}` included) at
  every path depth; error keys derive from it (aliases normalised, custom becomes a 1-arity fn).
- `lib/ash_surface/runtime_parity/rpc/pipeline.ex`: `check_scoped_spellings/2` recurses through
  relationship and embedded destinations and checks filter keys and sort fields (KD-10).
- `docs/KNOWN_DIVERGENCES.md`: KD-10 row (better_because, court, this receipt).

## Evidence

- PASS court run (scratch): `mix test .../formatter_scope_errors_tasks_test.exs` rc=0, 12 tests,
  0 failures. Defect 2 pascal/snake/custom scope fields, path and vars.field equal `FieldName.wire`;
  defect 3 real `Task.async`, `Task.Supervisor.async` and nested Task see the scope, no leak after
  exit, raise or owner crash; defect 4 nested snake/pascal accepted and the other spelling refused.

## Not run

Pre-fix flip of the new court on the unmodified lib: UNVERIFIED.
