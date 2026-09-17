# chicago-props-codec-042: property-based codec/digest laws
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
Add StreamData property tests: (1) canonical key-order invariance: shuffled-key maps -> identical CanonicalJSON bytes + digest; (2) value sensitivity; (3) five-section IR round-trip identity over bounded generators (realistic ash/semantic/capability/presentation/schema shapes). Subject: canonical_json.ex + ir/codec.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- 3 properties, bounded gens, seeded runs stable; falsifier: inject order-dependence into encode -> property RED; gates 0.
## History
