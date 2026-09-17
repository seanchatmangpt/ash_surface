# finish-replay-020: F1 — wire and harden Replay (vision synthesis)
status: IN_PROGRESS
created: 2026-09-17T04:30:00Z
## Mission
Per vision-map/_SYNTHESIS.md F1: route runtime receipts through from_receipt/2 (zero production callers today — event_projection.ex); promote the sorted-key canonical-JSON encoder into lib for Event/Observation digests (kills the map-order leak, event.ex:45); replace DateTime.utc_now() fallback with typed refusal (event_projection.ex:116,123); add one runtime-receipt replay-equality test. Mappers 05/11/17 corroborate.
## Acceptance
- one digest law (canonical, lib-owned); typed refusal replaces fallback; replay-equality test green; mix test 0; npm test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g20 + exp/finish-replay-020 | dispatched by rider (F-wave, target_n=11)
