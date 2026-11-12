# Wave 3 Lane T3 Receipt

Standing: PARTIAL_ALIVE

Lane T3 (codegen/, resource/, resource/transformers, rpc/codegen/helpers, mix_tasks): all 18
owned ledger rows accounted. 14 rows newly ported (2 ported, 11 adapted, 1 skipped_gap); the 4
seeded codegen skips (type_discovery, type_aliases, nested_type_aliases, import_resolver) are
untouched. The final gate run and format-after test run were blocked by another lane's
in-flight compile break (`lib/ash_surface/runtime_parity/rpc/pipeline.ex`), see Commands.

## Per-file dispositions

| reference file | disposition | ash_surface test |
|---|---|---|
| codegen/aggregate_calculation_support_test | adapted (5/5) | ported/codegen/aggregate_calculation_support_test.exs |
| codegen/embedded_entrypoint_discovery_test | adapted (4/4) | ported/codegen/embedded_entrypoint_discovery_test.exs |
| codegen/pagination_types_test | adapted (4/4) | ported/codegen/pagination_types_test.exs |
| codegen/relationship_markers_test | adapted (8/8) | ported/codegen/relationship_markers_test.exs |
| codegen/{type_discovery,type_aliases,nested_type_aliases,import_resolver}_test | skipped_gap (seeded, untouched) | inference_deep_test.exs |
| resource/map_field_names_utility_test | ported (8/8) | ported/resource/map_field_names_utility_test.exs |
| resource/map_field_names_valid_test | ported (2/2) | ported/resource/map_field_names_valid_test.exs |
| resource/transformers/persist_formatted_fields_test | adapted (14/14) | ported/resource/persist_formatted_fields_test.exs |
| resource/typescript_field_names_codegen_test | adapted (2/2) | ported/resource/typescript_field_names_codegen_test.exs |
| resource/typescript_field_names_test | adapted (1/1) | ported/resource/typescript_field_names_test.exs |
| resource/verify_field_names_test | adapted (11/11) | ported/resource/verify_field_names_test.exs |
| resource/verify_map_field_names_test | adapted (9/9) | ported/resource/verify_map_field_names_test.exs |
| resource/verify_nested_map_field_names_test | adapted (4/4) | ported/resource/verify_nested_map_field_names_test.exs |
| rpc/codegen/helpers/action_introspection_newtype_test | adapted (5/5) | ported/codegen/action_introspection_newtype_test.exs |
| mix_tasks/install_test | skipped_gap (4 router tests) | ported/codegen/install_gap_test.exs |

The 2 config-scaffold tests of install_test run in `ported/codegen/install_test.exs`
(adapted, not on a ledger row: a row has one disposition and the gate requires every file of a
`skipped_gap` row to contain the skip).

## Gate output (`mix run --no-compile -e 'Mix.Tasks.AshSurface.Parity.Tests.run(["--summary"])'`)

`parity-tests: files=264 ported=8 adapted=101 skipped_gap=56 non_goal=11 unaccounted=88
broken=0 shallow=41` (whole ledger, other lanes in flight, exit 1 by design). T3 rows by dir
(`--json` `by_dir`): codegen adapted 4 + skipped_gap 4; resource adapted 5 + ported 2;
resource/transformers adapted 1; rpc/codegen/helpers adapted 1; mix_tasks skipped_gap 1.
`broken=0`. Six T3 rows are flagged shallow (advisory: no node/zod text): persist_formatted_fields,
typescript_field_names, verify_field_names, verify_map_field_names, verify_nested_map_field_names,
action_introspection_newtype; they assert Elixir verifier/classification behavior.

