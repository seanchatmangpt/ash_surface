# chicago-codec-canon-034: codec.ex single-canon reconciliation
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Mapper 02: ir/codec.ex:12-14,33 carries a stale parallel five-section canon claim while ir.ex is the admitted canon. Reconcile to ONE canon; state tests: codec round-trips the real five-section IR from a live fixture (both directions), digest pinned equal to fixture surface digest. Subject: lib/ash_surface/ir/codec.ex + ir.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- round-trip + digest state rows on real fixture; stale canon text gone; falsifier: introduce key-order dependence -> digest row RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g34 + exp/chicago-codec-canon-34 | dispatched by coordinator (chicago wave)
2026-09-17T06:11:10Z | REAPED: compound evidence — 0 commits + 22min silence during active storm (10th casualty pattern); worktree g34 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
