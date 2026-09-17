# finish-select-025: F6 — selection frontier: cost/latency/privacy as delegated facts
status: DONE
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F6 (+ mapper 07): extend the transport Decision inputs with delegated facts (cost class, latency class, privacy class) carried in the action profile — selection still deterministic, dimensions now declared rather than absent; docs (PROJECTORS/ARCHITECTURE) updated to the declared calculus.
## Acceptance
- selection law weighs declared dimensions; absent-fact behavior typed; mix test 0; npm test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g25 + exp/finish-select-025 | dispatched by rider (F-wave, target_n=11) — dispatch row carried from the rider's ticket copy (this branch's copy was still OPEN/empty)
2026-09-17T03:42:37Z | ALIVE | exp/finish-select-025 @ a4a5fcc (base ebd38ff) | mix format --check-formatted EXIT 0; mix compile --warnings-as-errors EXIT 0; mix test EXIT 0 (807 passed: 802 tests + 5 doctests, 0 fail); npm test EXIT 0 (250 pass / 0 fail / 0 skipped) | none — acceptance met (declared dimensions weighed per surf:SelectionEdge calculus; absent facts typed :undelegated with frontier mirroring availability; PROJECTORS + ARCHITECTURE carry the declared calculus; 帳 row pair 39 admitted; runtime golden + export-surface pins re-frozen with rationale); next: F-wave riders land 026/027
