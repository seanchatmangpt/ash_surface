# Wave 3 F1-triage-b: Per-file test failure census

Standing: PARTIAL

PARTIAL because the census is per-file at a moving tree (lanes editing lib/ throughout);
2 files compile-abort, 4 time out at 300s, 19 files carry real failures. Not a single-SHA run.

## Method

Full `mix test` aborts at VM exit with no summary, so each of 262 `test/**/*_test.exs` files
was run alone: `MIX_BUILD_ROOT=_build-f1tb timeout 300 mix test <file>`, 3 files in parallel via
`xargs -P3` after a sequential warm `MIX_ENV=test mix compile` (exit 0). Polling used a
deadline-bounded `read -t` loop, no sleep. Per-file logs: /tmp/f1tb/*.log; results:
/tmp/f1tb/results.txt, /tmp/f1tb/r1/results_full.txt.

Pass 1 (all 262): 217 PASS, 13 FAIL, 28 COMPILE-ABORT, 4 no-summary (3 were passes: props/doctest).
Of the 28 aborts, 27 were `SyntaxError` in lib/ash_surface/runtime_parity/rpc/pipeline.ex
(another lane's in-flight edit, mtime 22:37; compile-abort, not counted as failures) and 1 a
DslError in the idempotence court. After pipeline.ex compiled again (poll, ok), the 42 non-pass
files were re-run (pass 2). Rows below are the final state (pass 2 overrides pass 1).

Earlier in the run (22:12) test/support/ported/resources/todo.ex had a DslError
(`accept [:hierarchy, :strict_hierarchy]`); fixed in-flight by its owner before the final passes.

## Totals (final)

- files: 262 = 237 PASS, 19 FAIL, 4 TIMEOUT-300s, 2 COMPILE-ABORT
- tests (sum of per-file `N tests` summaries, incl. failing files): 2415; failures 34; invalid (setup_all) 11; skipped 6
- doctests/properties files (doctest_test, codec_props, transport_props) counted PASS from their own summaries, not in the test sum

## Non-passing files (classification)

| file | status | tests | fail | invalid | classification |
|---|---|---|---|---|---|
| test/ash_a2a_composition_test.exs | FAIL (rc=2) | 2 | 2 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_a2a_spark_parity_court_test.exs | FAIL (rc=2) | 2 | 1 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_a2a_transformer_court_test.exs | FAIL (rc=2) | 3 | 0 | 3 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_r2rml_composition_test.exs | FAIL (rc=2) | 2 | 0 | 2 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_r2rml_igniter_idempotence_court_test.exs | TIMEOUT-300s (rc=124) | 0 | 0 | 0 | UNOWNED: exceeds 300s (not a failure count); ash_surface_igniter one passed earlier lanes? UNVERIFIED |
| test/ash_r2rml_spark_parity_court_test.exs | FAIL (rc=2) | 2 | 1 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_r2rml_transformer_court_test.exs | FAIL (rc=2) | 3 | 3 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_r2rml_verifier_court_test.exs | FAIL (rc=2) | 3 | 2 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/ash_surface/compiler/schema_section_test.exs | FAIL (rc=2) | 23 | 2 | 0 | KNOWN: wave3-f1r.md / wave3-f1rw.md cite schema_section_test (z.unknown vs z.any, enum fabrication, allow_nil key) |
| test/ash_surface/error_type_parity/error_type_parity_test.exs | FAIL (rc=2) | 6 | 1 | 0 | KNOWN: wave3-f1rp.md cites error_type_parity |
| test/ash_surface/projectors_coverage_test.exs | FAIL (rc=2) | 14 | 2 | 0 | UNOWNED: no receipt cites it (Expo project/1 match failure :180,:189) |
| test/ash_surface/schema_section_test.exs | FAIL (rc=2) | 18 | 10 | 0 | KNOWN: wave3-f1r.md / wave3-f1rw.md cite schema_section_test (z.unknown vs z.any, enum fabrication, allow_nil key) |
| test/ash_surface/zod_type_parity_test.exs | FAIL (rc=2) | 3 | 1 | 0 | UNOWNED: no receipt cites it; ZodTypeParity "agree on every kind" =~ failure, likely zod_type kind lane (F1-kindiv) in flight |
| test/ash_surface_igniter_idempotence_court_test.exs | TIMEOUT-300s (rc=124) | 0 | 0 | 0 | UNOWNED: exceeds 300s (not a failure count); ash_surface_igniter one passed earlier lanes? UNVERIFIED |
| test/ash_surface_transformer_court_test.exs | FAIL (rc=2) | 3 | 1 | 0 | UNOWNED: determinism court :212 (drafts persist different state); possibly lib/ in-flight |
| test/audit_trail_composition_test.exs | FAIL (rc=2) | 4 | 4 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/audit_trail_igniter_idempotence_court_test.exs | TIMEOUT-300s (rc=124) | 0 | 0 | 0 | UNOWNED: exceeds 300s (not a failure count); ash_surface_igniter one passed earlier lanes? UNVERIFIED |
| test/audit_trail_spark_parity_court_test.exs | FAIL (rc=2) | 2 | 1 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/audit_trail_transformer_court_test.exs | FAIL (rc=2) | 3 | 0 | 3 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/audit_trail_verifier_court_test.exs | COMPILE-ABORT (rc=1) | 0 | 0 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/notification_extension_composition_test.exs | FAIL (rc=2) | 2 | 2 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/notification_extension_igniter_idempotence_court_test.exs | TIMEOUT-300s (rc=124) | 0 | 0 | 0 | UNOWNED: exceeds 300s (not a failure count); ash_surface_igniter one passed earlier lanes? UNVERIFIED |
| test/notification_extension_spark_parity_court_test.exs | FAIL (rc=2) | 2 | 1 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/notification_extension_transformer_court_test.exs | FAIL (rc=2) | 3 | 0 | 3 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |
| test/notification_extension_verifier_court_test.exs | COMPILE-ABORT (rc=1) | 0 | 0 | 0 | UNOWNED-pre-existing: extension fixture family (Dsl/Info modules absent, Persist transformer on fixture); not zod-port |

Known-failure cross-check: validator_action_types_test.exs (:139 failure reported earlier)
is rc=0 in pass 1 (PASS at this tree state). schema_section_test.exs:311 (compiler/ variant)
and :148-:310 (top-level, 10 failures) still fail: owner wave3-f1r/f1rw (z.unknown vs z.any).
wave3-01.md's 9 failures were in the ir/compiler set; none of the ir_* / compiler_* /
digest / no_local_do / mock_discipline files fail now.

Unowned defects needing a lane: zod_type_parity_test:6, projectors_coverage_test:180/:189,
ash_surface_transformer_court_test:212, and the four idempotence courts (300s timeout).
The ash_a2a / ash_r2rml / audit_trail / notification_extension families (15 files) are a
separate extension-fixture cluster (missing `*.Dsl.Info`/`Dsl.Event` modules, r2rml Persist
transformer refusing the fixture data layer, transformer-source path not found); no zod-port
receipt references them: UNOWNED, pre-existing as far as receipts show (not verified at baseline).

## Proposed floors (PROPOSED, not set; set after lanes drain and a clean re-run)

- scripts/chicago_census.txt `# floor:` currently 1424 -> propose 2415 (per-file sum above).
  Caveat: excludes 4 timeout + 2 compile-abort files and counts tests in failing files; the
  real `mix test` total is UNVERIFIED (no summary line obtainable).
- TESTING.md line 4 text: replace the `no summary line` clause with: per-file census at
  2026-11-11: 2415 tests across 256 summarising files, 34 failures, 11 invalid,
  4 files >300s, 2 compile-aborts; pinned floor 1424 -> proposed 2415.

## Commands and exit codes

- `MIX_BUILD_ROOT=_build-f1tb mix compile` rc=0 (dev deps from scratch)
- `MIX_ENV=test MIX_BUILD_ROOT=_build-f1tb mix compile`: rc=1 at 22:12 (todo.ex DslError, in-flight),
  rc=0 on retry; rc=1 during pipeline.ex SyntaxError window, rc=0 after poll
- 262 x `mix test <file>`: rc distribution in table (rc 0 PASS, 2 FAIL, 1 compile-abort, 124 timeout)
- re-run of 42 non-pass files: results.txt (42 lines)

## Falsifiers

Re-running any FAIL row at a quiescent tree and getting rc=0 retracts that row; a SHA-bound
receipt is absent because lanes were mid-edit (no git state commands used).

## See Also

[[wave3-01]] · [[wave3-f1r]] · [[wave3-f1rw]] · [[wave3-f1rp]]
