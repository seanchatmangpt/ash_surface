# Wave 3 Lane F1-atomflake receipt

Standing: PARTIAL

## Subject

`test/ash_surface/runtime_parity/field_selection_test.exs`, test "atomizing never mints atoms".

## Cause (UNVERIFIED reproduction)

The test bounded the global `:erlang.system_info(:atom_count)` delta (< 50). That counter is
VM-global; other `async: true` modules mint atoms concurrently, so the bound measures the
neighbours. Reproduction attempt: one combined run of runtime_parity + parity_deepen +
naming_test (112 tests, 0 failures) did not reproduce the 275-delta; flake is load-dependent
and was not re-witnessed, so the cause is inferred from the assertion shape, not observed.

## Change

Removed the global atom-count bound. Replaced with a structural proof: hostile names
(camelCase, snake_case, nested-map key; built at runtime with a unique integer so no literal
interns them) go through `atomize_requested_fields`; results must equal the input strings
and `String.to_existing_atom/1` must raise `ArgumentError` for every hostile name and its
snake_case form afterwards. The property (never mints) is strictly stronger and race-free.
No sleeps, no mocks.

## Commands and exits (MIX_BUILD_ROOT=_build-f1af, since deleted)

- `mix test test/ash_surface/runtime_parity/field_selection_test.exs`: 9 tests, 0 failures, rc 0.
- Combined set `runtime_parity parity_deepen naming_test field_name_test compiler projector`
  x4 (post-fix): 504 tests, 1 failure each, rc 2. The one failure is
  `SchemaSectionTest` "per-argument zod fragments match the live projector emission"
  (another lane's in-flight work); the atomizer test passed all 4 runs.
- Runs 5-7: BLOCKED, compile error `lib/ash_surface/runtime_parity/rpc/pipeline.ex:1115`
  (unexpected `end`, another lane's in-flight file), rc 1.
- Full `mix test`: BLOCKED pre-existing, duplicate test name in
  `test/ash_surface/ported/rpc/run_action/rpc_run_action_crud_gap_test.exs:42`.

## Gap

Requested >=5 combined green runs: 4 achieved with the atomizer test green (suite not fully
green due to the unrelated failure above); remaining runs blocked by pipeline.ex.
Re-run once that file compiles.
