# chicago-replay-state-028: replay state table over real receipts
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
F1 landed Event.from_receipt/2 + typed refusals. Deepen Chicago-style: a state table over REAL runtime receipts minted via the node runtime over live HTTP (consumer_fixture pattern), each replayed TWICE through Event.from_receipt asserting identical structs, wire forms, and digests; perturbation rows (tampered digest, missing timestamp, foreign subject) assert the exact typed refusal. Subject: lib/ash_surface/event.ex + ir/event_projection.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=8 state rows incl. 3 refusal rows; falsifier: perturb one receipt field -> refusal flips/changes (RED proof executed); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g28 + exp/chicago-replay-state-28 | dispatched by coordinator (chicago wave)
2026-09-17T06:49:55Z | REAPED: cluster death at ~30min (sustained-load grind; 5 simultaneous); branch preserved — successor reviews git log first
2026-09-17T07:23:03Z | IN_PROGRESS | successor re-dispatch (cold-hold lifted after 32min clean; half-pace cohort 1 of 4; branch preserved — review git log first)
2026-09-17T07:31:40Z | DONE | g28 + exp/chicago-replay-state-28 @ 45f2a063d22848f1ffe8e65b2af15d169b115e2b | predecessor's partial work inherited and completed: digest-binding law (REFUSED_RECEIPT_DIGEST_MISMATCH, ordering subject→timestamp→digest) + event_replay_state_test.exs (11 state rows: 7 OK + 4 refusal + 1 falsifier row; real node-runtime receipts over live HTTP, consumer_fixture pattern, each replayed twice asserting identical structs/wire/digests) | falsifier EXECUTED: `mix test test/ash_surface/event_replay_state_test.exs` with bind_receipt_digest disabled (the exact mutation predecessor left in-tree) → exit 2, 1/3 passed RED (tampered-digest + falsifier rows fail); restored `:ok <- bind_receipt_digest(receipt)` → exit 0, 3 passed GREEN | gates: mix compile --warnings-as-errors exit 0; mix test exit 0 (845 passed, base 842 +3); mix format --check-formatted exit 0; npm test n/a (no JS touched) | remaining: none — awaiting coordinator merge
