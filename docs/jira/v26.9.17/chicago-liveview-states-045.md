# chicago-liveview-states-045: LiveView projector data-state tests
status: DONE
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
2026-09-17T08:05:32Z | post-reap completion (7th false-positive reap; agent finished after 102min reap) — status corrected to DONE
026-09-17T06:41:30Z | ALIVE | exp/chicago-liveview-states-45@00338e7 (ash-surface-wt/g45; gate repair feeb6b6) | mix compile --warnings-as-errors:0; mix test:0 (848 passed = 843 tests + 5 doctests, incl. 6 new state tests in test/ash_surface/projectors/live_view_states_test.exs); mix format --check-formatted:0 (repaired 2 PRE-EXISTING unformatted test files, feeb6b6, verified red at HEAD before repair); npm test: not run (no JS touched); falsifier EXECUTED: action_control/1 mutated to gated=true -> mix test live_view_states_test.exs RED exit 2 (4/6, "OBSERVE control in DO-window: delegated_operator/Ops.Cluster/Ops.Cluster#index"), restored -> GREEN exit 0 (6/6) | none — DONE; witness: 12-row gate state table over 3 authority profiles (delegated_operator/delegated_agent/public_observer); SUBJECT DEFECT FIXED: presentation.widget==nil fell through is_atom(nil) -> to_string(nil)=="" leaving @type_widgets/dead default for zero-config form fields — one nil clause now reaches default_widget/1 (live_view.ex, commit 00338e7); operator wrote: 0 lines
2026-09-17T08:03:39Z | ALIVE | exp/chicago-liveview-states-45@00338e7 (ash-surface-wt/g45) | successor re-witness after mid-life death — predecessor receipt NOT inherited, every gate observed this session: mix compile --warnings-as-errors:0; mix test:0 (848 passed = 5 doctests + 843 tests, incl. 6 new state tests); mix format --check-formatted:0; npm test N/A (no JS touched, no assets dir); falsifier RE-EXECUTED this session: action_control/1 mutated to gated=true -> mix test test/ash_surface/projectors/live_view_states_test.exs RED exit 2 (4/6, "OBSERVE control in DO-window: delegated_operator/Ops.Cluster/Ops.Cluster#index"), restored byte-clean (git diff empty) -> GREEN exit 0 (6/6) | none — DONE
2026-09-17T08:05:55Z | MERGED 96e333b  (rider): --no-ff exp/chicago-liveview-states-45; 12-row gate table over 3 authority profiles; falsifier: OBSERVE-in-DO-window RED; predecessor's 573-line suite recovered + nil-widget subject fix landed
