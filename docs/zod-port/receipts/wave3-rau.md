# Wave 3 RAU Repair Receipt

Standing: PASS

Lane RAU closes survivor C2 from `wave3-rap.md`. New file
`test/ash_surface/ported/rpc/rau/calc_required_argument_test.exs`: inline Widget resource and
Domain, calculation `:scaled` with required `:factor` (allow_nil? false, no default). No lib or
fixture edits.

Tests: bare atom, nil args, empty args (error tuples), supplied arg (load spec), wrong-typed arg
(selection passes, real `Ash.read` returns `Ash.Error.Invalid`; valid arg yields 6).

Court `/tmp/rau/court.sh` (build root `_build-rau`, in-place mutate of `field_selector.ex`):
baseline rc=0, 5 tests 0 failures; C2 mutant rc=2, 1 failure; sha256 restore byte-exact
(`restore_eq True`); restored rc=0, 5 tests 0 failures.

`mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
