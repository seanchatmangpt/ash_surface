# Wave 3 RAW: repair of RAD pagination and ForbiddenField survivors

Standing: PARTIAL_ALIVE

Edited tests only (no lib change): rpc/d/rpc_validate_action_surface_test.exs (+4 tests P2,P3,P4,P6),
rpc/a/forbidden_field_redaction_test.exs (+5 tests F1-F5). Real Todo/TodoMetadata resources, no mocks.

Commands (MIX_BUILD_ROOT=_build-raw, deleted after):
- `mix test <2 files>`: rc=0, 26 tests, 0 failures.
- Mutations applied in-memory (Code.compile_string via `mix do run -r /tmp/raw/mut.exs + test`);
  lib sha256 baseline == after (both files OK). Each "applied" confirmed (NOOP raises).

| id | result |
|---|---|
| P2 | red (rc=2, 1 failure) |
| P4 | red |
| P6 | red |
| F1 | red |
| F2 | red |
| F3 | red |
| F4 | red |
| F5 | red |
| P3 | green: equivalent mutant |

P3 equivalence: unknown page keys reach `Enum.map(&to_string/1)` already as binaries
(FieldFormatter input parse), so to_string is identity; the test still pins binary keys.

`mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0). Full suite not run (UNVERIFIED).
