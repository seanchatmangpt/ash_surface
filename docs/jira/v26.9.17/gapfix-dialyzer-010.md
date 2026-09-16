# gapfix-dialyzer-010: dialyzer + coverage layers, first receipt
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
No dialyzer (the committed 65MB crash dump is literally a crashed dialyzer attempt), no coverage either language (mix test --cover ran once, unreceipted). Add dialyxir + a dialyzer step (clean baseline: fix trivial findings, ignore-warnings file for the rest with justification per line); add minimal coverage receipts: mix test --cover once, node --test with coverage flag once; record numbers in History. Wire both into CI (after gapfix-ci-009 or as part of it — coordinate via ticket status).
## Acceptance
- mix dialyzer exits 0 with receipted baseline; coverage numbers recorded both languages; CI runs both or dependency-noted.
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g10 + exp/gapfix-dialyzer-010 | dispatched by rider (run2, target_n=10)
