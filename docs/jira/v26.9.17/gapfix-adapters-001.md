# gapfix-adapters-001: land the five Compiler default-section adapters + reconcile rival ash builders
status: OPEN
created: 2026-09-17T05:30:00Z
## Mission
Land `AshSurface.Compiler.Section.{Ash,Semantic,Capability,Presentation,Schema}` (compiler.ex:65-71 binds them; none exist). Bridge to the real builders; conform the Section behaviour (build/2 callback); capability is build/1 today (compiler/capability.ex:71) — move to canonical build/2. Reconcile the two rival ash builders (Compiler.Ash violates IR.Ash @type per ir.ex:140-147; Compiler.AshTruth conforms): ONE canon for default compile, tests re-pointed to integrated truth, conflict resolution ledgered if any byte is hand-written. Default `compile/1` on the fixture must produce a five-section IR (currently fail-closed {:invalid_section_module,...}, pinned by compiler_discovery_test.exs:124-131 — replace that pin with the real-pipeline law).
## Acceptance
- default compile/1 builds all five sections from the real fixture; mix test 0; npm test 0; ARCHITECTURE.md §7 + :123 rows match the landed truth; the owed-debt note in final-integration-010 History is satisfied by a cross-reference commit note.
## History
