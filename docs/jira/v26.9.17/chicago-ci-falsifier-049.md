# chicago-ci-falsifier-049: CI runs the falsifier subset
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Wire a bounded falsifier job into ci.yml: runs the mutation-recipe script subset (from chicago-golden-mutation-041) + tripwire canaries, fast (<5min), pins per .tool-versions; actionlint/yamllint clean. Subject: .github/workflows/ci.yml + scripts.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- workflow valid; falsifier subset green on HEAD; falsifier: a known-bad recipe variant -> job RED locally simulated (act or documented); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g49 + exp/chicago-ci-falsifier-49 | dispatched by coordinator (chicago wave)
2026-09-17T05:57:07Z | REAPED: agent rate-killed [1302] (storm window); worktree g49 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:30:36Z | REAPED: compound evidence (worktree silent 28-42min; STAGGER EXPERIMENT RESULT: successor died despite spaced launch — sustained-load class); branch preserved, 0 commit(s) ahead — successor reviews first
026-09-17T06:37:00Z | IN_PROGRESS | successor pickup: branch was clean at f0d3577 (predecessor rate-killed before any work; 041 recipes not landed — minimal recipe set manufactured on this branch: scripts/mutation_recipes.md 3 families, scripts/ci_falsifier.sh) | baseline: guard subset + canaries 113 passed, 0.2s test time; mix deps.get + npm install cold | falsifier GREEN execution pending

EXECUTED FALSIFIER (real subjects, commands + exits):
- canaries on pristine HEAD: `mix test no_local_do handwritten_ledger standing transport_falsifiers refactor_safety_net` -> EXIT[canaries]=0, 69 passed
- runtime-sha-whitespace: `printf '\n' >> priv/static/ash_surface_runtime.mjs` -> `mix test test/ash_surface/runtime_source_test.exs` RED exit 2 (Result: 3/4 passed, Failed: 1 test) -> `git checkout --` -> GREEN exit 0 (4 passed)
- digest-hexcase-flip: `perl -pi -e 's/Base\.encode16\(case: :lower\)/Base.encode16(case: :upper)/' lib/ash_surface.ex` -> `mix test test/ash_surface/digest_test.exs` RED exit 2 (4/7, Failed: 3 tests) -> restore -> GREEN exit 0 (7 passed)
- irgolden-presentation-fielddrop: `perl -pi -e 's/\@presentation_fields ~w\(format group label order widget\)/\@presentation_fields ~w(format group order widget)/' test/ash_surface/ir_codec_golden_test.exs` (codec producer half; goldens untouched) -> `mix test test/ash_surface/ir_codec_golden_test.exs` RED exit 2 (24/33, Failed: 9 tests) -> restore -> GREEN exit 0 (33 passed)
- full script on committed HEAD 3542fa9: `bash scripts/ci_falsifier.sh` -> FALSIFIER_OK, exit 0, 7.2s (9.5s first timed run)
- ACCEPTANCE FALSIFIER — known-bad recipe variant ACTED: mis-wire recipe 1's guard to digest_test.exs (guard does not watch the runtime file): mutation landed, guard survived (EXIT[red:...]=0, 7 passed) -> "FALSIFIER_FAIL: guard survived mutation (dead guard)" exit 1 = job RED; self-heal trap restored the subject (tree clean after)
2026-09-17T06:54:44Z | ALIVE | exp/chicago-ci-falsifier-49 @ 3542fa9 (+ format repair 3594f2b; ticket commit follows) | incoming HEAD was format-RED (223e7df left 2 suites unformatted) -> repair committed first 3594f2b, 10/10 on both suites; gates on 3542fa9: mix compile --warnings-as-errors=0, mix test=0 (842 passed, 5 doctests), npm test=0 (258 passed), mix format --check-formatted=0, actionlint=0, yamllint=0 (no new findings; pre-existing warnings unchanged), falsifier=0 | workflow job wired: `falsifier` timeout-minutes: 5, pins mirror .tool-versions (28.3 / 1.20.3), no npm bootstrap needed (subset avoids zod-importing e2e tests) | remaining: none — DONE
