# chicago-aria-states-046: ARIA projector state table
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
State table: complete type->role mapping, live regions OBSERVE-only, DO-politeness absent, delegated-lookup null fail-closed (F5) pinned as data; emitted JSON fields asserted. Subject: lib/ash_surface/projectors/aria.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=10 state rows; falsifier: emit aria-live assertive on a DO action -> RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g46 + exp/chicago-aria-states-46 | dispatched by coordinator (chicago wave)
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
2026-09-17T07:59:35Z | IN_PROGRESS | successor re-dispatch (cohort 3 of 4; window confirmed by cohorts 1-2 completing 6/6; branch preserved — review git log first)
2026-09-17T08:02:50Z | REAPED: compound evidence — 102min silence (past max observed runtime), 0 active agent processes matched to this worktree, 0 commit(s) preserved — successor reviews first
2026-09-17T08:09:08Z | IN_PROGRESS | successor re-dispatch (final cohort 4; branch preserved — review git log first; 045's lesson: long-runners are alive)
2026-09-17T08:14:56Z | DONE | ~/ash-surface-wt/g46 + exp/chicago-aria-states-46 @ 09e4326 (+be261ef base-format repair, separate commit; predecessor's uncommitted moduledoc start folded in) | 16-row @state_table as data: complete type->role over all 5 Ash types (role verbatim-or-nil, never inferred; integrity test), OBSERVE-only live (default polite, case-normalized, off admitted), DO-politeness absent pinned, F5 null-boundary fail-closed pinned (2 rows delegating a politeness the projector must drop), per-row real project_ir/2 + on-disk .json field asserts (tmp_dir = only injected seam); falsifier EXECUTED: live_hint else-branch %{} -> %{"live" => "assertive"} → mix test aria_projector_test.exs exit 2, 21/36, 15 RED (all DO rows, F5 rows, CONSTRUCT row, both integrity tests) → restore (subject diff 0 lines) → exit 0, 36/36 | gates: compile --warnings-as-errors 0; mix test 0 (861 = 842 base + 19 new); format --check-formatted 0 (2 files drifted at base, mechanical repair be261ef, stash-roundtrip-verified); npm skipped (no JS) | remaining: none
2026-09-17T08:16:22Z | MERGED 68a429f  (rider): --no-ff exp/chicago-aria-states-46; 16-row table + integrity tests; falsifier: live-hint assertive default -> 15 RED (all DO+F5 rows + both integrity guards)
2026-09-17T08:20:50Z | ALIVE (independent verification of the duplicate cohort-4 dispatch) | exp/chicago-aria-states-46 @ 09e4326 (merged 68a429f) | COLLISION witnessed and serialized: live writer (agent_99e1c300) observed mid-falsifier on g46 (aria.ex mutate/restore cycles, 01:11-01:13Z) — held all writes, watched it commit 09e4326 + be261ef instead of double-writing; then independently re-executed: compile --warnings-as-errors exit 0; mix test exit 0 (861 passed); format --check-formatted exit 0; aria_projector_test.exs 36/36; falsifier RE-EXECUTED with own hands: live_hint else-branch %{} -> %{"live" => "assertive"} -> exit 2 (21/36, 15 RED) -> git checkout -- restore -> exit 0 (36/36), tree clean | remaining: none
