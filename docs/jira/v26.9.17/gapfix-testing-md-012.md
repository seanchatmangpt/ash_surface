# gapfix-testing-md-013 note: land AFTER gapfix-adapters-001 if counts shift
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
TESTING.md truth pass: 20 paths marked [INTEGRATION]/absent that exist at HEAD (zero_config_v2.sh, ir_test, compiler_test, all section tests, no_local_do "defined nowhere" vs test/ash_surface/no_local_do_test.exs:229); counts frozen at 308/175 vs receipted 725/217; battery order documented mix-first but the scripts require npm-first (zod import, consumer_e2e_runner.mjs:4); suite map rows for landed files. Soft-order: if gapfix-adapters-001 changes suite counts, land after it and use final numbers.
## Acceptance
- zero false [INTEGRATION] rows; counts match `mix test`/`npm test` at landing SHA; battery order npm-first everywhere; mix test 0.
## History
2026-09-17T00:09:51Z | IN_PROGRESS | ~/ash-surface-wt/g12 + exp/gapfix-testing-md-012 | dispatched by rider (target_n=9; 012's soft-order on 001 satisfied — 001 MERGED)
2026-09-17T00:23:18Z | ALIVE | exp/gapfix-testing-md-012 @ 741ec09 | mix compile --warnings-as-errors=0; mix test=767 passed/0F exit 0; npm test=220/220/0F exit 0; mix format --check-formatted=0 | none — premise verified true (all 20 [INTEGRATION]/absent citations false at HEAD), counts unfrozen to measured 767 tests/68 files + 220 tests/16 files at landing SHA, battery order npm-first per consumer_e2e_runner.mjs:4, suite-map rows added for all landed v-wave files, HANDWRITTEN ledger row appended (supersedes falsified 09-15 row)
