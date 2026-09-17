# chicago-digest-parity-051: cross-language digest parity tables
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
One parity suite covering EVERY digest-bearing contract (contract, event, observation, episode [after 036], receipt [after 038], IR): JS twin recomputes each from canonical JSON; table per contract. Subject: test/js/digest_cross_language*.test.mjs + elixir fixtures.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- parity table per contract (>=5); falsifier: diverge the JS canonicalizer -> parity RED; gates 0.
## History
