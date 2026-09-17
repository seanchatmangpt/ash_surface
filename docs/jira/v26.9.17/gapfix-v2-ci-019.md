# gapfix-v2-ci-019: wire zero_config_v2.sh into CI (008-green conditional now satisfied)
status: OPEN
created: 2026-09-17T02:30:00Z
## Mission
gapfix-v2-receipt-008 is DONE green (six EXITs 0 + ZERO_CONFIG_OK on landed tree). ci.yml's zero-config job runs v1 only (deliberate 009 deferral). Add v2 to the zero-config job (or a sibling job) with the same pins (.tool-versions 28.3/1.20.3); v2 runs the local-clone full battery — keep the job's timeout adequate and cache-friendly. actionlint/yamllint clean.
## Acceptance
- ci.yml runs v2; yaml valid; actionlint 0; the deferral note in 009's History gets a completion cross-ref.
## History
2026-09-17T02:30:00Z | IN_PROGRESS | ~/ash-surface-wt/g19 + exp/gapfix-v2-ci-019 | dispatched by coordinator (vision-finish fleet, agent 20)
2026-09-17T02:31:41Z | REAPED: agent rate-killed [1302] at 441s (storm window, 3rd incident); worktree g19 + branch preserved — successor reviews git log first
