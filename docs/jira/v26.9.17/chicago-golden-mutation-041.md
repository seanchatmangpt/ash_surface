# chicago-golden-mutation-041: mutation-proven golden families
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Chicago core: prove the golden guards CAN fail. For 3 families (runtime SHA, contract digest, IR codec golden): documented mutation recipes (whitespace injection, field rename) executed in-receipt showing the guarding tests RED, restored GREEN; encode recipes as a scripts/mutation_recipes.md + optional fast script (not wired to default CI). Subject: test goldens + recipes doc.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- 3 families x mutation executed with commands+exits in History; recipes doc committed; gates 0 (mutations restored).
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g41 + exp/chicago-golden-mutation-41 | dispatched by coordinator (chicago wave)
2026-09-17T05:55:59Z | REAPED: agent rate-killed [1302] at 346s; worktree g41 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:34:00Z | IN_PROGRESS | exp/chicago-golden-mutation-41 (pre-receipt, HEAD f0d3577) | baseline guards GREEN: 3 golden files (runtime_source, digest, ir_codec_golden) 44/44 exit 0; mix compile --warnings-as-errors exit 0 | falsifiers next
2026-09-17T06:38:00Z | IN_PROGRESS | M1 runtime SHA (whitespace injection): `printf '\n' >> priv/static/ash_surface_runtime.mjs` → `mix test test/ash_surface/runtime_source_test.exs` exit 2 (3/4; golden SHA assert failed: 85e44fc9… vs frozen 8373790c…); `git checkout --` restore → 4/4 exit 0 | guard proven falsifiable
2026-09-17T06:40:00Z | IN_PROGRESS | M2 contract digest (field rename): `perl -pi -e 's/"generatorIdentity" =>/"generatorIdentityRenamed" =>/' lib/ash_surface.ex` → `mix test test/ash_surface/digest_test.exs` exit 2 (6/7; all 5 frozen digests drifted, e.g. minimal_read 3847c08b… vs c8f65e1c…); `git checkout --` restore → 7/7 exit 0 | guard proven falsifiable
2026-09-17T06:42:00Z | IN_PROGRESS | M3 IR codec golden (field rename): `perl -pi -e 's/"presentation" => section_to_map/"presentation_renamed" => section_to_map/' test/ash_surface/ir_codec_golden_test.exs` → `mix test` exit 2 (18/33, 15 failed: golden JSON pins both fixtures, canonical key set, frozen digests, round-trip); `git checkout --` restore → 33/33 exit 0 | guard proven falsifiable
2026-09-17T06:45:00Z | IN_PROGRESS | runner: `bash scripts/mutation_recipes.sh` exit 0 → MUTATION_RECIPES_OK (baseline compile+3 guards 0; M1/M2/M3 RED exit 2 each, GREEN 0 each; subjects clean) | recipes doc + script written, NOT wired to CI
2026-09-17T06:47:00Z | IN_PROGRESS | HEAD-red repair: `mix format --check-formatted` was RED at f0d3577 (mx_episode_compose_test.exs from 3954d86/F4, projector_ir_determinism_test.exs from aa2ddc4/F8; formatter fails fast on first offender) — formatting-only fix, diffs reviewed semantics-free, affected files 10/10, full suite 842/842 → commit 8f55234 | format gate 0
2026-09-17T06:49:08Z | DONE | exp/chicago-golden-mutation-41 @ 8f55234 + recipes commit | gates: mix compile --warnings-as-errors=0; mix test=0 (842 passed); npm test=0; mix format --check-formatted=0; all mutations restored (git status clean of subjects) | remaining: none — merge pending (rider)
