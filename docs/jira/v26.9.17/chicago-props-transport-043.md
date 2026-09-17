# chicago-props-transport-043: property-based selection laws
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
StreamData properties over generated fact profiles + transport sets: selected ∈ declared∩available always; preference law preserved when non-dominated; malformed shapes always typed refusals (never raises, never nil). Subject: transport.ex select/3.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- 3 properties with shrinking proven (a falsifier run showing a shrunk counterexample on an injected bug); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g43 + exp/chicago-props-transport-43 | dispatched by coordinator (chicago wave)
