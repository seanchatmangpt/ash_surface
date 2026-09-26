# chicago-standing-table-029: Standing module exhaustive state table
status: DONE
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
2026-09-17T07:23:03Z | IN_PROGRESS | successor re-dispatch (cold-hold lifted after 32min clean; half-pace cohort 1 of 4; branch preserved — review git log first)
2026-09-17T07:36:36Z | DONE | ~/ash-surface-wt/g29 + exp/chicago-standing-table-29 @ ba184bc (+ f079397 style: pre-existing HEAD-red format fix, 2 untouched files) | predecessor's uncommitted subject tightening reviewed and landed: bare :REFUSED dropped from vocabulary (unnamed refusal = fabricated refusal), :UNKNOWN refused with exact post-dispatch message; state table 41 tests (5 base + 11 witnessed REFUSED_* + synthetic-openness probe + exact boundary/constructor messages for Observation/PlanningEpisode/Event); JS parity rows (STANDING_VALUES -"REFUSED", bare/empty-reason rejection); runtime golden re-frozen to ACTUAL 017c8a2d (predecessor's 1cbcc5cb was stale); falsifier EXECUTED: inject valid?(:REFUSED) -> exit 2 RED (3 failures, all bare-:REFUSED rows), restore byte-identical -> exit 0 GREEN (41 passed); gates: compile --warnings-as-errors 0, mix test 0 (854 passed), npm test 0 (260/260), format --check-formatted 0 (after f079397); 産面 delta: 274+/70- across 6 files, 100% test/subject-twin bytes, zero app-code debt | remaining: none — ready for rider integration (one --no-ff, mix-test-gated)
2026-09-17T07:38:30Z | MERGED 1687493  (rider): --no-ff exp/chicago-standing-table-29 (doc conflict resolved to branch law: bare :REFUSED retired — unnamed refusal = fabricated refusal); 41-test state table; golden re-frozen to ACTUAL runtime digest (predecessor's mismatch caught)
