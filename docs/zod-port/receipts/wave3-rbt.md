# Wave 3 RBT: duplicate-definition court and order-dependence sweep

Standing: PARTIAL

## Court extension (test/ash_surface/test_module_isolation_court_test.exs, now 6 tests)
New `def_sites/1` + `definition_findings/2`: defmodule (incl. inside quote/eval_quoted bodies),
`Module.create/3` (literal alias, `Module.concat([..])`, or `@attr` bound to one),
`Code.eval_string/compile_string` literal binaries. Finding = same name in >=2 files (test
files plus lib/ and test/support), or any `Code.ensure_loaded?`-guarded definition in a test
file (reported with `fields:`). Lib-internal if/else definitions in one file are not flagged.

## Findings fixed (test-only)
- `AshAuthentication.Errors.{AuthenticationFailed,InvalidToken}`: three guarded `Module.create`
  fakes (error_type_parity_test, rbh/pins_test, rba/error_pins_test; field lists differed) ->
  one shared `test/support/ash_authentication_fakes.ex` (fields union
  `[:field, :message, :count]`); the three setup_all blocks removed (RBM one-liner superseded).
- presentation_section_test.exs: dead guarded fake of lib's `Compiler.Presentation` removed.

## Evidence (MIX_BUILD_ROOT=_build-rbt, rc un-piped)
- Court + presentation test: rc=0. Each of the 3 touched files alone: rc=0.
- Non-vacuity: planted test file with duplicate `Module.create(InvalidToken)`: court rc=2,
  "DUPLICATE ... zz_rbt_plant_test.exs:2 (module_create); test/support/...fakes.ex"; removed,
  rc=0. In-court unit plants also cover defmodule/eval_quoted/guarded.
- `test/ash_surface/ported/rpc` seeds 3,5,6,7,8: rc=0 each, 2116 tests, 0 failures, 213 skipped.
  Seed 3 rbf `embedded_resource` failure did not reproduce (RBO's local Rbf.Emb holds).
- Whole `test/ash_surface` seed 0: rc=2, 48 doctests, 23 properties, 5765 tests, 6 failures,
  267 skipped (floor basis: 5759 passing). Seeds 1,2,3: UNVERIFIED (coordinator stopped sweep).
- Failures 2-6 STALE (not order): lib FieldName now keeps trailing `?` (RBS, field_name.ex
  07:51) but field_formatter_struct_clause_test, typescript_field_names_precedence_test and
  projectors/js_mapped_fields_test (3) still expect stripping; owners must re-pin.
- Failure 1 private_arguments_surface_test.exs:53 `action_not_found create_org_todo`: passes
  in rpc-only seeds, fails whole-run seed 0: order-dependent, root cause UNVERIFIED, unfixed.
- `mix ash_surface.parity.tests` rc: UNVERIFIED (not re-run after this change).
- Build dirs deleted.
