# chicago-e2e-loop-044: closed-loop e2e extension: state assertions at every stage
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Extend the consumer_fixture e2e: intent -> node runtime dispatch (live HTTP) -> receipt -> Event.from_receipt -> observation -> projector render (one projector) -> on-disk byte assertions; assert END-STATE at each stage (no intermediate-mock bookkeeping). Subject: test/ash_surface/consumer_fixture_test.exs family.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- full-loop test green with >=5 end-state assertions; falsifier: break one stage (e.g., tamper receipt) -> the loop RED at the right stage; gates 0.
## History
