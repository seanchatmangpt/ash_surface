# chicago-pathtruth-anchor-035: path-truth law enforcement anchor
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Mapper 18: TESTING.md:8 states the path-truth law but nothing enforces it. Add test/ash_surface/path_truth_test.exs: parses TESTING.md (and PROJECTORS.md) cited paths, fails on any nonexistent file; allowlist for intentional external refs. Subject: docs + new test.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- anchor test green over all current citations; falsifier: add a fake citation -> RED (executed); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g35 + exp/chicago-pathtruth-anchor-35 | dispatched by coordinator (chicago wave)
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
