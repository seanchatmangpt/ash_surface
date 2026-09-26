# gapfix-ci-009: CI true-up to the receipted toolchain + full battery
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
.github/workflows/ci.yml drifts: pins OTP 27.3/elixir 1.18.4 vs .tool-versions 28.3/1.20.3 (changed in the SAME commit 9f22b12 — masked by mix.exs ~> 1.15); runs neither zero-config script (v1 landed 8e59431, v2 6c4ba94 — CI last touched 2026-09-13), nor mix test.zero, nor mix test.all; cache key hashes mix.exs but not mix.lock (ci.yml:17-20). Align pins to .tool-versions; wire the full battery (test.all/test.zero per zero-config gate law, zero_config_check.sh; v2 if gapfix-v2-receipt-008 is DONE green); add mix.lock to the cache key.
## Acceptance
- ci.yml pins == .tool-versions; battery complete; cache key includes mix.lock; workflow yaml valid (actionlint or equivalent if available).
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g09 + exp/gapfix-ci-009 | dispatched by rider (run2, target_n=10)
2026-09-16T23:52:54Z | ALIVE | exp/gapfix-ci-009 @ f7807ea | actionlint 0; yamllint 0 (2 pre-existing style warnings); mix format --check-formatted 0; mix compile --warnings-as-errors 0; mix test 0 (725 passed); npm test 0 (217 pass); mix test.all 0; mix test.zero 0; bash scripts/zero_config_check.sh 0 + ZERO_CONFIG_OK | first GitHub-runner execution unobserved (push forbidden) — pins/battery/cache-key proven locally only; v2 wiring deferred per gapfix-v2-receipt-008 IN_PROGRESS
2026-09-16T23:54:09Z | MERGED c9b8085  (rider): --no-ff exp/gapfix-ci-009; landed mix exit 0; first GitHub-runner run unobserved (no push) — recorded boundary
2026-09-17T02:55:13Z | DONE (unchanged; completion cross-ref) | gapfix-v2-ci-019 resolves the v2 deferral recorded 2026-09-16T23:52:54Z above: zero_config_v2.sh wired into ci.yml as sibling job zero-config-v2 (same pins 28.3/1.20.3, timeout-minutes 30, cache-friendly ~/.mix+~/.hex+~/.npm keyed on mix.lock+package-lock.json), work commit 428a2dd on exp/gapfix-v2-ci-wiring; local gates 0 (actionlint, yamllint, mix compile --warnings-as-errors, mix test 771, npm test 220/220); first GitHub-runner execution unobserved (push forbidden) | remaining: none
