# chicago-liveview-states-045: LiveView projector data-state tests
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
State tests over rendered structure maps as DATA: relationships, windowing, defaults, intent-only controls, delegated-authority gating across >=3 authority profiles; assert content fields (not markup internals). Subject: lib/ash_surface/projectors/live_view.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=10 state rows across authority profiles; falsifier: an OBSERVE-violating control in a DO-window -> RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g45 + exp/chicago-liveview-states-45 | dispatched by coordinator (chicago wave)
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
2026-09-17T07:59:35Z | IN_PROGRESS | successor re-dispatch (cohort 3 of 4; window confirmed by cohorts 1-2 completing 6/6; branch preserved — review git log first)
2026-09-17T08:02:50Z | REAPED: compound evidence — 102min silence (past max observed runtime), 0 active agent processes matched to this worktree, 2 commit(s) preserved — successor reviews first
