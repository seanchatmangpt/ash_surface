# Wave3 lane CR receipt

Standing: PASS

- Gap (wave3-cf.md): embedded filter not exported from the JS projector.
- Change: `AshSurface.Projectors.JS.project_ir/2` option `:embedded_filters` (list of embedded
  resource modules); each exports `<Short>EmbeddedFilterSchema` from
  `FilterSchema.render_embedded/1` (wire names already formatter/field_names-aware), admitted
  via ZodGuard, sorted by name, collision-checked; non-embedded module refused
  `{:unadmitted_embedded_filter, mod, :not_an_embedded_resource}`.
- Test: `test/ash_surface/projectors/js_embedded_filter_export_test.exs` (node+zod on the real
  .mjs). `MIX_BUILD_ROOT=_build-cr mix test <that file>` exit 0, 3 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-cr mix test test/ash_surface/projectors` exit 0, 99 tests, 0 failures,
  2 skipped.
- Digest movement: none expected (default `[]` emits byte-identical output); conformance not
  regenerated and not run (UNVERIFIED).
