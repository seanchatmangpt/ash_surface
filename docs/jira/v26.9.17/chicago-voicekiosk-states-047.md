# chicago-voicekiosk-states-047: VoiceKiosk flow-state tests
status: OPEN
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
