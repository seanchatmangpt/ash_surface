# Wave 3 RAX: repair of errors.ex and config.ex survivors

Standing: PARTIAL_ALIVE

Tests added to test/ash_surface/ported/rpc/a/error_protocol_surface_test.exs (new describe
"classify table and bare-message path (RAX)") and rpc/b/manifest_generator_config_test.exs
(4 default tests + env snapshot keys). Court: in-memory recompile of the mutated module
(/tmp/rax/court.exs, `mix run`, MIX_ENV=test); lib never mutated, sha256 of errors.ex and
config.ex verified unchanged after (sha256sum -c OK).

Baselines: error file 29 tests 0 failures rc=0; config file 13 tests 0 failures rc=0.

| mutation | result |
|---|---|
| E9, E11 (type and short), E12, E13, E14, E15 (type and short) | killed, rc=1 |
| E17 InvalidChanges dropped from bare list | killed, rc=1 |
| E20 scrub List.last -> join | killed (not equivalent), rc=1 |
| E21 drop :count | survives, EQUIVALENT: no struct in @table has a :count field (probed Map.keys(struct(m)) for the Ash table modules; only Ash.Error.Invalid.MultipleResults has it, not in @table), so the key never matches |
| C4-C7 suffix/object_mode/infer_types/policy_breakdowns defaults | all killed, rc=1 |

AshAuthentication table modules not loadable in this env: :count absence for them UNVERIFIED.
`mix ash_surface.parity.tests` rc=0 (unaccounted=0, broken=0). Full suite: UNVERIFIED.
