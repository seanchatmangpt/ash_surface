# wave3-cm

Standing: PARTIAL

Lane CM, item I15: `lib/ash_surface/parity/court_map.ex` reads `exclude:` from
`test/test_helper.exs` (`excluded_tags/1`); a court whose test carries an excluded tag is a
hard non-pass (`EXCLUDED`). Witness court: `test/ash_surface/parity/gate_non_vacuity_test.exs`
court (g) (test_helper exclude shim).

Recorded by the lane CM report (not re-run by this receipt's author, UNVERIFIED here):

- `mix test test/ash_surface/parity` rc=0, 50 tests, 0 failures
- parity summary unchanged: pass=302 divergence=12 non_goal=79 broken=0 missing=10

Follow-up (lane CS, wave3-cs): tag detection moved from text scan to AST (`tags` exposed by
`AshSurface.Parity.TestIndex`); lane CS run: `mix test test/ash_surface/parity` rc=0,
51 tests, 0 failures (court g2 added); `mix ash_surface.parity.tests` rc=0, unaccounted=0.
