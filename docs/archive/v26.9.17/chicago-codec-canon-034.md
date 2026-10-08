# chicago-codec-canon-034: codec.ex single-canon reconciliation
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Mapper 02: ir/codec.ex:12-14,33 carries a stale parallel five-section canon claim while ir.ex is the admitted canon. Reconcile to ONE canon; state tests: codec round-trips the real five-section IR from a live fixture (both directions), digest pinned equal to fixture surface digest. Subject: lib/ash_surface/ir/codec.ex + ir.ex.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- round-trip + digest state rows on real fixture; stale canon text gone; falsifier: introduce key-order dependence -> digest row RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g34 + exp/chicago-codec-canon-34 | dispatched by coordinator (chicago wave)
2026-09-17T06:11:10Z | REAPED: compound evidence — 0 commits + 22min silence during active storm (10th casualty pattern); worktree g34 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:40:01Z | REAPED: mid-life sustained-load death (worktree silent 20-29min); branch preserved — successor reviews git log first
026-09-17T06:59:29Z | IN_PROGRESS | ~/ash-surface-wt/g34 + exp/chicago-codec-canon-34 (base f0d3577) | predecessor left 0 commits, clean tree — reviewed git log first per re-dispatch law; baseline: compile 0, codec suites 101 green, format gate RED at HEAD (pre-existing drift, 2 files) | reconcile codec to the ONE admitted canon
2026-09-17T06:59:29Z | ALIVE | 480bba4 fix(format) | mix format --check-formatted 0 | formatter-owned mechanical wraps only (mx_episode_compose_test, projector_ir_determinism_test); gate was red at HEAD before any ticket change
2026-09-17T06:59:29Z | ALIVE | 2be0e73 refactor(ir) | compile --warnings-as-errors 0; mix test 834 passed/0 fail (5 doctests); format --check-formatted 0; JS untouched -> npm n/a | AshSurface.IR.Surface parallel canon DELETED; AshSurface.IR.Codec re-pointed at the admitted ir.ex canon (golden-declared to_map/from_map law + JSON-isomorphic staging of declared sub-structs/atoms; digest/1 byte-identical); golden suite bound to admitted modules with frozen goldens byte-identical; ir_codec_test.exs rewritten as live-fixture state rows (real VolunteerMilestone pipeline, round-trip both directions, digest pinned == fixture surface digest, >32-key construction-history independence, typed refusals)
2026-09-17T06:59:29Z | ALIVE — falsifier EXECUTED | mutation: digest/1 canonical_term key sort inverted (key-order dependence in preimage): mix test ir_codec_test.exs ir_codec_golden_test.exs -> exit 2, RED on "digest pinned to the fixture surface digest" + golden reuse pin; restored: same command -> exit 0, 48/48 GREEN. Attempted mutation 1 (drop sort, no invert): exit 0 — invisible on this runtime (flatmaps iterate key-sorted, HAMT order is set-determined; recorded in suite moduledoc) | none — DONE; observe: ir_struct_test.exs still carries its own pending bind-to-admitted-ir.ex block (separate mapper defect, untouched here)
2026-09-17T07:01:34Z | MERGED 7cdd86f  (rider): --no-ff exp/chicago-codec-canon-34; one canon (IR.Surface parallel deleted); goldens byte-survived = strongest reconciliation proof; falsifier: sort-inversion RED both digest rows (sort-drop masked, recorded honestly)
