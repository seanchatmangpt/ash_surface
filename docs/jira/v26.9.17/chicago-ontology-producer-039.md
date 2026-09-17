# chicago-ontology-producer-039: ontologyDigest/applicationReleaseIdentity: honest producer or enforced absence
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
015 adjudicated keep-typed-optional-no-producer. Decide by evidence on the CURRENT tree (F4 landed since): either wire an honest producer from admitted state (surface.digest + generator identity — no fabrication) with state rows, OR encode the absence as an enforced contract test (fields absent from contract/2 output BY LAW, presence = RED) + doc note at the schema site.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- one of the two landed with state rows + executed falsifier for the chosen side; no fabricated provenance; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g39 + exp/chicago-ontology-producer-39 | dispatched by coordinator (chicago wave)
2026-09-17T06:49:55Z | REAPED: cluster death at ~30min (sustained-load grind; 5 simultaneous); branch preserved — successor reviews git log first
2026-09-17T07:39:37Z | IN_PROGRESS | successor re-dispatch (cohort 2 of 4; window confirmed by cohort 1 completing 3/3; branch preserved — review git log first)
