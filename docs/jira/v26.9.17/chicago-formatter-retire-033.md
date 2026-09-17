# chicago-formatter-retire-033: formatter.ex decorative module: wire or retire
status: DONE
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
2026-09-17T07:31:42Z | DONE | exp/chicago-formatter-retire-33 @ d582fbb (+5547362 fmt-repair) | DECISION: RETIRE (formatter.ex registered never-existent AshSurface.Resource; surface consumes Ash, not a Spark DSL — nothing to wire to); gates: compile --warnings-as-errors 0; mix test 0 (836 passed/0 failed; 6 canary + 4 ledger included); mix format --check-formatted 0 after repairing pre-existing HEAD drift in mx_episode_compose_test.exs (base exit 1, file untouched by branch, 5547362); npm N/A (no JS) | FALSIFIER EXECUTED: retired formatter.ex recreated verbatim -> canary exit 2, TRIPWIRE "nonexistent module AshSurface.Resource — unwired-registration pattern" (5/6) -> rm -> exit 0, 6/6 GREEN; ledger pair HANDWRITTEN row + ontology Row44 (bijection test green); canary formatter_registration_canary_test.exs admitted w/ non-vacuity self-proofs + method guard; remaining: none — ready for rider integration (one --no-ff, mix-test-gated)
