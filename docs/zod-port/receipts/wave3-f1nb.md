# wave3-f1nb

Standing: PASS

## Subject
Lane F1-nodobang. Close the bang-variant hole in test/ash_surface/no_local_do_test.exs
(found in wave3-sknodo.md). Repo working tree, no git state commands run.

## Changes
- `@action_funs` extended with :create!, :update!, :destroy!, :calculate!, :bulk_create!,
  :bulk_update!, :bulk_destroy!, :run_action!, :execute_action! (the last mirrors the existing
  :execute_action). `[:Rewrite, :Source]` allowlist entry kept untouched.
- New test/ash_surface/no_local_do_bang_court_test.exs (3 tests): baseline scratch copy passes;
  scratch copy mutated with all 8 bang funs x {Ash, Some.Api} is flagged (each named in output)
  and restore is sha256 byte-exact then passes again; self-check that a corrupted restore is
  detected. Real `elixir` subprocess over a /tmp copy; no mocks, no sleeps.

## Real-tree result
Tripwire with bang funs: 0 newly flagged lib sites (no lib change needed, allowlist not widened).
lib/ash_surface/runtime_parity/rpc/pipeline.ex compiled green (no BLOCKED).

## Commands
- `MIX_BUILD_ROOT=_build-f1nb mix test test/ash_surface/no_local_do_test.exs`: 5 tests, 0 failures, rc=0
- `MIX_BUILD_ROOT=_build-f1nb mix test test/ash_surface/no_local_do_bang_court_test.exs
  test/ash_surface/no_local_do_test.exs`: 8 tests, 0 failures, rc=0 (final run)
- scratch dirs /tmp/f1nb_* : 0 remaining; _build-f1nb deleted.

## Notes
First court draft timed out at 60s (17 subprocesses); collapsed to one mutation run with
per-fun output assertions and a 300s moduletag timeout.
