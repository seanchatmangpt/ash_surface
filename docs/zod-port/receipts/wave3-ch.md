# Wave 3 Lane CH: I10 fold argument constraints

Standing: PASS

- Fix: `lib/ash_surface/compiler/route_schema/fold.ex` refuses unknown constraint keys
  (`{:invalid_argument_constraints, route, arg, key, :unknown_constraint}`), validates and folds
  array item constraints (string items get `allow_empty?: false`), folds `trim?: true` default.
- Tests added: 3 in `fold_argument_constraints_test.exs` (unknown key, trim?, item constraints
  with real zod).
- Command: `MIX_BUILD_ROOT=_build-ch mix test test/ash_surface/ported/typed_controller`
  -> 95 tests, 0 failures, 13 skipped (exit status shown by output only; pipe hid rc).
