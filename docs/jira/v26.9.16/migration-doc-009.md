# migration-doc-009: 26.9.14 -> 26.9.16 breaking changes
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v49.) docs/MIGRATION_26_9_16.md: envelope slimming (semanticId/authorityBoundary/doAuthority/receiptRequired removed from local derivation — per-field before/after table via IR delegation); new deps (pins per exp/v23: ash_r2rml 7d958a8, ash_a2a e25ed6e); compiler entry compile/1; projector behaviour v2 + legacy adapter; consumer upgrade checklist (reference zoela's MIGRATION.md canon).
## Acceptance
- mix test -> 0; pins match exp/v23 exactly
## History
2026-09-16T19:31:57Z | DONE | exp/v49 @ bd7de84 (pins b02bb45 = verbatim 57278d7; base 282f3ca) | mix deps.get=0, npm install=0, mix test=0 (308 passed), pin-diff vs exp/v23 (mix.exs+mix.lock) EMPTY | remaining: none on this ticket — doc cites sibling-canonical interfaces that land with final-integration-010
