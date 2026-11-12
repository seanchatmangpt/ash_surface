# Wave 3 Lane 12 Receipt

Standing: PASS

## Files
- lib/ash_surface/errors.ex (Config-derived defaults, default handler link, output formatter)
- lib/ash_surface/error_formatter.ex (pure `apply_field_names/3`)
- lib/ash_surface/config.ex (+ `show_policy_breakdowns/0`), config/verifier.ex (boolean check)
- test/ash_surface/errors_config_test.exs (new)

## Commands
`MIX_BUILD_ROOT=_build-w312 mix test errors_config_test error_runtime_test config_test
config_deep_test error_schema_test error_schema_deep_test` -> exit 0, 45 tests, 0 failures.
Build root deleted.

## Semantics
Explicit opts win. Chain: resource -> domain -> Config.error_handler (module or mfa) -> identity.
`error_output_formatter`: module `format_error/1` or `{m, f, extra}` called `m.f(error, extra...)`,
applied after key formatting. Formatter default = Config.output_field_formatter.

## UNVERIFIED
Policy breakdown text with real SAT-solved policies (Policy struct built directly).

## Requests
- Wire `ErrorFormatter.apply_field_names/3` into Errors (needs a `:field_names` opt sourced from
  the resource) and ErrorSchema.carry/2 (lane w3-01).
