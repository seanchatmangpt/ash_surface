# gapfix-v2-ci-019: wire zero_config_v2.sh into CI (008-green conditional now satisfied)
status: DONE
created: 2026-09-17T02:30:00Z
## Mission
gapfix-v2-receipt-008 is DONE green (six EXITs 0 + ZERO_CONFIG_OK on landed tree). ci.yml's zero-config job runs v1 only (deliberate 009 deferral). Add v2 to the zero-config job (or a sibling job) with the same pins (.tool-versions 28.3/1.20.3); v2 runs the local-clone full battery — keep the job's timeout adequate and cache-friendly. actionlint/yamllint clean.
## Acceptance
- ci.yml runs v2; yaml valid; actionlint 0; the deferral note in 009's History gets a completion cross-ref.
## History
2026-09-17T02:30:00Z | IN_PROGRESS | ~/ash-surface-wt/g19 + exp/gapfix-v2-ci-019 | dispatched by coordinator (vision-finish fleet, agent 20)
2026-09-17T02:31:41Z | REAPED: agent rate-killed [1302] at 441s (storm window, 3rd incident); worktree g19 + branch preserved — successor reviews git log first
2026-09-17T02:50:06Z | successor agent active (g19 fresh); status corrected OPEN->IN_PROGRESS
2026-09-17T02:55:13Z | ALIVE | exp/gapfix-v2-ci-wiring @ 428a2dd (rebased onto base a00111f; predecessor of reaped agent had created branch as exp/gapfix-v2-ci-wiring, not -019, zero commits, clean tree — recorded, proceeded on preserved branch) | premise verified TRUE: 008 DONE green, merge ec70861 is ancestor of HEAD, zero_config_v2.sh bytes unchanged since 6c4ba94. v2 wired as sibling job zero-config-v2 in ci.yml (same pins otp 28.3 / elixir 1.20.3; timeout-minutes 30; cache ~/.mix+~/.hex+~/.npm keyed on hashFiles mix.lock+package-lock.json — survives script's env -i re-exec, cache-friendly without weakening zero-config proof); stale 009-deferral comment removed. Gates: actionlint=0, yamllint=0 (2 pre-existing style warnings, 009 baseline), bash -n scripts/zero_config_v2.sh=0, mix compile --warnings-as-errors=0, mix test=0 (771 passed), npm test=0 (220/220); 009 History completion cross-ref appended | remaining: first GitHub-runner execution unobserved (push forbidden) — same recorded boundary as 009; nothing else
