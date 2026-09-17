# chicago-runtime-ledger-037: runtime.mjs pack-source ledger row
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Mapper 02: priv/static/ash_surface_runtime.mjs is hand-maintained pack source with NO HANDWRITTEN row. Admit the row (+ UNSUPPORTED bijection pair) naming the intended owner (JS runtime template family in ash-extension-pack) and paydown path; byte-provenance note (golden SHA law already pins content).
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- ledger+ontology pair admitted, bijection tripwire green; falsifier: remove the pair -> tripwire RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g37 + exp/chicago-runtime-ledger-37 | dispatched by coordinator (chicago wave)
2026-09-17T06:12:36Z | DONE | exp/chicago-runtime-ledger-37 @ 1a2ae2f4ef25127e8b75a567bc9e125fec6db61d | deps.get 0; npm install 0; mix compile --warnings-as-errors 0; mix format --check-formatted 0; mix test 844 passed/0; npm test 258 pass/0; tripwire 6/6 exit 0; falsifier A (ontology UNSUPPORTED half removed: sed 471,476d) mix test handwritten_ledger_test exit 2 RED (44 vs 43 + pair-pin), restore 6/6 0; falsifier B (whole pair removed: ontology + HANDWRITTEN row) exit 2 RED (both runtime pin tests, generic bijection stayed green), restore 6/6 0 | remaining: paydown — ash-extension-pack grows the JS runtime template family and emits priv/static/ash_surface_runtime.mjs from ontology runtime facts; golden re-frozen at cutover, ledger row + UnsupportedLedgerRow44 retired together
