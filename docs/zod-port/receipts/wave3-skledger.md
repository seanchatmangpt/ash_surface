# Wave 3 Lane SK-ledger Receipt

Standing: PASS

Skeptic audit of `parity/test_ledger.json` after T9/T11 wholesale rewrites. Result: no row
regressed, no wrong disposition, no missing test path. Audit snapshot is the live file at
audit time (the ledger was still moving: unaccounted fell 88 -> 70 during the audit).

## Mismatch table

| lane | receipt rows compared | mismatches |
|---|---|---|
| T4 | 7 manifest rows | 0 |
| T5 | 12 rfp rows | 0 |
| T6 | 7 run_action rows (skipped_gap) | 0 |
| T9 | 8 rows | 0 (receipt `lifecycle_hooks_*` = ledger `rpc/lifecycle_hooks_*`, non_goal/adapted, as claimed; the `channel_lifecycle_hooks_*` unaccounted rows are T8's, not T9's) |
| T11 | 18 rows | 0 |
| T13 | 6 typed_channel rows | 0 |
| T0, T15 | summary-only receipts | n/a (T15 ts counts agree with ledger by_dir within the fixtures-vs-ledger split) |
| T1,T2,T3,T7,T8,T10,T12,T14,T16,T17 | no receipt on disk | not auditable per-file |

Regressed lanes: none. Remaining `unaccounted` (70) are never-landed, not reverted:
T8 21, T12 17, T16 17, T1 15 (T17 drained during the audit).

## Checks

- Rows 264 == `parity/test_inventory.json` files 264; no missing/extra/duplicate files.
- JSON valid; format is indent-2, trailing newline, multi-line rows (NOT one row per line).
- Every ported/adapted row lists >=1 `ash_surface_tests` path and all exist on disk.
- Gate (`mix ash_surface.parity.tests --json`): broken=0 (so no skips in ported/adapted files);
  counts non_goal 14, ported 8, adapted 112, skipped_gap 60, unaccounted 70.
  Advisory: 43 `shallow` files reported by the gate (list in gate JSON `shallow_files`).
- Compile was green (runtime_parity/rpc/pipeline.ex not blocking).

## Commands

| command | rc |
|---|---|
| `python3 /tmp/skl.py` (ledger vs inventory vs receipts, disk existence) | 0 |
| `MIX_BUILD_ROOT=_build-skl mix ash_surface.parity.tests --json` | 1 (expected: unaccounted rows) |
