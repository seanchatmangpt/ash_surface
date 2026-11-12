# Wave 3 Lane RO Receipt

Standing: PASS

Scope: SK-fw defects 3 and 4 only (defects 1, 2, 5, 6 not touched: UNVERIFIED/open).

## Changes

- `lib/ash_surface/field_name.ex`: one precedence kernel, `override/2` behind `wire/3`.
  Reference rule (ash_typescript `FieldFormatter.compute_field_for_client`): a module exporting
  `typescript_field_names/0` is authoritative; an unlisted field falls to the formatter, never to
  the `field_names` DSL option; only without the callback does `field_names` apply.
  `format_field_for_client/3` now delegates to `wire/3` (no second kernel).
- `lib/ash_surface/errors.ex` + `error_formatter.ex` (`apply_namer/2`): with a resource and no
  explicit `:field_names` opt, error `fields`, `path` and `vars.field` are named by
  `FieldName.wire_argument/4` (with `:action`) or `wire/3`, i.e. the schema key spelling.
- Court: `test/ash_surface/divergence_close/field_name_precedence_error_spelling_test.exs`
  (5 tests, real Spark compile, real `Errors.to_errors/2`; SK-fw inputs: `a_x?`+`done?: "isDone"`,
  `[:__x,:a_1]`, `:is_active?`, `:is_task_completed_now?` with `argument_names`).

## Commands (MIX_BUILD_ROOT=_build-ro)

- Court alone: exit 0, 5 tests, 0 failures.
- `mix test` on divergence_close, ported/top, ported/resource and the 5 errors tests: rc=0
  (un-piped capture), 489 tests, 0 failures, 16 skipped.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.

## Overlaps

Edited no `compiler/*` (RN) or runtime_parity/rpc (RL) files. Not run: IR digest / conformance
regen (FINAL-REGEN), node+zod of emitted artifacts for these two resources (UNVERIFIED).
`_build-ro` deleted at close.
