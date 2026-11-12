# wave3-rav

Standing: PARTIAL

Survivor S5 (wave3-raq): `Support.action_input_field_types/1` was a stub returning nil.

- Reference ash_typescript 5d6e80ae `Custom.action_input_field_types/1` reads a precomputed
  `input_field_types` map built by `Decorator.build_input_field_types/1`: name -> `%Type{}` | nil
  from `action.inputs`. That is identical to the scan fallback in `get_input_field_type/4`,
  so the `types ->` branch is a pure optimization with no distinct behavior (option b).
- Removed: stub in `lib/ash_surface/runtime_parity/rpc/support.ex`; dead branch in
  `lib/ash_surface/runtime_parity/rpc/input_formatter.ex` (scan is now sole path).
- grep proof: `action_input_field_types` has 0 hits in lib/test/conformance/scripts/parity.
- `mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0).
- `mix test test/ash_surface/ported/rpc` rc=2: 1 failure, `ray/calc_branches_test.exs:91`
  (K5 args+nested fields), owner lane RAY; calc loading, not input formatting. UNVERIFIED
  whether pre-existing (no baseline run).
- Not run: mutation shim-court (no branch remains to mutate).
