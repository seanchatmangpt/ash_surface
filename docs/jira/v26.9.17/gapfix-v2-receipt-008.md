# gapfix-v2-receipt-008: execute zero_config_v2.sh on the landed tree
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
scripts/zero_config_v2.sh has NEVER been executed on the landed tree (only receipt is branch-tip era, 308-test tree; V_WAVE.md:61 lists it among green v50 gates without exit receipts). Execute it at HEAD; record per-step EXIT lines; if red, repair narrowly and re-run; then reconcile V_WAVE's "green" wording with the actual receipts (append receipt ref).
## Acceptance
- v2 run on landed HEAD, ZERO_CONFIG_OK-equivalent marker + exits recorded in this ticket's History; V_WAVE claim backed by receipts.
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g08 + exp/gapfix-v2-receipt-008 | dispatched by rider (run2, target_n=10)
2026-09-16T23:49:18Z | ALIVE | exp/gapfix-v2-receipt-008 @ a7a6b402a5530e1db7d839863f9992ecee6dfd74 (executed tree; receipt commit follows this line) | premise verified TRUE: sole prior v2 receipt was v40-era exp/v40 6c4ba94 (308-test tree, zero-config-battery-002); v50 landing gates list v1 zero_config_check.sh only (final-integration-010). v2 run at landed HEAD: clone HEAD == a7a6b40 verified; EXIT[env-read guard (test/ vs @zero_env_allowlist)]=0 EXIT[mix deps.get]=0 EXIT[npm install]=0 EXIT[mix test]=0 (725 passed) EXIT[npm test]=0 (217/217) EXIT[mix test.zero]=0 (alias present; scrubbed env -i test.all re-run: 725 + 217/217) → ZERO_CONFIG_OK, script exit 0, green first run, no repair. Worktree gates: mix compile --warnings-as-errors=0, mix test=0 (725), npm test=0 (217). V_WAVE.md:61 gates cell receipt-ref appended (v50 wording reconciled with actual receipts) | remaining: ledger paydown of scripts/zero_config_*.sh into marketplace pack template (HANDWRITTEN.md:19)
