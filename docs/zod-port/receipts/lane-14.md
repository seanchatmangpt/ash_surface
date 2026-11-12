# Lane 14 Receipt

Standing: PASS

Files: lib/ash_surface/config.ex, lib/ash_surface/config/verifier.ex,
test/ash_surface/config_test.exs (all new).

Command: `MIX_BUILD_ROOT=_build-lane14 mix test test/ash_surface/config_test.exs`
Output tail: `3 tests, 0 failures` (exit 0; compile warnings from inference.ex are lane 18's).
_build-lane14 deleted.

Notes: valibot/manifest keys omitted. Override spec shapes accepted: `%{import:, name:}` or
`{import, name}`. Verifier is a plain module (`verify/0`, `verify!/0`), not wired into startup.

Requests: none.

Falsifiers: default zod_object_mode is :strip; :loose is rejected; override without import or
with non-identifier name is rejected (all tested).
