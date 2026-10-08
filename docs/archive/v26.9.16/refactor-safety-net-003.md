# refactor-safety-net-003: t-wave canary + preservation
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v41.) Prove the chicago-wave law suites survive the v26.9.16 refactor: full mix test + npm test green; test/ash_surface/refactor_safety_net_test.exs asserts each load-bearing file EXISTS at canonical path (transport_select/fallback/outcome/falsifiers, digest, golden_stability, validator, validator_adversarial) — the canary that integration dropped nothing. Fix expectation-drift ONLY (no lib edits), each change receipted.
## Acceptance
- mix test -> 0; npm test -> 0; canary suite green
## History
2026-09-16T19:29:36Z | ALIVE | exp/v41 @ 8c90365 (base 282f3ca; commits 1c5f17b drift fix, 8c90365 canary, receipt bodies in-commit) | mix test 317/317 exit 0 (canary 9/9 incl.); npm test 175/175 exit 0; canary falsified (digest hidden -> 8/9 drop msg, restored -> 9/9) | remaining: one seed-7 transient (316/317, unreproduced in 12+ reruns, diagnostic lost) — watch for recurrence; golden_stability canon-mapped to action_id_test.exs (no such file ever existed on any branch)
