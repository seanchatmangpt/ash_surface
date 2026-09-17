# chicago-episode-digest-036: PlanningEpisode canonical digest law
status: IN_PROGRESS
created: 2026-09-17T06:30:00Z
## Mission
Mapper 10: episodes cross languages with NO digest law while Event/Observation have one. Define the canonical digest (sorted-key JSON over the episode record, mirroring CanonicalJSON), implement Elixir-side + JS twin (if episodes cross), pin both. Subject: lib/ash_surface/planning_episode.ex (+ canonical_json.ex reuse).
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- digest state rows: order-invariant, value-sensitive, pinned both sides where applicable; falsifier: raw-Jason (unsorted) digest -> invariance row RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g36 + exp/chicago-episode-digest-36 | dispatched by coordinator (chicago wave)
