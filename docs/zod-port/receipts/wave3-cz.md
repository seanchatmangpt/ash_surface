# Wave 3 CZ: emitted-key collision per renderer

Standing: PASS

Subject: /Users/sac/ash_surface working tree (no commit SHA; coordinator owns git).

## Probes (mix run, MIX_BUILD_ROOT=_build-cz, exit 0)

- RecordSchema: resource with `foo_bar` + `fooBar` rendered
  `z.object({ id, fooBar: ..., fooBar: ... })` silently (names pre-emitted, so the embedded
  check saw equal keys). WIRED: `RecordSchema.check_collisions/1` on raw names ->
  `{:emitted_key_collision, {:record, Mod}, "fooBar", ["fooBar","foo_bar"]}`.
- ResourceFacts calc args / public_attributes pre-emit names (duplicate `aB`,`aB` observed);
  CalculationSchema already refuses (`calc_name_duplicate`, `arg_name_duplicate`).
- Relationship load (`duplicate_relationship`), route args (`duplicate_argument`): refused.
- Calculation, relationship, route, sort, filter, get take wire names verbatim: distinct
  names stay distinct keys (no formatter in the renderer), asserted.
- Channel: payload fields go through EmbeddedSchema (CX wiring); event-name identifier
  clashes refused by `payload_name_conflict`.
- Upstream: `FieldName.action_inverse` -> `field_name_collision` (KD-09) asserted.
- Not wired (harmless, same-name only): filter `z.enum` and sort regex tolerate repeated
  identical names; not distinct-name collisions.

## Commands

- `mix test test/ash_surface/compiler/emitted_key_collision_renderers_test.exs`: 10 tests, 0 failures.
- `mix test test/ash_surface/compiler` (un-piped to file): exit 0, 314 tests, 0 failures.

Files: lib/ash_surface/compiler/record_schema.ex (edit), the test file above (new).
- RecordSchema-referencing test files (grep): exit 0, 121 tests, 0 failures, 2 skipped.
