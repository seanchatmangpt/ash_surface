# finish-classify-021: F2 — classify intent KNOWN-ness pre-bus
status: DONE
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F2: Intent.Dispatch.submit/3 refuses action_id outside the admitted action set, typed, BEFORE the bus hand-off (Elixir mirror of generated JS REFUSED_UNKNOWN_ACTION); tripwire tests. Owner: lib/ash_surface/intent/dispatch.ex.
## Acceptance
- typed refusal fires pre-bus for out-of-set action_id; admitted set unchanged; mix test 0; npm test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g21 + exp/finish-classify-021 | dispatched by rider (F-wave, target_n=11)
2026-09-17T03:28:56Z | ALIVE | exp/finish-classify-021@942680a (ash-surface-wt/g21) | mix format --check-formatted:0; mix compile --warnings-as-errors:0; mix test:0 (800 passed = 795 tests + 5 doctests, incl. 6 new KNOWN-ness tripwires, dispatch suite 15/15); npm test:0 (245/245); ledger bijection tripwire green (HANDWRITTEN row + surf:UnsupportedLedgerRow39) | none — DONE; note: _SYNTHESIS.md absent from tree, mission executed from ticket statement, REFUSED_UNKNOWN_ACTION anchor verified in projectors/js.ex:205
2026-09-17T03:30:11Z | MERGED 06ec54f  (rider): --no-ff exp/finish-classify-021 (F2); landed mix 800/0 (795+5 doctests); KNOWN-ness gate pre-bus, 6 falsifiers, ledger row 39 paired
