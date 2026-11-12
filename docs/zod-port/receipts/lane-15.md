# Lane 15 Receipt

Standing: PARTIAL

Files: lib/mix/tasks/ash_surface.codegen.ex (new), lib/ash_surface/projectors/js.ex
(emit builds artifacts map; new public `write_artifacts/2`; `:target_dir` delegates to it),
test/ash_surface/codegen_task_test.exs (new, real tmp dirs, no mocks).

Commands: `MIX_BUILD_ROOT=_build-lane15 mix test test/ash_surface/codegen_task_test.exs`
-> 2 tests, 0 failures. Full `mix test` rc=1: failures observed in SchemaConstraintTest and
ir_codec/golden digest tests (schema keys capability_flags/error/filter/page/sort/response_zod
from other lanes' in-flight work), not in js.ex/codegen; no JS-projector failure matched.
--check/--output on a real domain app not exercised (UNVERIFIED).

Requests: none.

Falsifiers: --check on drifted file must raise; not run end to end.
