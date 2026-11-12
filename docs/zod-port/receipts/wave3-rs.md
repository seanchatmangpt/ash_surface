# Wave 3 RS: cross-VM-unique test temp paths

Standing: PASS

Subject: test/ + test/support only (no lib), current tree 2026-11-12.

## Change
- New `test/support/test_tmp.ex` (`AshSurface.TestTmp`): `suffix/0` (pid + unique_integer +
  monotonic + os_time), `unique_dir/2` (fresh dir, retries on :eexist, on_exit rm_rf),
  `scoped/1` (fixed path -> `<path>-<pid>`), `sweep/0` (removes only this pid's leftovers,
  run via `ExUnit.after_suite` in test/test_helper.exs).
- ~85 test/support files: path-building `System.unique_integer` -> `TestTmp.suffix()`;
  12 fixed `_build/test/...` attrs wrapped in `scoped/1`; fixed
  `ash_surface_install_failure.txt` made unique; t1.exs/t2.exs use `unique_dir/1`
  (also resists stale dirs from earlier runs, per RM).

## Verification (rc un-piped, two concurrent VMs, MIX_BUILD_ROOT _build-rsA/_build-rsB)
- Both VMs, same files (ported/top, compiler, parity, route_schema, inference, errors,
  codegen_task, expo): rc=0 / rc=0, 834 tests, 0 failures, 16 skipped each, seed 4242.
  LinkError/eexist count in logs: 0.
- `mix test test/ash_surface/ported/top --seed 4242`: rc=0, 384 tests, 0 failures, 16 skipped.
- Remaining grep of unique_integer on path lines excluding TestTmp/pid-carrying
  (`:os.getpid`/`System.pid`) sites: 0 matches. Non-path uses (module/atom/telemetry names)
  left unchanged.

## Not run
Full-suite run: UNVERIFIED. Build roots deleted.
