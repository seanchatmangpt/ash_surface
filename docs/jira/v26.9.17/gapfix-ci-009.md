# gapfix-ci-009: CI true-up to the receipted toolchain + full battery
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
.github/workflows/ci.yml drifts: pins OTP 27.3/elixir 1.18.4 vs .tool-versions 28.3/1.20.3 (changed in the SAME commit 9f22b12 — masked by mix.exs ~> 1.15); runs neither zero-config script (v1 landed 8e59431, v2 6c4ba94 — CI last touched 2026-09-13), nor mix test.zero, nor mix test.all; cache key hashes mix.exs but not mix.lock (ci.yml:17-20). Align pins to .tool-versions; wire the full battery (test.all/test.zero per zero-config gate law, zero_config_check.sh; v2 if gapfix-v2-receipt-008 is DONE green); add mix.lock to the cache key.
## Acceptance
- ci.yml pins == .tool-versions; battery complete; cache key includes mix.lock; workflow yaml valid (actionlint or equivalent if available).
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g09 + exp/gapfix-ci-009 | dispatched by rider (run2, target_n=10)
