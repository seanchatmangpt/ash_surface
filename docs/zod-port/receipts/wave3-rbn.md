# wave3-rbn

Standing: PARTIAL_ALIVE

Lane RBN repairs skeptic survivors from wave3-skmutj. New files only:
`test/ash_surface/ported/rpc/rbn/scoped_spelling_survivors_test.exs` (9 tests) and
`calc_args_nested_paths_test.exs` (6 tests). Real inline resources, real parse pipeline,
camel/snake/pascal scopes, relationship scope, nested calculations.

## Shim-court
Mutations applied in memory (`mix do run /tmp/rbn/shim.exs + test`, compile_string); lib sha256
of pipeline.ex, field_selector.ex, support.ex identical before/after (SHA_IDENTICAL).
- E1, E2, E4, E5: RED (assert unknown_field) -> killed.
- H4, H6, H7: RED at nested path [:gadget] -> killed (were unresolved).
- E6: 9 tests green under mutation -> EQUIVALENT. `mapped_argument_name/3` returns a binary
  or `input_name`; so `cond` branch `true ->` is unreachable (binary hits branch 1, equal hits
  branch 2).

## Gates
- `mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0).
- `mix test test/ash_surface/ported/rpc` rc=0 un-piped: 2108 tests, 0 failures, 213 skipped.
- `mix test .../rbn`: 15 tests, 0 failures.

Not run: other lanes' survivors. `/tmp/rbn` and `_build-rbn` cleanup pending below.
