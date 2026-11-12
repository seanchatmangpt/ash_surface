# Wave 3 Lane CJ: I12 map_error_type schema_too_large

Standing: PASS

- Re-ran on current tree: `MIX_BUILD_ROOT=_build-cj mix test test/ash_surface/compiler/s1g_schema_courts_test.exs`
  exit 0, 18 tests, 0 failures. I12 no longer reproduces; the receipt was a stale snapshot.
- `validation_error_schema.ex` build/2 catches the thrown `{:schema_too_large, bytes, cap}` and returns
  `{:error, {:schema_too_large, bytes, cap}}`; no raise/ArgumentError site exists in it or `error_schema.ex`.
- Typed error asserted at test lines 179-180 (`map_error_type` and `render`, max_bytes 5) and 146/225/275.
- No source edits made.
