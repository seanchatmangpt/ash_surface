# integration-dry-run-005: full-suite stability rehearsal
status: OPEN
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v42.) Dress rehearsal: full battery 3x (mix test x3, npm test x2), record exits; hunt flakiness (async ordering, shared ETS, tmp dirs — consumer_fixture UUID race is the known suspect); fix ONLY test-infrastructure flakiness, smallest diffs, receipted; verify mix test.all + mix test.zero; stable 0-failure across repeats.
## Acceptance
- three consecutive clean full batteries recorded in History
## History
