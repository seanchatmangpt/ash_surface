# chicago-pathtruth-anchor-035: path-truth law enforcement anchor
status: DONE
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
2026-09-17T07:39:37Z | IN_PROGRESS | successor re-dispatch (cohort 2 of 4; window confirmed by cohort 1 completing 3/3; branch preserved — review git log first)
2026-09-17T07:45:23Z | DONE | ~/ash-surface-wt/g35 + exp/chicago-pathtruth-anchor-35 @ 6bfd2d1 (+fdf0cfb format repair) | successor found predecessor's untracked path_truth_test.exs (3/3 green but unformatted) — formatted it; falsifier A: fake citation appended to TESTING.md -> RED exit 2 ("TESTING.md:255 cites missing lib/ash_surface/definitely_not_here.ex"), restore -> GREEN exit 0; falsifier B: existing path falsely marked [INTEGRATION] -> RED exit 2 (stale markers: "a marker path is never an existing gate"), restore -> GREEN exit 0; gates: mix compile --warnings-as-errors 0, mix test 0 (845 passed, 5 doctests = HEAD 842 + 3 new), mix format --check-formatted 0 (HEAD was format-RED on 2 unrelated committed files — repaired atomically in fdf0cfb before the ticket commit); JS untouched -> npm test not required, cross-language e2e green inside mix test | none — remaining: none (rider integrates; never pushed)
2026-09-17T07:46:17Z | MERGED 222fc48  (rider): --no-ff exp/chicago-pathtruth-anchor-35; 331-line corpus-floored anchor (2 falsifiers: fake citation + stale marker direction); predecessor's untracked suite recovered-verified-formatted
