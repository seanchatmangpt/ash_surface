# chicago-golden-mutation-041: mutation-proven golden families
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
Chicago core: prove the golden guards CAN fail. For 3 families (runtime SHA, contract digest, IR codec golden): documented mutation recipes (whitespace injection, field rename) executed in-receipt showing the guarding tests RED, restored GREEN; encode recipes as a scripts/mutation_recipes.md + optional fast script (not wired to default CI). Subject: test goldens + recipes doc.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- 3 families x mutation executed with commands+exits in History; recipes doc committed; gates 0 (mutations restored).
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g41 + exp/chicago-golden-mutation-41 | dispatched by coordinator (chicago wave)
2026-09-17T05:55:59Z | REAPED: agent rate-killed [1302] at 346s; worktree g41 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
