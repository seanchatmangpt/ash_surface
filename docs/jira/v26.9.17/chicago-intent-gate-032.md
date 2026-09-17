# chicago-intent-gate-032: intent KNOWN-ness gate state transitions
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
F2 landed the pre-bus gate. State table: in-set id reaches bus (count 1); out-of-set refuses pre-bus (bus count 0); empty set admits nothing; malformed set typed refusal; no-key = no gate byte-identical. Subject: lib/ash_surface/intent/dispatch.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=6 state rows with bus-call counting (the law IS the boundary); falsifier: remove the gate -> out-of-set row RED; gates 0.
## History
