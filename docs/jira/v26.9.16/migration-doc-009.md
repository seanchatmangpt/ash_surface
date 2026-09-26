# migration-doc-009: 26.9.14 -> 26.9.16 breaking changes
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v49.) docs/MIGRATION_26_9_16.md: envelope slimming (semanticId/authorityBoundary/doAuthority/receiptRequired removed from local derivation — per-field before/after table via IR delegation); new deps (pins per exp/v23: ash_r2rml 7d958a8, ash_a2a e25ed6e); compiler entry compile/1; projector behaviour v2 + legacy adapter; consumer upgrade checklist (reference zoela's MIGRATION.md canon).
## Acceptance
- mix test -> 0; pins match exp/v23 exactly
## History
2026-09-16T19:31:57Z | DONE | exp/v49 @ bd7de84 (pins b02bb45 = verbatim 57278d7; base 282f3ca) | mix deps.get=0, npm install=0, mix test=0 (308 passed), pin-diff vs exp/v23 (mix.exs+mix.lock) EMPTY | remaining: none on this ticket — doc cites sibling-canonical interfaces that land with final-integration-010
2026-09-17T00:18:52Z | CORRECTION (no code change) | appended by gapfix-docs-truth-013 (g13, exp/gapfix-docs-truth-013): this ticket title's "26.9.14 -> 26.9.16" conflated ash_a2a release numbers — ash_surface never shipped 26.9.14 (only version-setting commits: b97837f = 26.9.13, 1c3baff = 26.9.16; base 282f3ca mix.exs @version "26.9.13"). Title left byte-intact per append-only ticket law; docs/MIGRATION_26_9_16.md corrected to 26.9.13 with provenance. | remaining: none
