# Wave 3 F1-genexec receipt

Standing: PARTIAL_ALIVE

Owned file changed: `test/ash_surface/projector/generated_artifacts_exec_test.exs` (only).

## Changes

1. Race: fixed `_build/test/generated_artifacts_exec` replaced by a per-test unique dir under
   `System.tmp_dir!()` (unique integer + nanosecond clock), created in `setup`, removed in
   `on_exit`, exposed via `tmp_dir/0` (process dictionary).
2a. decimal: `lib/ash_surface/compiler/zod_type.ex` renders `z.string()`; ash_typescript
   `zod_schema_generator.ex:49` maps `Ash.Type.Decimal => "z.string()"` as well, and Ash
   JSON-encodes Decimal as a string. Renderer is correct; test re-pinned to valid `"2"`, `"0.25"`,
   invalid `2`, `0.25`, `nil`.
2b. untyped: node check with zod 4.6.5: `z.object({a: z.unknown()}).safeParse({})` and the
   `z.any()` form (ash_typescript's choice) both fail, so both treat the key as required. Lib behavior
   matches ash_typescript; the test now supplies the key (`{"u": nil}`) and `invalid_missing/1`
   no longer exempts the exotic kind. Removed a stale "unresolved" case (not in the action list;
   unresolved resources are a typed error since M9) that the earlier failure had masked.
3. Runtime shim: `install_runtime_shim!` copies the runtime/http/channel `.mjs` files and links zod;
   passes in isolation.

## Commands (MIX_BUILD_ROOT=_build-f1g, removed afterwards)

- exec test, 3 serial runs: rc=0, rc=0, rc=0; each 18 tests, 0 failures.
- 2 concurrent OS processes (_build-f1g and _build-f1g2): both rc=0, 18 tests, 0 failures.
- `mix test test/ash_surface/projector/ test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs`: rc=2, 97 tests, 1 failure (not in owned file; below).
- `mix format --check-formatted` on the owned file: rc=0.

## Defect requests (not owned)

- `test/ash_surface/projector/expo_client_reconcile_test.exs:35` fails: generated
  `ash_surface_http_transport.mjs:75` throws `CROSS_ORIGIN_ENDPOINT` for `http://127.0.0.1:<port>`
  (expected: client reconciles against the local stub; actual: pre-dispatch refusal). Likely the
  test or `test/js/generated_client_reconcile_runner.mjs` must pass an allowed-origin option, or the
  transport's origin law needs a documented local override. Same test still uses a fixed
  `_build/test/projector_expo_client_reconcile` dir (same race class).
