# Lane 09 Receipt

Standing: PASS

## Files
- lib/ash_surface/error_formatter.ex (key format + `%{placeholder}` rewrite together; own
  camel/pascal/snake/fun formatter, no dependency on lane 13)
- lib/ash_surface/error_handler.ex (behaviour `handle_error/2 -> map | nil`; `chain/3`
  resource -> domain -> identity default; nil short-circuits)
- lib/ash_surface/errors.ex (`to_errors/2` pipeline, UUID-logged unhandled errors,
  `:show_raised_errors` opt, handler failure fails closed, JSON-safe serialization)
- test/ash_surface/error_runtime_test.exs (8 tests, real Ash errors, no mocks)

## Commands
- `MIX_BUILD_ROOT=_build-lane09 mix test test/ash_surface/error_runtime_test.exs` -> exit 0,
  `8 tests, 0 failures` (final run; first run had 5 failures from `error[:path]` on structs,
  fixed with `Map.get`; one assertion adjusted because Ash wraps raised exceptions in
  UnknownError whose message is `** (RuntimeError) leak`).
- mock grep over the test file: zero matches. `_build-lane09` deleted.

## Requests
- Lane 14: Config should expose `show_raised_errors`, `error_handler` (module or {m,f,a}) and
  output formatter; callers pass them as `Errors.to_errors/2` opts (`:show_raised_errors`,
  `:domain_handler`, `:resource_handler`, `:formatter`). No Config coupling exists yet.
- Not ported: AshTypescript.Rpc.Error protocol and field_names resource mappings
  (no equivalent in ash_surface; Ash error structs are mapped directly).

## Falsifiers
- A raising handler leaking the original error; unhandled terms exposing their content; a
  `vars` key renamed without matching `%{}` rewrite. Each is asserted in the test file.
