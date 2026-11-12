# Wave 3 RK: flaky file, stray probes, codegen determinism

Standing: PARTIAL_ALIVE

## (a) typed_controller_results_fail_test.exs flake

- Alone x8 (`MIX_BUILD_ROOT=_build-rk mix test <file>`): 8/8 rc=0, 8 tests 0 failures each.
- Directory x3 (`test/ash_surface/ported/ts/should_fail`): 3/3 rc=0, 19 tests 0 failures.
- The 4 intermittent failures did NOT reproduce on this tree. skmutb recorded them under fleet
  load average 90-190; root cause UNVERIFIED (load-driven node/zod harness timing is the only
  candidate, not witnessed). No edit made to this file. Failing assertions not captured (none).

## (b) probe files

| file | present on disk | author lane | ledger/test refs | runtime | recommendation |
|---|---|---|---|---|---|
| ported/rpc/a/zz_probe_test.exs | no | in-flight probes (named by wave3-skmutb.md) | none in parity/ or receipts beyond skmutb | 60 s timeout (skmutb) | already absent; keep deleted |
| ported/rpc/c/zz_probe_test.exs | no | same | none | same | already absent; keep deleted |
| ported/**/gu8d_probe_test.exs | no | lane GU8D (`/tmp/gu8d_probe.exs` listed as scratch in jira INTEGRATION-PLAN.md) | none | n/a | already absent; keep deleted |

`find . -name '*probe*test*'` (excluding deps/_build) finds only a ggen pack fixture. No files
deleted by this lane.

## (c) codegen_determinism_test.exs

- Baseline: 1 test, 287.9 s, rc=0 (13 IR compiles).
- Profile: Ash.Info.Manifest.generate 0.68 s; Compiler.compile 23.2 s per call. Cost = repeated
  full IR compile, not manifest generation or igniter.
- Change: 13 -> 5 hashes (3 fresh-manifest + 2 shared-manifest), matching the ledger row text
  ("5 hashes"); timeout 600 s -> 240 s. Still in the default gate (no tag), ledger unchanged.
- After: 1 test, 0 failures, 106.3 s, rc=0.
- Residual: 106 s still heavy; further cut needs a faster Compiler.compile (UNVERIFIED).

_build-rk deleted at end.
