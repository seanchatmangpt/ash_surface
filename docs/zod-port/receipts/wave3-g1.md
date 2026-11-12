# Wave 3 Lane G1: Config Keys Parity

Standing: PARTIAL_ALIVE

All 58 `config.key.*` ids now map to `pass` (config section 65/0/0/0/0). Keys are
implemented (accessor, validation, executed court). Standing is PARTIAL_ALIVE because most
keys have no renderer consumer yet (consumer gaps below), and the mock-discipline test fails
on another lane's file.

## Commands

- `mix test test/ash_surface/config` (+ no_local_do, mock_discipline, config_test): 71 tests,
  1 failure: `ash_surface_mock_discipline_test` flags unparseable
  `test/ash_surface/compiler/zod_type_s3b_test.exs:79` (another lane's in-flight file, not
  G1). Config tests: 60 tests, 0 failures. no_local_do: pass.
- `mix ash_surface.parity`: rc=1 (expected). config section before 65 = 7/0/0/0/58; after
  65 = 65/0/0/0/0. Overall after: pass 254, broken 6, missing 65 (other lanes concurrent).
- `mix format --check-formatted` on 3 changed files: rc=0. `_build-g1` deleted.

## Implementation

`AshSurface.Config.parity_keys/0` table `{key, default, kind}` with the exact ash_typescript
names and defaults (verified in `~/ash_typescript/lib`); accessors generated per key (existing
accessors untouched); `Config.parity_value/1`. `Config.Verifier.parity_errors/0` validates by
kind (boolean, nilable string, enum, endpoint, handler, overrides, ...).
`test/ash_surface/config/parity_keys_test.exs`: per key, default == reference default,
override observable via accessor, invalid value rejected by `verify/0` and `verify!/0`.

## Dispositions (court: parity_keys_test.exs unless noted)

All 58: pass (wildcard `config.key.*` any_of extended with the new test file;
`import_into_generated`, `policies`, `manifest` got explicit entries with specific tokens).
Ids: add_ash_internals_to_jsdoc, add_ash_internals_to_manifest, controller_namespace_output_dir,
enable_controller_namespace_files, enable_namespace_files, generate_phx_channel_rpc_actions,
generate_valibot_schemas, generate_validation_functions, generate_zod_schemas,
import_into_generated, input_field_formatter, json_manifest_file,
json_manifest_filename_format, manifest, manifest_file, namespace_output_dir, not_found_error?,
phoenix_import_path, policies, require_tenant_parameters, router, all 8 rpc_*_hook keys, all 4
rpc_*_hook_context_type + channel variants, run_endpoint, source_path_prefix,
type_mapping_overrides, typed_channels, typed_channels_output_file, all typed_controller_* keys,
typed_controllers, untyped_map_type, valibot_* (4), validate_endpoint, warn_on_* (4).
No divergence rows; no non_goal entries made.

## Consumer gaps (accessor + validation + court only; not renderer-wired)

Needs lib edits outside G1 ownership: require_tenant_parameters (IdentitySchema),
not_found_error? (inference/typed outputs), input/output_field_formatter (FieldName),
type_mapping_overrides/untyped_map_type (ZodType), warn_on_* (verifier warnings), policies
(`show_policy_breakdowns?` into error formatting), source_path_prefix, router,
run_endpoint/validate_endpoint (HTTP transport/Expo), generate_zod_schemas /
generate_validation_functions (gating). The valibot_*, rpc_*_hook*, typed_controller_*,
typed_channels*, namespace, manifest keys have no ash_surface renderer.

## Operator decisions

Proposed non-goals (README edit needed; ids currently PASS via config court, so optional):
TS/Valibot/hook emission keys (valibot_*, rpc_*_hook*, *_hook_context_type, phoenix_import_path,
generate_phx_channel_rpc_actions), typed_controller_* / typed_channels*, namespace keys,
json_manifest_*/manifest_file/add_ash_internals_to_*. Proposed README wording: "no Valibot,
phoenix channel/typed-controller TypeScript codegen, or TS hook emission". Decide whether these
stay implemented-config-only or are reclassified.

## Files changed

lib/ash_surface/config.ex, lib/ash_surface/config/verifier.ex,
test/ash_surface/config/parity_keys_test.exs (new), parity/court_map.json (3 targeted edits),
docs/zod-port/receipts/wave3-g1.md.
