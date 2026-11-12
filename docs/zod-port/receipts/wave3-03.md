# Wave 3 Lane 03 Receipt

Standing: PASS

## Files

- lib/mix/tasks/ash_surface.codegen.ex (--runtime/--no-runtime, default on; runtime files
  merged into targets so write-on-diff and --check cover them)
- package.json (exports: ./runtime, ./http-transport, ./channel-transport, ./package.json)
- test/ash_surface/codegen_runtime_copy_test.exs (new), codegen_task_test.exs (one test
  now passes --no-runtime to keep its single-file diff assertion)

## Commands

`MIX_BUILD_ROOT=_build-w303 mix test` on the three files above: 22 tests, 0 failures (final run).

## UNVERIFIED

- package-lock.json not touched (exports change needs no lock edit).
- lib/ash_surface.ex untouched: task reads priv/static via Application.app_dir directly.

## Requests

- CONTRACT lane 15 does not mention running the Expo projector from the task: not added.
- generated_artifacts_exec_test.exs (lane b1a) may need --no-runtime or to expect the
  three extra files in the output dir.
