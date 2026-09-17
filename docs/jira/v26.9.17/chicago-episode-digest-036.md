# chicago-episode-digest-036: PlanningEpisode canonical digest law
status: DONE
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
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
2026-09-17T07:39:37Z | IN_PROGRESS | successor re-dispatch (cohort 2 of 4; window confirmed by cohort 1 completing 3/3; branch preserved — review git log first)
2026-09-17T07:48:57Z | DONE | ~/ash-surface-wt/g36 + exp/chicago-episode-digest-36 @ 783024e (+ a1eb015 branch-base format repair) | successor completed predecessor's uncommitted work: digest/1 = CanonicalJSON.sha256_hex over wire record minus episodeId, create/2 mints "ep_" 16-hex prefix; JS twin pinned (13 tests, golden f9c0365f24b5e1260969cfc6a601975b2348581739f3d09804f9a629043433a0 cross-language incl. zod-parsed record, insertion-order hazard pin); falsifier EXECUTED: digest mutated to raw unsorted Jason.encode! -> mix test test/ash_surface/planning_episode_deep_test.exs exit 2, >32-key canonical-byte tripwire RED (aded6021... raw vs 9c903218... canonical), restored -> 24/24 exit 0 | gates: compile 0, mix test 848 passed/0 failed (843 tests + 5 doctests), npm test 263/0, format --check-formatted 0 | remaining: none — ready for rider integration (never pushed)
