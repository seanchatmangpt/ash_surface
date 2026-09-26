# validator-ir-alignment-005: one truth, two consumers
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v44.) Admission alignment law: the validator's admitted-projection set (exact public actions) equals the IR ash-section action set for the SAME resource. Same inline resource through both paths -> identical sorted action lists; private actions excluded from both; rename residue rejected by validator => ash-section never emits the stale name. Sibling modules absent -> declare minimal contracts locally + @tag :integration_pending honestly.
## Acceptance
- targeted suite -> 0; full suite green
## History
2026-09-16T19:31:32Z | ALIVE (alignment law vs declared minimal contract; real-sibling convergence integration_pending by tag) | exp/v44 b2c8e90 (base 282f3ca) | targeted `mix test test/ash_surface/resource/` 0 (35); full `mix test` 0 (316, 2x consecutive clean); `npm test` 0 (175/0); format 0; compile --warnings-as-errors 0; pre-existing flake measured on pristine base (~2/8: ConsumerFixtureTest/HealthDeepTest, owned by integration-dry-run-005, not fixed here) | remaining: when exp/v03's AshSurface.Compiler.Ash lands, delete the local stand-in, re-point tests at build/1, drop :integration_pending tags
