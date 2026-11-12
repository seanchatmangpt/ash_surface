# Wave 3 Lane 08 Receipt

Standing: PARTIAL

## Files
- lib/ash_surface/projectors/js/inference.ex (added `action_types/2`, `default_names/0`)
- test/ash_surface/inference_deep_test.exs (new, 20 tests, 4 loud skips)
- test/ash_surface/metadata_projection_test.exs (new, 15 tests, 2 loud skips)
- test/ash_surface/inference_test.exs (unchanged)

## Commands
- `MIX_BUILD_ROOT=_build-w308 mix test test/ash_surface/metadata_projection_test.exs
  test/ash_surface/inference_deep_test.exs test/ash_surface/inference_test.exs`
  -> `39 tests, 0 failures, 6 skipped` (exit 0 by ExUnit summary)
- tsc used: `node_modules/.bin/tsc` (exists); each emitted doc compiled with `--strict`,
  including `@ts-expect-error` negative cases and a tsc-rejects non-vacuity case.
- zero-mock grep over both new files: no matches.
- `_build-w308` deleted.

## Delivered
- Per-action generators: `<A>Fields`, `<A>Metadata`, `<A>PageInput`, `<A>Config`,
  `Infer<A>Result` (read array / get with `| null` when `not_found_error?` false /
  create+update record / destroy `{}` / metadata Pick / optional + required
  offset|keyset|mixed Page-generic narrowing). Field names default hardcoded, overridable
  through opts (fields/args/filter/sort/page/limit/offset/count/results/has_more/...).
- Metadata row: DSL `show_metadata` matrix and `metadata_field_names` stored and persisted
  (Info.surface/compiled); profile metadata validated and stored under `custom.ash_surface`
  (lib/ash_surface.ex validate_profile/decorate_manifest), proven on a real generated manifest.

## Real bugs / gaps outside inference.ex (not edited)
- lib/ash_surface/resource/validator.ex:147 (`option_refusals/2`) and :173
  (`projection_option_refusals/3`): `show_metadata` / `metadata_field_names` never validated;
  probe returned `:ok` for `show_metadata [:nope]`, `metadata_field_names :bad`.
- lib/ash_surface.ex `decorate_manifest/2` (~L189-205): custom.ash_surface gets only `"id"` and
  `"profile"`; DSL show_metadata is not written there. Register Metadata row "validated +
  stored under custom.ash_surface" is true only for the manifest profile path.

## UNVERIFIED
- Reference ports type_discovery / type_aliases / nested_type_aliases / import_resolver:
  no ash_surface analog (loud skips). rpc_metadata_test runtime result shaping: no analog;
  DSL-observable half ported.
- Full `mix test` not run. `mix format` not applied to inference.ex (file was already
  unformatted by `--check-formatted`).

## Requests
- Owner of validator.ex: refuse unknown/non-atom `show_metadata` entries vs the action's
  `metadata` and non-keyword `metadata_field_names`; then un-skip the 2 KD tests in
  metadata_projection_test.exs.
