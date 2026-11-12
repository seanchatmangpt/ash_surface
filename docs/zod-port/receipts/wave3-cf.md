# Wave3 lane CF receipt

Standing: PARTIAL

- I07: added `FilterSchema.render_embedded/2` and `ResourceFacts.embedded_filter_entries/1`.
- I08: added `FieldName.config_options/1` (minimal additive edit; F1-fieldwire shares the file).
- Command: `MIX_BUILD_ROOT=_build-cf mix test test/ash_surface/ported/top/formatter_artifact_gap_test.exs`
  exit 0, 6 tests, 0 failures, 1 skipped (the `@ref_skipped` reference self-skip, unchanged).
- Not run: full suite (UNVERIFIED). The embedded filter is not yet projected as an artifact export.
