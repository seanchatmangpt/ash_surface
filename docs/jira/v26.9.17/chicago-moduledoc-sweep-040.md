# chicago-moduledoc-sweep-040: stale-claim comment sweep + tripwire
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Mappers 05/14 residuals: lib/ carries transition/existence claims (pattern: 'does not exist yet', 'until X lands', 'on no branch'). Sweep every hit in lib/ — correct or prove-current; add a lightweight tripwire test grepping lib/ for the stale-claim patterns with an explicit allowlist of proven-current mentions.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- sweep clean + tripwire green with allowlist; falsifier: add a stale claim -> tripwire RED (executed); gates 0.
## History
