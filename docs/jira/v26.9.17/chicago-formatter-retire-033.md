# chicago-formatter-retire-033: formatter.ex decorative module: wire or retire
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
Mapper 14: lib/ash_surface/formatter.ex registers a plugin for a nonexistent AshSurface.Resource — decorative. Decide by evidence: wire it to the real surface (formatter output state-tested on a fixture) OR retire the module with HANDWRITTEN+UNSUPPORTED pair recording the decision. Either way the Vision-15 necessity law holds afterward.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- module either state-tested with real output rows (>=3) or retired with ledger pair; falsifier: unwired-registration pattern trips the canary/no_local_do-adjacent guard OR removal breaks a now-real consumer; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g33 + exp/chicago-formatter-retire-33 | dispatched by coordinator (chicago wave)
2026-09-17T06:49:55Z | REAPED: cluster death at ~30min (sustained-load grind; 5 simultaneous); branch preserved — successor reviews git log first
2026-09-17T07:23:03Z | IN_PROGRESS | successor re-dispatch (cold-hold lifted after 32min clean; half-pace cohort 1 of 4; branch preserved — review git log first)
