# version-bump-011: execute the 26.9.16 bump
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
BLOCKED BY final-integration-010. Execute scripts/bump_version.sh 26.9.16 (built on exp/v26 @ 1569e7d — verify it survives integration first); verify every regenerated golden via full battery; HANDWRITTEN.md ledger row if the script needed any post-integration repair.
## Acceptance
- bump applied; mix test -> 0; npm test -> 0; old version zero occurrences
## History
2026-09-16T20:58:10Z | ALIVE | 1c3baff | mix compile --warnings-as-errors=0, mix format --check-formatted=0, mix test=0 (725 passed), npm test=0 (217/217), grep -c 26.9.13 mix.exs=0, tree-wide 26.9.13 occurrences=0 | script survived byte-identical (blob 0b8406a = exp/v26) but needed lawful extension for the v-wave: 7 TEXT carriers + docs/DEP_GRAPH.md (per the exp/v25 prescription), 4 new computed-golden families (IR_DIGEST x5, JS_DIGEST_V2 x3, JS_T26_REF x3, ARTIFACT_SHA x1) all self-proven at the old version and re-frozen through real pipelines (IR.Codec, Projectors.JS); one fail-open hole in the generator-run check found and closed; 3 historical version citations reworded truthfully (ARCHITECTURE.md, MIGRATION doc, prior ledger row) instead of falsified; repair ledgered in HANDWRITTEN.md; remaining: none — next bump runs the mechanism as-is.
