# Wave 3 RE: ported census order-dependence

Standing: PASS

Subject: test/ash_surface/ported/{top,codegen,resource,manifest,rpc/rfp}, current tree
(2026-11-12, other lanes editing lib concurrently), `MIX_BUILD_ROOT=_build-re` (deleted).

## Whole-directory runs (rc captured un-piped, timeout 900)

| dir | seed 0 | seed 4242 |
|---|---|---|
| top | 379 tests, 0 failures, 16 skipped rc=0 (after fixes) | 383 tests, 1 failure rc=2 -> fixed (below); filter_mapped_fields re-run 18/0 |
| codegen | 33/0 (4 skipped) rc=0 | 33/0 rc=0 |
| resource | 51/0 rc=0 | 51/0 rc=0 |
| manifest | 150/0 (1 skipped) rc=0 | 150/0 rc=0 |
| rpc/rfp | 245/0 rc=0 | 245/0 rc=0 |

First run on current tree (seed 0): top 11 failures, manifest 2, others 0. Per-file runs
were not needed: the baseline 68 no longer reproduces.

## Classification

- (d) transient/stale snapshot: top/custom_types_test (10) and type_mapping_overrides (1)
  failed against a mid-edit test/lib state; on disk they already pin z.number().int() /
  z.record(...) / customId; re-run 0 failures. manifest persist_resource_lookups (2 flaky
  results) passed on re-run (digest/profile mid-edit by another lane).
- (a) stale premise: manifest/codegen_type_dispatch_surface_test:182 expected
  `z.record(z.string(), z.any())`; lib zod_type.ex maps "map" to `z.unknown()`. Re-pinned.
- (b) shared state: top/support/t1.exs node_accepts/kinds tmp dir used only
  `System.unique_integer` (per-VM), colliding with a concurrent VM (File.LinkError on
  node_modules symlink). Added `System.pid()` to both dir names. Same pattern remains in
  other test files outside scope (route_schema_test, inference_test, etc.): UNVERIFIED risk.
- (c) real lib defect: none found.
- Environment: no scratch copies used; node_modules from shared checkout.

## Not run
Final post-fix re-run of full top at seed 4242 (only filter_mapped_fields_test.exs, 18/0):
UNVERIFIED.
