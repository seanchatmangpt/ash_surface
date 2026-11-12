# Wave 3 RF Census Receipt

Standing: PASS

Lane RF, MIX_BUILD_ROOT=_build-rf (deleted). Subject: test/*.exs + test/ash_surface/**
excluding ported/** and *_igniter_idempotence_court_test.exs; 299 files, 6 chunks of 50.

## Runs (exit codes un-piped, timeout 900)

- aa (first run): rc=1, VM abort with no summary (AuditTrail.Dsl.Event.__struct__/0): I02.
  24 top-level ash_a2a/ash_r2rml/audit_trail/notification_extension files are the I02
  cluster; recorded, not fixed, not re-run. Remaining 26 files (aa2): 118 tests.
- ab 456 tests/35 doctests/5 props, 0 failures after fix; ac 446 tests, rc=0;
  ad 541 tests/13 doctests/9 props, 0 failures after fix, rc=0; ae 369 tests, rc=0;
  af 674 tests, rc=0 (re-run). aa2 118 tests, rc=0 (with AEX_PACK_ROOT).

## Failures and class

- CompilerTest "IR assembly" and CompilerCoverageTest inputs (a): IR inputs gained
  `required` key; re-pinned (`required: true` / `required: nil`).
- TS.ZodCodegenTest "passes ZodGuard.admit" (a): CE response_zod emits
  `*_response_schema` without `.passthrough()`; lazy regex spanned to a doc comment.
  Regex bounded by `(?!export const)`.
- SparkDeadSurfaceCourtTest (d): packs/ash-extension-pack not under this repo; passes with
  AEX_PACK_ROOT=~/ggen-marketplace/packs/ash-extension-pack (environment, test unchanged).
- af 5 failures (ExpoActions x2, VoiceKiosk, GeneratedArtifactsExec, ManifestTransformers)
  (d): did not reproduce in isolation, nor on the full chunk with the failing seed
  651011 and a fresh seed; coincided with concurrent lane edits of lib/ash_surface.ex
  decorate_manifest. Transient.

## Edits

test/ash_surface/compiler_test.exs, compiler_coverage_test.exs, ts/zod_codegen_test.exs.
No lib edits.

Not run: *_igniter_idempotence_court_test.exs (lane CP), ported/** (lane RE), the 24 I02
files (UNVERIFIED), test/conformance, test/js, test/ts.
