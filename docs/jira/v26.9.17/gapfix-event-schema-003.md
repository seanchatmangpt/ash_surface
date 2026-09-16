# gapfix-event-schema-003: unify eventProjectionSchema across runtime + Expo artifact
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
Same-named schemas diverge: runtime allows nullable evidenceRef/receiptRef + payload (ash_surface_runtime.mjs:74-76); Expo demands non-nullable refs, no payload (projector/expo.ex:139-143). Event.to_map/1 always emits nil refs (event.ex:72-76) → real events pass one boundary, rejected by the other (pinned at expo_events_test.exs:171-174). ONE canon: either both accept the real wire form, or both reject with the same typed error. Re-point both test suites to the unified truth; add the missing nullable-acceptance rows.
## Acceptance
- a real Event.to_map/1 output validates identically at both boundaries (or fails identically, typed); no test pins divergence; mix test 0; npm test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g03 + exp/gapfix-event-schema-003 | dispatched by rider (run1, target_n=9)
