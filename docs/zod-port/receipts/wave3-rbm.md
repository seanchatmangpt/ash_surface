# wave3-rbm: pins_test.exs:149 order dependence

Standing: PARTIAL

## Cause (same class as RBO: cross-file module-definition collision)
`AshAuthentication.Errors.InvalidToken` is faked via `Module.create` guarded by
`Code.ensure_loaded?` in two files. `error_type_parity/error_type_parity_test.exs` defined it with
fields `[:field, :message]` (no `:count`); `rbh/pins_test.exs` with `:count`. Whichever ran first
won, so pins A1 got `:count` nil. Not an env/config leak.

## Fix (disclosed, one line)
error_type_parity_test.exs: fields now `[:field, :message, :count]`.

## Evidence (MIX_BUILD_ROOT=_build-rbm, rc un-piped)
- Repro, pre-fix: parity file then pins, `--seed 0`: rc=2, 17 tests, 1 failure (:count nil).
- Post-fix same pair: rc=0, 17 tests, 0 failures.
- Post-fix `test/ash_surface/ported/rpc` seeds 1,2,4: rc=0 (2115 tests each). Seed 3: rc=2,
  1 failure in rbf/exposed_and_type_facts_test.exs (embedded_resource vs struct); file was edited
  concurrently by another lane; unrelated to InvalidToken. UNVERIFIED cause (RBO/RBR class).
- Mutation (in-memory recompile of lib/ash_surface/errors.ex dropping `:count` from the Map.take):
  pins + parity run rc=0 script, 17 tests, 1 failure (A1 left nil right 3). Test still bites.
- Whole `test/ash_surface` seeds 3 and 1: started, killed at coordinator request. UNVERIFIED.
