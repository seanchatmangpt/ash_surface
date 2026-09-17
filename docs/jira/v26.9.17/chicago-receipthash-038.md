# chicago-receipthash-038: receiptHash formula pinning
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Mapper 10: receiptHash is shape-only. Pin the FORMULA: canonical-JSON over the named receipt fields (document the field list at the schema site), compute independently in test (and JS twin row) asserting the emitted value; reorder-invariant, value-sensitive.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- formula documented at owner site + independent-computation rows both languages; falsifier: field-order change -> same hash (invariance RED if violated), value change -> different (RED if not); gates 0.
## History
