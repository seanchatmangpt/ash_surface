# chicago-e2e-loop-044: closed-loop e2e extension: state assertions at every stage
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Extend the consumer_fixture e2e: intent -> node runtime dispatch (live HTTP) -> receipt -> Event.from_receipt -> observation -> projector render (one projector) -> on-disk byte assertions; assert END-STATE at each stage (no intermediate-mock bookkeeping). Subject: test/ash_surface/consumer_fixture_test.exs family.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- full-loop test green with >=5 end-state assertions; falsifier: break one stage (e.g., tamper receipt) -> the loop RED at the right stage; gates 0.
## History
2026-09-17T06:38:42Z | DONE | ~/ash-surface-wt/g44 + exp/chicago-e2e-loop-44 @ b35e6c0 (test) + 6a3248b (format fix) | compile --warnings-as-errors exit 0; mix test exit 0 = 843/0 (5 doctests, 838 tests); format --check-formatted exit 0; npm not triggered (no JS in final tree) | remaining: none on this ticket; integration merge by rider
2026-09-17T06:38:42Z | falsifier EXECUTED: tampered test/js/consumer_e2e_runner.mjs:112 receipt-hash minting (+\"FALSIFIER_TAMPER\"); `mix test test/ash_surface/consumer_fixture_test.exs:210` -> exit 2, RED at the RIGHT stage (line 292: `assert receipt["receiptHash"] == recomputed_receipt_hash(receipt)`, stage-3 receipt self-verification); restored (git checkout, byte-identical); same command -> exit 0, 1 passed. Full loop test carries >=20 end-state assertions across stages 1-6 (intent content-address, receipt binding, real Ash record, event back-projection, observation digest/evidence, on-disk ARIA bytes + re-projection identity + accept-list/attribute-law binding)
2026-09-17T06:38:42Z | successor receipt: predecessor's uncommitted +229-line closed-loop test completed, corrected (1 defect: final assertion compared rendered aria inputs to AshTruth inputs — arguments vocabulary, legitimately empty for accept-based create :record; rebound to intent input keys + REAL accept list + attribute allow_nil? law), verified, falsified. Side fix 6a3248b: HEAD format-gate was RED (2 pre-existing unformatted test files; pure reflow) — gate now 0