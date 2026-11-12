# Wave 3 Lane RBJ Receipt (full-suite census)

Standing: PARTIAL

Seed 0, `MIX_BUILD_ROOT=_build-rbj`, Elixir 1.19.5, deps ash_a2a 26.9.31 (hex).

## Full `mix test` (working tree)
rc=1, no summary line: the runner dies mid-stream (EXIT, `AuditTrail.Dsl.Event.__struct__/0`
undefined) after 9+ setup/test failures in `test/{ash_a2a,ash_r2rml,audit_trail,
notification_extension}_*` court/composition files. Cause: hex ash_a2a lacks
`AshA2A.Dsl.Info`/`Persist` transformer; ash_r2rml Persist refuses the data layer; no
audit_trail/notification_extension modules exist. Not session-touched beyond whitespace
(ash_a2a_composition_test diff is blank-line only). Substrate-dependent, pre-existing.

## Census excluding those 4 families (explicit file list, seed 0)
48 doctests, 23 properties, 5805 tests, 4 failures, 267 skipped (rc=2).
1. conformance_replay_test:90 and :126 -- filter_operators.json (untracked, wave3-04) drifted:
   f1en later admitted gt/gte/lt/lte on string fields; regenerate via conformance_regen.exs.
   SESSION-INTRODUCED.
2. route_channel_adversarial_test:122 -- 53 cases: key `p_1` vs schema `p1`
   (digit-after-underscore name mapping; owners s2b/ci). Deterministic. SESSION-INTRODUCED.
3. rbh/pins_test:149 -- `:count` nil in InvalidToken vars; passes in isolation, fails in
   full order: order-dependent. SESSION-INTRODUCED (rbh).

## HEAD baseline: UNVERIFIED
`git archive HEAD` omits ~126k untracked files and the tree crashes at compile (Spark.Options
one_of) / JS runtime absent; its 9 failures are archive artifacts, not a baseline.
