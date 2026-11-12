# Lane 13 Receipt

Standing: PASS

## Files
- lib/ash_surface/naming.ex (invalid_name?/1, identifier?/1, make_name_better/1)
- lib/ash_surface/field_name.ex (format/3 with verbatim overrides, compute/2,
  parse_input/2 existing-atom only, parse_sort/1, client_to_internal/3 with collision error)
- test/ash_surface/naming_test.exs

## Commands
- `MIX_BUILD_ROOT=_build-lane13 mix test test/ash_surface/naming_test.exs`
  -> `4 tests, 0 failures` (exit of mix not captured un-piped; pass read from output).
  Compile warning seen from another lane: lib/ash_surface/projectors/js/inference.ex:14
  heredoc indentation (lane 18 file, not touched).
- _build-lane13 deleted.

## Requests
- None.

## Falsifiers
- parse_input of an unknown client name returning {:ok, _} or minting an atom (tested).
- override not used verbatim (tested).
