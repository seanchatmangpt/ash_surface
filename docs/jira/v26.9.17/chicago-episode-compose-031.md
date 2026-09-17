# chicago-episode-compose-031: MXEpisode.compose state + verifier round-trips
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
F4 landed MXEpisode.compose/1. State tests: full episode from real parts (live fixture) -> verifier :ok; each-missing-part refusal table; subject-binding violation row; non-canonical digest row; verify_file/1 on a written episode file. Subject: lib/ash_surface/mx_episode.ex + priv/verifier.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=10 state rows; falsifier: drop observed_transitions witness -> verifier/validate RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g31 + exp/chicago-episode-compose-31 | dispatched by coordinator (chicago wave)
2026-09-17T05:56:53Z | REAPED: agent rate-killed [1302] (storm window); worktree g31 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:39:55Z | DONE | ~/ash-surface-wt/g31 + exp/chicago-episode-compose-31 @ cff0468 (gate-repair 4d0d6cb) | 13 state rows as data (live fixture: real Observation/PlanningEpisode/Event/manifest-admitted Surface, no doubles): happy row compose+validate+verify_file VALID on written artifact; string-key dialect row; 8 missing-part typed-refusal rows; subject-binding violation row; 2 non-canonical digest rows (short + UPPERCASE 64-hex); on-disk-bytes test; typed verify_file failures. FALSIFIER: drop observed_transitions witness from compose/1 -> mix test new file exit 2 RED 0/3 (validate {:missing_fields,[observed_transitions]}, verify_file MISSING_EPISODE_FIELDS) -> git restore -> exit 0 GREEN 3/3. GATES: compile --warnings-as-errors 0; mix test 0 (845 passed = 840+5 doctests); format --check-formatted 0 (after mechanical repair of 2 PRE-EXISTING drifted test files, commit 4d0d6cb); npm test not run (zero JS touched) | remaining: merge exp/chicago-episode-compose-31 (coordinator; never pushed)
