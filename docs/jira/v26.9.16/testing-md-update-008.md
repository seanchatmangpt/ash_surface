# testing-md-update-008: suite map for the IR era
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v48.) Update TESTING.md: suite map extended with IR/compiler/projector/intent rows (canonical paths), delegation-test pattern (real ash_r2rml/ash_a2a, never mocks), no-local-DO tripwire, zero-config v2 battery. Every cited path exists or is sibling-canonical marked (lands at integration).
## Acceptance
- mix test -> 0; spot-checked paths exist
## History
2026-09-16T19:32:18Z | ALIVE | exp/v48 d20c895 | mix test 0 (308 pass), npm test 0 (175 pass), mix format 0, path spot-check 80 cited / 65 exist / 15 all [INTEGRATION]-marked / 0 unmarked absences | IR/compiler/projector/intent rows cite sibling-canonical paths (v01/v02/v05/v06/v08/v09/v20 per V_WAVE.md); they land with final-integration-010 — nothing remaining on this branch.
