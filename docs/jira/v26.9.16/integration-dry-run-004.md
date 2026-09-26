# integration-dry-run-005: full-suite stability rehearsal
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v42.) Dress rehearsal: full battery 3x (mix test x3, npm test x2), record exits; hunt flakiness (async ordering, shared ETS, tmp dirs — consumer_fixture UUID race is the known suspect); fix ONLY test-infrastructure flakiness, smallest diffs, receipted; verify mix test.all + mix test.zero; stable 0-failure across repeats.
## Acceptance
- three consecutive clean full batteries recorded in History
## History
2026-09-16T19:32:26Z | ALIVE | exp/v42@c914348 (base 282f3ca, commits e25326a+c914348) | mix test x9 =0 (308 passed); npm test x6 =0 (175/175); mix test.all =0 (308+175); mix test.zero =0 x2 (308+175); pre-fix falsifiers: mix test 307/308 exit 2 (consumer_fixture UUID binding), mix test.zero exit 1 (health_deep persistent_term snapshot) | STABLE: 3 consecutive clean full batteries post-fix (9 mix + 6 npm, 0 failures); flake #1 = shared Ash ETS leak of member_zoela_01 across mx/consumer tests (ordered-set UUID find race, fixed by hermetic table reset); flake #2 = async:true global-state snapshot under concurrent mutation (fixed by async:false exclusivity); test-infra-only diffs, 2 files/16 lines, receipts in commit bodies | remaining: none for this ticket — epistatic watch item: health_deep delta was inspect-truncated, exclusivity removes the class rather than naming the last writer
