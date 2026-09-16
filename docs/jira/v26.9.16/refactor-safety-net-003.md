# refactor-safety-net-003: t-wave canary + preservation
status: OPEN
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of v41.) Prove the chicago-wave law suites survive the v26.9.16 refactor: full mix test + npm test green; test/ash_surface/refactor_safety_net_test.exs asserts each load-bearing file EXISTS at canonical path (transport_select/fallback/outcome/falsifiers, digest, golden_stability, validator, validator_adversarial) — the canary that integration dropped nothing. Fix expectation-drift ONLY (no lib edits), each change receipted.
## Acceptance
- mix test -> 0; npm test -> 0; canary suite green
## History
