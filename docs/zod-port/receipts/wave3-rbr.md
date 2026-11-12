# Wave 3 RBR: test-module isolation court

Standing: PASS

Court: `test/ash_surface/test_module_isolation_court_test.exs` (4 tests). AST via
`Code.string_to_quoted` (TestIndex has no module-reference surface; walk is local). Flags any
test/**/*.exs reference (aliases, remote calls, structs, use/import, `:"Elixir.X"`) to a
module defined only in another test file. lib/ and test/support (mix.exs
`elixirc_paths(:test)`) are lawful; a `Code.require_file("x", __DIR__)` makes x's modules own.
Allowlist `@allowlist` is empty (entries need a justification).

Findings fixed (test-only, each file green alone):
- `AshPostgres.Ltree` (defined in rpc_run_action_ltree_surface_test.exs, used by
  exotic_type_facts_test.exs): moved to `test/support/ash_postgres_ltree.ex`.
- `Rbg.Fmt` used by divergence_close/custom_formatter_result_test.exs: own `tag/1` added to
  its local `CustomFormatterResultFmt`.
- adversarial `S2` (support.exs): lawful, explicit require_file; court models it.
- rbh/pins_test.exs: no finding on current tree (RBM-owned, untouched).

Commands (rc un-piped): `mix test test/ash_surface/ported/rpc` rc=0, 2116 tests, 0 failures,
213 skipped; court rc=0, 4 tests; `mix ash_surface.parity.tests` rc=0 (unaccounted=0,
broken=0). Non-vacuity: planted two scratch test files on the real tree, court rc=2 naming
file:line and owner; removed, rc=0. Unit planting also in-court.
