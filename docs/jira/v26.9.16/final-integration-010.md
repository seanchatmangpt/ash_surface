# final-integration-010: land the v-wave
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
From exp/v50 head (partial integration, 387/387 at time of writing): merge ALL landed exp/v* branches in V_WAVE.md order (interfaces -> sections -> codec/intent -> v10 slimming AFTER sections -> projectors -> deps v23 KEEP ITS mix.exs over v04/v05/v30/v31 local lines -> tests -> machinery -> docs). Reconcile: v01 IR canonical (v10's delegated-reader IR folds in as accessors); supersede local Section duplicates; re-freeze goldens only through real pipelines. Gates: full mix test x3, npm test, mix test.zero, zero_config_check.sh, no_local_do green. Land on feat/dfcm-surface-core --no-ff. No push.
## Acceptance
- all gates 0 on the landed tree; V_WAVE.md table updated to final standings
## History

2026-09-17T06:00:00Z | ALIVE | feat/dfcm-surface-core @ 241c8cd | mix test 725/725=0, npm test=0, compile --warnings-as-errors=0, format=0 | all 39 branches merged through v50 checkpoint (e3c07d1), landed --no-ff; deps.get + npm install run by coordinator post-landing; ticket closed by coordinator (agent died before History append) | remaining: version-bump-011, capacity-ladder-001
