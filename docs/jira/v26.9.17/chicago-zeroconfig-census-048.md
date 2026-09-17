# chicago-zeroconfig-census-048: zero-config v3 seed: suite census step
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
Extend the fresh-clone battery with a census step: the cloned tree must contain the full chicago suite set (file list pinned) with a test-count floor (mix test line-count >= current); fails closed on removed suites. Subject: scripts/zero_config_v2.sh (v3 step) or a sibling script + TESTING.md note.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- census step runs in the battery and passes on HEAD; falsifier: delete a suite file in the clone -> battery RED (executed); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g48 + exp/chicago-zeroconfig-census-48 | dispatched by coordinator (chicago wave)
2026-09-17T06:04:53Z | REAPED: agent rate-killed [1302] mid-life (12-14min — sustained-overload class, not launch-spike); worktree g48 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
