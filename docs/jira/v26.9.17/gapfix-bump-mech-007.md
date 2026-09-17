# gapfix-bump-mech-007: bump mechanism — carrier/citation split + missing golden regen path
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
`bump_version.sh --check <next>` fails closed today: 36-39 files carry legitimate "26.9.16" CITATIONS outside the handled set (compiler.ex:62 @ir_version is a true carrier; ontology.ttl, TESTING.md, ~20 tests are citations). Teach the mechanism to distinguish carriers (rewritten) from historical citations (preserved): either a per-file carrier/exclude table or a citation-context rule — fail-closed on anything unclassified. Extend handled code carriers (@ir_version ir.ex/compiler.ex). Add the missing regeneration family: ir_codec_golden_test.exs freezes digests + canonical JSON (:378,:386,:395,:563) with NO regen path — self-prove at old version, regenerate through the real IR.Codec pipeline.
## Acceptance
- `--check 26.9.17` exits 0 with a complete plan (carriers listed, citations excluded); apply + full battery green; version-bump-011's falsified "runs as-is" claim corrected by cross-ref note.
## History
2026-09-16T23:38:19Z | IN_PROGRESS | ~/ash-surface-wt/g07 + exp/gapfix-bump-mech-007 | dispatched by rider (run2, target_n=10)
2026-09-17T00:19:01Z | BLOCKED (integration-red, rider): branch is green in isolation but was CUT PRE-002 — its apply proved the mechanism at 26.9.17 on a base that predates 002's projector-CalVer law; the merge produced a mid-flight state (tree 26.9.17, aria.ex 26.9.16) the apply mode cannot reconcile — projector_calver_law refuses, correctly. UNBLOCK PATH: rebase exp/gapfix-bump-mech-007 onto current feat/dfcm-surface-core (post-002) and re-run the apply; the rebased mechanism will classify aria.ex as carrier and sync it lawfully. Work preserved on branch (25a4f25, aba5636).
