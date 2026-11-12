# Wave 3 Repair RAE

Standing: PASS

Lane RAE. Repairs SK-mutE2 survivors (receipt wave3-skmute2.md). Test files only; no lib change.
Scratch: /tmp/rae (explicit-path tar incl README.md, node_modules/deps symlinked, build root
/tmp/rae/_b). Restore sha256 byte-exact after each mutation (RESTORE_EQ x4, plus base.sha -c OK).

| survivor | test file (added tests) | scratch mutation | red | live |
|---|---|---|---|---|
| actions sorted desc | rpc/b/json_manifest_generator_surface_test.exs (ascending order) | action_manifest.ex sort_by :desc | rc=2, 1 failure | green |
| manifest_file default | rpc/b/manifest_generator_config_test.exs (defaults nil) | config.ex manifest_file default "x.md" | rc=2, 1 failure | green |
| :complex_type tag | rpc/a/calculation_field_selection_test.exs (2 tests: calc args-no-fields, union member) | field_selector.ex tag :complex_typeX | rc=2, 2 failures | green |
| fold_arguments reversed | typed_controller/fold_argument_constraints_test.exs (3-arg order) | fold.ex drop Enum.reverse | rc=2, 1 failure | green |

Disclosure: argument order is observable only on Fold.fold_arguments output; RouteSchema body zod
is key-sorted and route facts carry no arguments list, so route/zod order assertions are not
possible (zod body asserted to contain all arguments).

## Gates (live tree, MIX_BUILD_ROOT=_build-rae, rc un-piped)

- mix test test/ash_surface/ported/{manifest,typed_controller,top}: rc=0, 650 tests, 0 failures,
  30 skipped.
- mix ash_surface.parity.tests: rc=0, unaccounted=0 broken=0.
- Edited rpc/a and rpc/b files verified green (64 tests, 0 failures) in the targeted run.
