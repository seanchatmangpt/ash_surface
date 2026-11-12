# Wave 3 RBS: FieldName deviations vs reference (KD register check)

Standing: PASS

Register grep (docs/KNOWN_DIVERGENCES.md, parity/court_map.json): none of the three deviations
had a KD row (court_map only maps `runtime.module.FieldFormatter` as pass).

## Verdicts

1. Trailing `?`: NO harm witnessed, ALIGNED (kept, like the reference). Keys with `?` are
   quoted by the renderer (valid JS/zod); stripping broke the built-in inverse
   (`isReady` -> `:is_ready`, not `:is_ready?`). The reference also refuses unmapped `?`
   attribute names upstream (VerifyFieldNames), so no capability is lost. `FieldName.clean/1`
   no longer strips.
2. Leading `_`: HARM witnessed, KD-13 registered. Reference rule run in memory as a real
   custom formatter: `x` and `_x` share key `x`; admitted-set inverse returns `:error` for
   both. Court: test/ash_surface/divergence_close/leading_underscore_divergence_test.exs.
3. `Foo_bar`/`a_B` (and `A_b`): ALIGNED to `Macro.camelize` + lowercase-first (`fooBar`,
   `a_B`, `aB`). Reference non-injectivity (`Foo_bar`/`foo_bar`, `A_b`/`a_b`) is refused by
   the court: `RouteSchema.build` -> `emitted_key_collision`, `client_to_internal` ->
   `collision`, `format_checked` -> `not_invertible`.

## Change (disclosed)

lib/ash_surface/field_name.ex (`clean/1`, `camelize/2`); tests updated for `?` kept:
field_name_test, rbh/pins_test (I5), field_name_precedence_error_spelling_test,
formatter_scope_errors_tasks_test, field_naming_divergence_test, route_channel_adversarial_test
(oracle now pure reference + leading `_`). New KD-13 row + court.
Conformance vectors need regeneration (NOT run; coordinator).

## Verification (MIX_BUILD_ROOT=_build-rbs, rc un-piped)

- mix test ported/rpc adversarial divergence_close field_name_test: 2309 tests, 0 failures,
  213 skipped, rc=0.
- mix ash_surface.parity.tests rc=0 unaccounted=0 broken=0 (pre-existing parity MISSING rows
  are installer/typed_controller options, unrelated).
- Shim-court (/tmp/rbs/fn_mut.ex, in-memory recompile, sha256 b8cdb92f78b90857 == restore):
  BEFORE `_x`/`{:ok,:x}`; SHIM `x`/`:error`; AFTER restored.
