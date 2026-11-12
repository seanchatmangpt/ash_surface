# Wave 3-16 idempotence court

Standing: PASS

Lane W3-16b (finishes stopped W3-16). Prior-lane inspection: no wave3-16 receipt or
idempotence file existed on disk; the other untracked wave3 tests (zod_type_wave3,
expo_wave3_s1h_court) belong to other lanes and were not touched.

Subject: `test/ash_surface/idempotence_court_wave3_test.exs` (new, 6 tests, Chicago, no mocks,
no sleeps; subprocesses bounded by `Task.yield` deadlines of 300 s).

Covered: compiler twice (IR equality and digests), codec fixed point (JSON bytes and digest),
JS projector x4 plus reversed input, `write_artifacts` twice and rewrite, real node + zod
import of two regenerated artifacts (identical export surface), and the conformance corpus
regenerator (`scripts/conformance_regen.exs`, ggen-owned vectors) run twice in real
subprocesses into scratch dirs, trees byte-identical.

Commands (MIX_BUILD_ROOT=_build-w316b, MIX_ENV=test):
- `mix test test/ash_surface/idempotence_court_wave3_test.exs` -> exit 0, 6 tests, 0 failures
  (58.1 s); rerun 43.5 s; final rerun after unused-helper cleanup (cold deps) 128.6 s, 6 tests, 0 failures, no warnings from the test file.

Build root `_build-w316b` deleted. No git state commands run.
