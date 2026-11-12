# Wave 3 Lane CU (I21) Receipt

Standing: PASS

Docs-only. Refreshed the `## Attribution` section of
`docs/jira/v26.11.11/INTEGRATION-PLAN.md` from a fresh read-only
`git status --porcelain -uall`. No mix runs, no git state changes, no tests run
(tests UNVERIFIED by design: docs-only lane). Contract: `/tmp/census_contract.txt`.

## Result

- Paths at read time: 880 untracked + 106 modified = 986 (peer session may change this).
- OWNED=939, GENERATED=22 (11 untracked + 11 modified vectors/inventory), SCRATCH=1
  (`304_trial.mjs`), UNKNOWN=24.
- Of the 23 previously-UNKNOWN files: 22 resolved by receipt (wave3-t0, g3b, f1k, g6, f1gh/q1,
  f1rf, 16, 05, 06, lane-19, f1d); 1 stays UNKNOWN
  (`test/js/transport_phase_classification.test.mjs`, no receipt names it).
- Remaining UNKNOWN: 4 untracked (above plus `envelope_test.exs`,
  `js_embedded_filter_export_test.exs`, `test/support/ported/ash_names.ex`) and 20 modified
  tracked files with no naming receipt; listed as operator questions in the plan.
- Method: path, brace-list expansion, basename, directory/stem-token (weak) matching over
  `docs/zod-port/**` and `docs/jira/v26.11.11/**`; script `/tmp/cu_attrib.py` (scratch).
- Cleanup inventory (read-only): 20 `_build-*` dirs (~2.8 GB; cr/cs/ct/cv likely in-flight) and
  /tmp lane scratch listed in the plan; deletion left to the coordinator.

## Falsifiers

Weak OWNED rows rest on directory evidence; a wrong lane attribution there would not break
staging protocol but should be spot-checked at integration. Re-run `git status --porcelain`
before staging.
