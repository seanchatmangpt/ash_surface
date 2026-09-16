# migration-doc-009: 26.9.14 -> 26.9.16 breaking changes
status: OPEN
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v49.) docs/MIGRATION_26_9_16.md: envelope slimming (semanticId/authorityBoundary/doAuthority/receiptRequired removed from local derivation — per-field before/after table via IR delegation); new deps (pins per exp/v23: ash_r2rml 7d958a8, ash_a2a e25ed6e); compiler entry compile/1; projector behaviour v2 + legacy adapter; consumer upgrade checklist (reference zoela's MIGRATION.md canon).
## Acceptance
- mix test -> 0; pins match exp/v23 exactly
## History