## Commands (MIX_BUILD_ROOT=_build-t3, MIX_ENV=test; build root deleted)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/codegen test/ash_surface/ported/resource` (before `mix format`) | 0 | 84 tests, 0 failures, 4 skipped (install gap) |
| `mix format` on my test files, `--check-formatted` on them and my 7 lib files | 0 | clean |
| `mix test test/conformance` after regenerating query_envelope + MANIFEST | 0 | 28 tests, 0 failures |
| `node --test test/js/conformance_replay.test.mjs` | 0 | 15 pass, 0 fail |
| regression sweep (verifiers, resource, parity_deepen, compiler, installer*, fixtures, dsl, divergence_close, query/inference/field-name/naming/typed_query/ir_codec tests, mock-discipline court) | 1 | 637 tests, 2 failures, 4 skipped; both failures are in files other lanes have uncommitted edits to: `compiler/schema_section_test.exs:311` (Expo canon vs schema section; expo.ex, schema.ex modified) and `resource/validator_action_types_test.exs:139` (`invalid_load_paths`; validator.ex modified). UNVERIFIED as pre-existing (no clean baseline run) |
| re-run of ported tests after `mix format` | n/a | blocked: lib/ash_surface/runtime_parity/rpc/pipeline.ex (another lane) failed to compile |

## lib edits (all targeted; disclose to owning lanes)

- `lib/ash_surface/resource/verifiers/checks.ex`: new `invalid_field_name_refusals/1`
  (ash_typescript VerifyFieldNames: `?`/`_<digit>` attribute, calculation, aggregate names need
  `field_names`), `invalid_typed_name_refusals/1` (VerifyMapFieldNames: map/keyword/tuple/struct
  `fields`, union members, through arrays, unions, NewTypes; NewType `typescript_field_names/0`
  remaps); `unmappable/1` no longer reports container kinds `union embedded_resource
  typed_struct typed_map resource` (a valid union attribute was refused as unmappable). File
  was concurrently edited by another lane (`ActionTypeFieldNames`); my edit re-applied on top.
- `lib/ash_surface/info.ex`: `Info.get_formatted_field/3`.
- `lib/ash_surface/field_name.ex`: `FieldName.format_field_for_client/3`.
- `lib/ash_surface/compiler/type_facts.ex`: NewType `typescript_field_names/0` carried as
  `"field_names"` on map/struct/keyword type definitions.
- `lib/ash_surface/compiler/embedded_schema.ex`: per-type `"field_names"` applied as wire keys.
- `lib/ash_surface/compiler/query_schema.ex`: keyset result `previousPage`/`nextPage` now
  `.nullable()` (defect: Zod rejected the nulls the runtime and Inference declaration use).
  Regenerated `conformance/vectors/query_envelope.json` and `conformance/MANIFEST.json` from
  `scripts/conformance_regen.exs` into a scratch dir (only those two files differed) and copied
  them. Another lane overwrote them once in the interval (older lib build); re-copied. If the
  w3-04 lane regenerates, it must do so against this lib.
- `lib/ash_surface/installer/installer.ex`: `default_config/0` also seeds `run_endpoint`,
  `validate_endpoint`, `generate_zod_schemas`, `zod_schema_suffix`, `generate_valibot_schemas`,
  `valibot_import_path`, `valibot_schema_suffix` (all existing Config keys at their defaults).

## Open capability gaps and operator decisions

1. skipped_gap `mix_tasks/install_test` router tests: ash_surface has the
   `run_endpoint`/`validate_endpoint`/`router` config keys but no server-side RPC controller and
   its installer patches no router. Needs an operator decision: build a controller + installer
   router patch, or declare a README non-goal (README has no sentence today, so not recorded as
   non_goal).
2. Generic-action RETURN schemas: `Compiler.Section.Schema` passes `"returns" => nil`, so the IR
   output zod is `z.undefined()`; the reference's "defines the schema for the embedded resource
   behind an entrypoint" is asserted on the action INPUT side only (stated in the row `changes`).
   Return-side output schemas are an unimplemented parity debt (section/schema.ex is owned by an
   in-flight lane).
3. NewType `manifest:` module scaffold (install test 2) has no ash_surface counterpart.
4. Valibot: config keys exist and the installer seeds them; no README sentence about Valibot
   exists, so no non_goal claim was made.
5. `AshSurface.Resource.Persist` persists `:ash_surface_formatted_fields` for attributes,
   calculations, aggregates only (no relationships, camel_case only); `get_formatted_field/3`
   computes at read time instead. Not a parity break for the reference tests; noted.

## Falsifiers

- A non-public embedded-returning action appears in IR or artifact: the embedded test fails.
- An unmapped `?` attribute/calculation/aggregate or nested map/union field with an awkward name
  compiles without a refusal: verify_* tests fail.
- Keyset result schema rejects `previousPage: null`: pagination_types test fails.
