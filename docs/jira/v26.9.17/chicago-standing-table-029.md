# chicago-standing-table-029: Standing module exhaustive state table
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
F3 landed AshSurface.Standing. State table: every base standing valid; :UNKNOWN rejected with message naming it as post-dispatch outcome; every REFUSED_* accepted; bare :REFUSED rejected; constructor refusals (Observation/PlanningEpisode/Event) fire with exact ArgumentError messages; JS STANDING_VALUES parity rows in test/js. Subject: lib/ash_surface/standing.ex + consumers.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- state table covers all 5 + REFUSED class + boundary messages; zod parity rows; falsifier: admit an invalid standing in one constructor -> new tests RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g29 + exp/chicago-standing-table-29 | dispatched by coordinator (chicago wave)
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
