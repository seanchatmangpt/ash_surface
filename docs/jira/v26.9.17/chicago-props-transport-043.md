# chicago-props-transport-043: property-based selection laws
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
StreamData properties over generated fact profiles + transport sets: selected ∈ declared∩available always; preference law preserved when non-dominated; malformed shapes always typed refusals (never raises, never nil). Subject: transport.ex select/3.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- 3 properties with shrinking proven (a falsifier run showing a shrunk counterexample on an injected bug); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g43 + exp/chicago-props-transport-43 | dispatched by coordinator (chicago wave)
2026-09-17T06:04:53Z | REAPED: agent rate-killed [1302] mid-life (12-14min — sustained-overload class, not launch-spike); worktree g43 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:30:36Z | REAPED: compound evidence (worktree silent 28-42min; STAGGER EXPERIMENT RESULT: successor died despite spaced launch — sustained-load class); branch preserved, 0 commit(s) ahead — successor reviews first
2026-09-17T06:51:14Z | DONE | exp/chicago-props-transport-43 @ 1934012 (+731c6d2 format repair; 2 commits ahead — reap line above was stale: agent was alive, commits landed) | mix compile --warnings-as-errors=0; mix test 845/845 (837 tests, 3 properties, 5 doctests)=0; mix format --check-formatted=0 (HEAD shipped format-drifted projector_ir_determinism_test.exs + mx_episode_compose_test.exs, untouched by this ticket — repaired tool-owned in 731c6d2); npm n/a (JS untouched); falsifier EXECUTED seed 0 (reproducible): transport.ex:151 fold &(&1 in available)→&(&1 not in available) → RED exit 2, laws 1+2 fail with StreamData-shrunk counterexample declared [:http] available [:http] preferred :phoenix_channel profile %{} (selected nil escaped declared∩available); git checkout -- restore → GREEN exit 0; random-seed soak 431661/812443/965920 all 0; adversarial catch during authoring: law 3 refused its own generator's consed-atom case ({[:http],[:http],[]} returned ok) — generator split into direct non-list terms vs consed unadmitted members; dep {:stream_data, "~> 1.4", runtime: false} top-level because ash_a2a (all-env dep) requires it unconditionally (deps/ash_a2a/mix.exs:152), 1.4.0 already locked transitively; failed edge (階): no property-test pack in ~/ggen-marketplace/packs (grep stream_data/ExUnitProperties empty) — suite authored in-repo under ticket; 比: 0% pack-rendered, honest hand-authored test code (transport_props_test.exs, 383 lines; owner candidate: property-law-test day-pack, not yet admitted) | remaining: merge only (never pushed)
