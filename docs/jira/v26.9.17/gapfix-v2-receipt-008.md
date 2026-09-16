# gapfix-v2-receipt-008: execute zero_config_v2.sh on the landed tree
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
scripts/zero_config_v2.sh has NEVER been executed on the landed tree (only receipt is branch-tip era, 308-test tree; V_WAVE.md:61 lists it among green v50 gates without exit receipts). Execute it at HEAD; record per-step EXIT lines; if red, repair narrowly and re-run; then reconcile V_WAVE's "green" wording with the actual receipts (append receipt ref).
## Acceptance
- v2 run on landed HEAD, ZERO_CONFIG_OK-equivalent marker + exits recorded in this ticket's History; V_WAVE claim backed by receipts.
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g08 + exp/gapfix-v2-receipt-008 | dispatched by rider (run2, target_n=10)
