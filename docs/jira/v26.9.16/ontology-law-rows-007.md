# ontology-law-rows-007: v26.9.16 law admitted to the ontology
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v47.) Check ontology.ttl header + ggen.toml FIRST: if generated -> docs/ONTOLOGY_V26_9_16.md as the pack-admission PROPOSAL (do not touch ontology.ttl). Rows: SurfaceIR class (five section properties); ProjectionBoundary invariant (determines nothing about existence/meaning/DO-authority); DelegationEdge properties; IntentEdge (human->candidate, no direct DO). Each annotated with the enforcing test's canonical path.
## Acceptance
- mix test -> 0; admitted-or-proposed stated in History
## History
2026-09-16T19:29:32Z | ALIVE | exp/v47 afb54a7 | mix deps.get 0; npm install 0; mix test 0 (308/308) | ADMITTED (ontology.ttl is ggen [ontology] source, no generated header -> rows admitted in place, no proposal doc; SurfaceIR+ProjectionBoundary enforcedBy test/ash_surface/ir_test.exs, DelegationEdge by test/ash_surface_test.exs + test/ash_surface/compiler/capability_section_test.exs, IntentEdge by test/ash_surface/planning_episode_test.exs — IR/delegation paths verified byte-exact on exp/v50, resolve at wave integration) | remaining: none here — IR/delegation enforcing tests land with the wave integration merge
