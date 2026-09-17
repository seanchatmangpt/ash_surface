# chicago-voicekiosk-states-047: VoiceKiosk flow-state tests
<<<<<<< HEAD
status: IN_PROGRESS
=======
status: DONE
>>>>>>> exp/chicago-voicekiosk-states-47
created: 2026-09-17T06:30:00Z
## Mission
Flow states: authority-admitted vs not; CONFIRM always required; autoExecute=false in every emitted plan; ANSWER phrasing only for never-delegated DO (documented nuance); dialogue structure asserted as data. Subject: lib/ash_surface/projector/voice_kiosk.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=8 state rows; falsifier: flip autoExecute -> RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g47 + exp/chicago-voicekiosk-states-47 | dispatched by coordinator (chicago wave)
<<<<<<< HEAD
=======
2026-09-17T06:14:41Z | DONE | exp/chicago-voicekiosk-states-47 @ b5f7a9a (b5f7a9a031b641ce6bfce949b54d0341cebfed27) | 10-row flow-state table over the REAL VoiceKiosk.project_ir/2, each row asserted as a whole intent map (actionId, prompt, slots, mode, autoExecute) across the delegated-fact frontier (authorityBoundary DO/OBSERVE x doAuthority true/false x capabilities with/without authority_required); 3 table-wide invariants: CONFIRM always required on every authority-admitted row (prompt 'Please confirm: ...' + autoExecute=false); autoExecute=false in every emitted plan except the single ungated-OBSERVE-answer state; within the DO family ANSWER phrasing belongs only to never-delegated DO and never auto-executes (nuance documented in-file: phrasing is a dialogue mode, not an execution grant); dialogue structure asserted as data (slot list pinned as literal data inside every expected intent). FALSIFIER EXECUTED: subject autoExecute expression flipped to 'not (...)' -> mix test test/ash_surface/projector/voice_kiosk_test.exs --only flow_states -> 0/13 passed, exit 2; subject restored (git diff lib/ empty) -> 13 passed, exit 0. Test-only commit: 165 insertions in test/ash_surface/projector/voice_kiosk_test.exs, zero production bytes, no JS touched. Gates: mix compile --warnings-as-errors 0; mix test 0 (855 passed = 850 tests + 5 doctests, was 842 at HEAD f0d3577); npm test skipped (no JS touched, DoD conditional); mix format --check-formatted 0 | remaining: none (failed edge: mission phrase 'autoExecute=false in every emitted plan' read as the admitted-plan law pinned by committed behavior incl. the v10 integration test pinning read=ANSWER autoExecute=true; ungated OBSERVE remains the one auto-executable state and is pinned as such in rows 7-8 and the second invariant — coordinator's flip-falsifier fired RED on all 13 new tests either way)
>>>>>>> exp/chicago-voicekiosk-states-47
2026-09-17T06:16:21Z | MERGED c10e6f0  (rider): --no-ff exp/chicago-voicekiosk-states-47; landed 855+/0; falsifier: autoExecute flip -> 0/13 RED, restored green
