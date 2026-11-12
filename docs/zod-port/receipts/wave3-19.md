# Wave 3 Lane 19: TESTING.md floor and census

Standing: PARTIAL

## Files

- `TESTING.md` (edited: path citations, line-4 suite count, withheld-court paragraph)
- `scripts/chicago_census.txt`, `scripts/zero_config_v2.sh`: not touched

## Commands and output

- `MIX_BUILD_ROOT=_build-w319 mix test test/ash_surface/path_truth_test.exs`
  after the TESTING.md fix: `3 tests, 0 failures`, rc=0 (D-06 closed).
  Fix: the three `~/xaas/.../w901*` and `w984mf*` plan citations exist outside the tree and now
  carry `[INTEGRATION]`; the `/tmp/ash_surface_court_quarantine/` and `lib/generated` citations
  were reworded without path backticks.
- Full suite, `MIX_BUILD_ROOT=_build-w319 mix test > /tmp/w319_full.txt`:
  - Run 1: exit 1, compile error in `test/ash_surface/ts/inference_tsc_test.exs` (another lane's
    in-flight untracked file); it parsed clean on re-check, so it was transient.
  - Run 2: exit 1, 45 failures printed, NO `N tests, M failures` summary line. The
    `AuditTrail.Dsl.Event.__struct__/0` VM-exit abort did not reproduce in this run (grep found
    only source-listing mentions); the stream simply stops at exit 1.
- Failing modules by count: ActionIdTest 4, DigestTest 6, SchemaSectionTest 6, AshSurfaceTest 3,
  AshR2RML.ResourceTransformerClosureCourt 3, AuditTrail.ResourceCompositionTest 4,
  NotificationExtension.ResourceCompositionTest 2, AshA2A.DslCompositionTest 2, BoundaryHardeningTest 2,
  ConformanceReplayTest 2, and 1 each in ChannelDiscovery, FilterSchemaSize, DelegationCoverage,
  IrCodecGolden, TransportFallback, TransportFalsifiers, the 4 ResourceParityCourt modules and
  ResourceTransformerClosureCourt.
  Composition courts fail with `UndefinedFunctionError ... Resource.Info.compiled/1` (module not
  available) in audit_trail and notification_extension, which are extension projects outside this
  lane's ownership. DigestTest/ActionIdTest/SchemaSectionTest/ConformanceReplayTest/IrCodecGolden
  overlap the files other wave-3 lanes edit (session-introduced vs pre-existing NOT separated).
- Court files: 21 git-tracked `test/*_court_test.exs`-pattern files; 0 untracked. The old
  "19 withheld" statement is therefore stale; TESTING.md marks it STALE.

## TESTING.md state after this lane

- Floor unchanged at 1424 in `scripts/chicago_census.txt`; not re-measured (no summary line).
- Tracked test files: 153 `test/**/*_test.exs` (git ls-files), replacing the stated 180.

## UNVERIFIED

- Real current test count and floor (no summary line obtained).
- Cause of the missing summary: not isolated; stream ends at exit 1 after the lineage bench line.
- Pre-existing vs session-introduced attribution of the 45 failures.
- Wait-gate: wave3-01, wave3-04, wave2-b1a receipts were absent at fill (IN-FLIGHT-AT-FILL);
  wave3-02, 09, 17 were present.

## Requests

- Owners of DigestTest/ActionIdTest/SchemaSectionTest fixes: re-run the full suite once drained,
  then set the floor in `scripts/chicago_census.txt` and the line-4 count in TESTING.md.
- Extension owners (audit_trail, notification_extension): `Resource.Info` module absence.
