# SHIM-COURTS

Shim courts prove the zod-port gates and courts can FAIL. Port of smalt `scripts/shim_court/lib.sh`.

## Protocol

BASELINE sha256 -> BEFORE (guard test green) -> SHIM (marked `SHIM-COURT`) -> AFTER (guard
test must go red with a real failure, not a compile error) -> RESTORE (sha256 byte-exact,
fail-closed, trap on interrupt). A court that cannot flip is `[FAIL:AFTER]`; a missing
environment is `[SKIP] <reason>` (exit 3), never a pass.

## Divergence from smalt

Every shim lands in a `/tmp` scratch copy (`cp -R` of lib, test, priv, config, conformance,
parity, docs; `deps` and `node_modules` symlinked; `_build/test` seeded). The live tree is
never written; `shim_live_guard` fails closed if `SHIM-COURT` appears in the live file.

## Courts

| court | shimmed file | guard |
|---|---|---|
| 01_zod_type | compiler/zod_type.ex (numeric `.min(` to `.max(`) | schema_constraint_test (numeric describe) |
| 02_union_schema | compiler/union_schema.ex (discriminator literal dropped) | union_schema_test |
| 03_zod_guard | projectors/js/zod_guard.ex (`min` removed from allow-list) | zod_guard_test |
| 04_errors | errors.ex (Policy redaction removed) | errors_test, errors_config_test, errors_s1b_test |
| 05_runtime_transport | priv/static/ash_surface_runtime.mjs (outcome flipped) | test/js/transport_law.test.mjs |
| 06_conformance_vector | conformance/vectors/transport_outcome.json (leaf altered) | conformance_replay (post-dispatch) |
| 07_parity_gate | scratch-only one-capability court map (mapping deleted) | AshSurface.Parity.Report |

## Run

    bash scripts/shim_court/run_all.sh        # exit 1 on any FAIL; SKIPs counted loudly
    bash scripts/shim_court/courts/NN_*.sh    # one court

Self-check: `test/ash_surface/shim_court_selfcheck_test.exs`.

## See Also

`receipts/wave3-q2.md`
