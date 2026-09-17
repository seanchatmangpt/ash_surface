# chicago-select-frontier-030: selection calculus state tables + JS parity
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
F6 landed delegated dimension facts. State tables: preference-dominates-facts; frontier best via cost->latency->privacy with full-tie falling to declared order; absent-facts = legacy law byte-identical; malformed facts typed refusals; JS twin parity rows per table. Subject: lib/ash_surface/transport.ex select/3 + facts_from_profile/1 + runtime.mjs twin.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=12 state rows Elixir + >=6 JS parity rows; falsifier: flip tie-break priority -> frontier rows RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g30 + exp/chicago-select-frontier-30 | dispatched by coordinator (chicago wave)
2026-09-17T05:55:00Z | REAPED: agent rate-killed [1302] at 296s; worktree g30 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:53:43Z | DONE | exp/chicago-select-frontier-30 @ 7eaea9f (parent f0d3577; predecessor landed zero commits — started from clean base) | 29 Elixir state rows (A preference-dominates-facts 4, B frontier-best 8, C absent-facts legacy 4+equality, D typed refusals 9+3 profile) + 12 JS parity rows, all on the real subject; falsifiers EXECUTED: literal axis-order flip (@dimension_priority/DIMENSION_PRIORITY) MASKED 29/29 ex exit 0 + 12/12 js exit 0 (finding: preference short-circuit + order-independent dominance + 2-transport vocabulary make axis order unobservable; recorded as failed edge), effective class-direction flip (rank/1/DIMENSION_RANK) RED ex exit 2 (8 rows A3 A4 B1 B2 B3 B6 B7 D10, 21/29) + js exit 1 (6 rows, 6/12), restore -> GREEN 29/29 exit 0 + 12/12 exit 0, subjects byte-identical to parent; gates 0: compile --warnings-as-errors 0, mix test 0 (871 passed), npm test 0 (270/270), mix format --check-formatted 0 after repairing two PRE-EXISTING HEAD-red files (mx_episode_compose_test, projector_ir_determinism_test — format gate red at parent, same incident class as 50ffcf) | remaining: rider merge only; operator wrote nothing