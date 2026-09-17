# finish-replay-020: F1 — wire and harden Replay (vision synthesis)
status: DONE
created: 2026-09-17T04:30:00Z
## Mission
Per vision-map/_SYNTHESIS.md F1: route runtime receipts through from_receipt/2 (zero production callers today — event_projection.ex); promote the sorted-key canonical-JSON encoder into lib for Event/Observation digests (kills the map-order leak, event.ex:45); replace DateTime.utc_now() fallback with typed refusal (event_projection.ex:116,123); add one runtime-receipt replay-equality test. Mappers 05/11/17 corroborate.
## Acceptance
- one digest law (canonical, lib-owned); typed refusal replaces fallback; replay-equality test green; mix test 0; npm test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g20 + exp/finish-replay-020 | dispatched by rider (F-wave, target_n=11)
2026-09-17T03:40:26Z | ALIVE | exp/finish-replay-020 @ 656a0a0 (base ebd38ff) | compile --warnings-as-errors 0; mix test 0 (804 passed, 5 doctests, 0 failures; +10 rows vs last green 794); npm test 0 (245/0); mix format --check-formatted 0 | none — F1 complete: CanonicalJSON admitted (one lib-owned digest law, Event/Observation digests canonical, goldens byte-survive), typed REFUSED_MISSING_TIMESTAMP/REFUSED_INVALID_SUBJECT replace utc_now fallback + subject raise, Event.from_receipt/2 production route (from_receipt/2 now has a production caller), runtime-receipt replay-equality test green (real node receipt through the back-projection); remaining vision items are F2-F8 on their own tickets