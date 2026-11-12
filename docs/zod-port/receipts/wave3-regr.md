# Wave 3 Lane REG-refill: PARITY-REGISTER refill from receipts

Standing: PASS

## Files

- docs/jira/v26.11.11/PARITY-REGISTER.md (the register; docs/zod-port has no copy)

## Changes

- IR-wiring row: IN-FLIGHT-AT-FILL -> PARTIAL, from wave3-01.md (Standing PARTIAL).
- `compiler/ir.ex` call-site line refs re-read after w3-01 (230/318/341/355/377/387 ->
  244/335/358/373/396/406).
- Fill-gate paragraph and provenance line updated.
- Every other row's cited receipts re-read: Standings matched (33 receipts); no row dropped.
- All cited lib files exist on disk; ir.ex call sites grepped.

## Not done

- Other lib line refs (non-ir.ex) not re-grepped. No mix gate run (docs only).
- D-L24-2 untracked status not checked (no git state commands).
