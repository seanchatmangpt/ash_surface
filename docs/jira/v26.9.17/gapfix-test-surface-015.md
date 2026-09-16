# gapfix-test-surface-015: untested public surface + spec/doctest layer
status: OPEN
created: 2026-09-17T05:30:00Z
## Mission
(a) ashSurfaceContractSchema (runtime :82) — only export of 8 with zero direct tests; ontologyDigest/applicationReleaseIdentity (:88,:90) have NO live Elixir producer (contract/2 at lib/ash_surface.ex:134-142 never emits them; only frozen fixture) — add direct tests; decide producer-or-remove for the two fields, honestly. (b) UNKNOWN_ACTION branch (runtime :280) — only unexercised throw of 12; add row. (c) six specless publics: LiveView.project_ir/2 (live_view.ex:49,51,58), Formatter trio (formatter.ex:4,6,8), build/2 in schema.ex:53/semantic.ex:43/ash.ex:20 — add @spec. (d) zero doctests repo-wide: add doctest entries for boundary modules (from_manifest/2, compile/1,2 at minimum) with examples that run. (e) Section behaviour: no module declares @behaviour while semantic.ex:5-6 claims all sections implement it — declare or retract the claim. (f) Compiler.IR.Boundary (compiler/schema.ex:115-120) built-but-read-by-nothing — wire a reader or ledger the dead code decision.
## Acceptance
- every public export exercised or explicitly ledgered; @spec on the six; doctests run green; claim-vs-code consistent; mix test 0; npm test 0.
## History
