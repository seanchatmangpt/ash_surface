# chicago-intent-gate-032: intent KNOWN-ness gate state transitions
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
F2 landed the pre-bus gate. State table: in-set id reaches bus (count 1); out-of-set refuses pre-bus (bus count 0); empty set admits nothing; malformed set typed refusal; no-key = no gate byte-identical. Subject: lib/ash_surface/intent/dispatch.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=6 state rows with bus-call counting (the law IS the boundary); falsifier: remove the gate -> out-of-set row RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g32 + exp/chicago-intent-gate-32 | dispatched by coordinator (chicago wave)
2026-09-17T06:09:21Z | ALIVE | exp/chicago-intent-gate-32 @ 7b77e48 (+246ae31 format repair; base f0d3577) | deps.get+npm install ok; mix compile --warnings-as-errors=0; NEW test/ash_surface/intent/dispatch_knownness_gate_test.exs: 8 state rows x 3 observables (exact outcome, exact bus-call count, exact bus call), 9/9 GREEN exit 0; falsifier EXECUTED: removed validate_knownness/2 from Dispatch.submit/3 -> mix test (focused) exit 2 RED 4/9, out-of-set row got {:ok, "receipt-state-table"} (unknown id reached bus) not {:error, :REFUSED_UNKNOWN_ACTION}; git restore -> rerun exit 0 GREEN 9/9; mix test full=0 (851 passed, 846+5 doctests); mix format --check-formatted=0 after repairing PRE-EXISTING HEAD red (mx_episode_compose_test.exs, projector_ir_determinism_test.exs — mechanical mix format, commit 246ae31); npm test not run (no JS touched); 比: 177 test lines manufactured from the ticket's state table, 0 hand-written 産面 lines, 0 ledger deltas | none in-ticket — JS-mirror (dispatchIntent ACTIONS) state-table parity belongs to its own ticket
2026-09-17T06:11:10Z | MERGED 1d917fe  (rider): --no-ff exp/chicago-intent-gate-32; landed mix 851/0 (842+9), format 0 (branch carried HEAD format-red repair — recorded); falsifier: gate removal -> RED 4/9 with unknown-id reaching bus; restored green
