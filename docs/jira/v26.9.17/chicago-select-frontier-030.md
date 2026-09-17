# chicago-select-frontier-030: selection calculus state tables + JS parity
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
F6 landed delegated dimension facts. State tables: preference-dominates-facts; frontier best via cost->latency->privacy with full-tie falling to declared order; absent-facts = legacy law byte-identical; malformed facts typed refusals; JS twin parity rows per table. Subject: lib/ash_surface/transport.ex select/3 + facts_from_profile/1 + runtime.mjs twin.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=12 state rows Elixir + >=6 JS parity rows; falsifier: flip tie-break priority -> frontier rows RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g30 + exp/chicago-select-frontier-30 | dispatched by coordinator (chicago wave)
