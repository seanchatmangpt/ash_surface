# Wave 3 F1-errcamel receipt

Standing: PASS

Scope: close the GU-T11 divergence (`AshSurface.Errors` rendered `fields` / `vars.field` snake_case
and `message` in the long Ash form). Parity implemented, no KD row needed.

## Sites changed

- `lib/ash_surface/errors.ex`: (1) `field_names` pass (`ErrorFormatter.apply_field_names/3`) now runs
  always, not only when a resource mapping exists, so `fields`, `path` and `vars.field` go through the
  output formatter (camel_case default); (2) `validate_formatter!/1` typed refusal
  (`ArgumentError "unknown_formatter: ..."`) for formatters outside camel/pascal/snake/fun-1;
  (3) bare-message parity: InvalidChanges, InvalidQuery, InvalidAttribute and the three InvalidArgument
  types emit `error.message` (reference rpc/error.ex `Map.get(error, :message) || Exception.message`)
  with the error's own `vars` merged in; other types unchanged.
- Not changed: `error_formatter.ex`, `compiler/error_schema.ex` (ErrorSchema already accepts the
  formatted shape; court below), `runtime_parity/rpc/error_builder.ex` (already formatted).
- New court `test/ash_surface/f1_errcamel_test.exs` (5 tests, incl. node+zod ErrorSchema validation).

## Tests re-pinned

- `test/ash_surface/ported/rpc/d/rpc_validation_error_structure_surface_test.exs`: dropped the
  snake-or-camel acceptance (`names/1` now returns only the reference spelling). Evidence: file passes
  at 14 tests with camelCase-only names (`userId`, `priorityFilter`) and `message =~ "is required"`.
- errors_test, errors_s1b, errors_impl_leaf, error_type_parity, ErrorSchema courts: no pin changed
  (none asserted snake_case for multi-word fields; all pass).

## Commands (MIX_BUILD_ROOT=_build-f1ec MIX_ENV=test)

| command | rc | result |
|---|---|---|
| mix test error*/errors* tests, f1e_errcfg, parity_kinds/error_types, error_type_parity, error_formatter, no_local_do, mock_discipline, rpc/d validation_error_structure | 0 | 136 tests, 0 failures |
| mix test f1_errcamel_test.exs | 0 | 5 tests, 0 failures |
| mix format --check-formatted (3 changed files) | 0 | clean |

Observed not mine: `ported/rpc/a/embedded_argument_test.exs` 4 failures (embedded schema; other lane);
`ported/rpc/d/run_typed_query_runner_surface_test.exs` 4 failures (other lane's file).

## Conformance vectors

Error-shape vectors (`conformance/vectors/*`) not regenerated (FINAL-REGEN). Any vector exercising
`Errors.to_errors` with multi-word fields or Invalid* messages may move; not checked here.
`_build-f1ec` deleted.
