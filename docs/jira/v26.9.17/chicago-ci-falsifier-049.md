# chicago-ci-falsifier-049: CI runs the falsifier subset
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Wire a bounded falsifier job into ci.yml: runs the mutation-recipe script subset (from chicago-golden-mutation-041) + tripwire canaries, fast (<5min), pins per .tool-versions; actionlint/yamllint clean. Subject: .github/workflows/ci.yml + scripts.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- workflow valid; falsifier subset green on HEAD; falsifier: a known-bad recipe variant -> job RED locally simulated (act or documented); gates 0.
## History
