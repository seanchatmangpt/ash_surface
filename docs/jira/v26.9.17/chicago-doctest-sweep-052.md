# chicago-doctest-sweep-052: doctests for every boundary public
status: OPEN
created: 2026-09-17T06:30:00Z
## Mission
First-doctests landed for from_manifest/compile. Extend: project_ir/2 (one projector), transport select/3, Standing validators, MXEpisode.compose/1, Intent.create/3 — each with runnable iex examples asserting real output; modules lacking any public doc noted. Subject: lib docstrings + test/ash_surface/doctest_test.exs.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- >=6 new doctest groups green; falsifier: wrong expected output in one example -> RED; gates 0.
## History
