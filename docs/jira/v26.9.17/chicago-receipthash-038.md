# chicago-receipthash-038: receiptHash formula pinning
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
Mapper 10: receiptHash is shape-only. Pin the FORMULA: canonical-JSON over the named receipt fields (document the field list at the schema site), compute independently in test (and JS twin row) asserting the emitted value; reorder-invariant, value-sensitive.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- formula documented at owner site + independent-computation rows both languages; falsifier: field-order change -> same hash (invariance RED if violated), value change -> different (RED if not); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g38 + exp/chicago-receipthash-38 | dispatched by coordinator (chicago wave)
2026-09-17T06:04:53Z | REAPED: agent rate-killed [1302] mid-life (12-14min — sustained-overload class, not launch-spike); worktree g38 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
