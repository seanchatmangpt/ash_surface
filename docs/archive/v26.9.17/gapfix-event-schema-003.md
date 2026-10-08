# gapfix-event-schema-003: unify eventProjectionSchema across runtime + Expo artifact
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
Same-named schemas diverge: runtime allows nullable evidenceRef/receiptRef + payload (ash_surface_runtime.mjs:74-76); Expo demands non-nullable refs, no payload (projector/expo.ex:139-143). Event.to_map/1 always emits nil refs (event.ex:72-76) → real events pass one boundary, rejected by the other (pinned at expo_events_test.exs:171-174). ONE canon: either both accept the real wire form, or both reject with the same typed error. Re-point both test suites to the unified truth; add the missing nullable-acceptance rows.
## Acceptance
- a real Event.to_map/1 output validates identically at both boundaries (or fails identically, typed); no test pins divergence; mix test 0; npm test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g03 + exp/gapfix-event-schema-003 | dispatched by rider (run1, target_n=9)
2026-09-16T23:42:31Z | DONE | exp/gapfix-event-schema-003 @ dca0c22 | premise executed (runtime parsed real to_map output, Expo rejected invalid_type @ evidenceRef/receiptRef) → canon = both accept real wire form; expo.ex nullable refs + payload row; suites re-pointed + nullable-acceptance rows + executed both-boundary test (BOTH_BOUNDARIES_ALIVE); gates: compile --warnings-as-errors 0, format-check 0, mix test 726 pass/exit 0, npm test 220 pass/exit 0, npm run check 0 | remaining: none for this ticket (noted: TESTING.md suite counts stale at base commit, owned elsewhere)
2026-09-16T23:44:51Z | MERGED 614e389 (rider): --no-ff exp/gapfix-event-schema-003; landed-tree gate mix 728/0 exit 0 (725 base + 005's 2 + 003's 1); note: agent edited main-checkout ticket copy directly (contract deviation, content identical to branch — accepted, deviation recorded)
