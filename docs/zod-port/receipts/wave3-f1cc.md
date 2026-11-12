# Wave 3 Lane F1-cfgconsume: Config Key Consumer Census

Standing: PARTIAL

One key wired with a consumer-effect court; the remaining UNCONSUMED keys have no natural
emission site or need a wire-name / README decision, recorded as OPERATOR-DECISIONS D23.

## Census (readers in lib/ other than config.ex, verifier.ex, parity/*; `Config.<accessor>`)

| key | class | evidence |
|---|---|---|
| output_file, output_dir | CONSUMED | mix codegen task reads `Config.output_file`; codegen_task_test |
| always_regenerate | CONSUMED | codegen task; codegen_task_test.exs:120,137 |
| show_raised_errors, show_policy_breakdowns, error_handler, error_output_formatter | CONSUMED | errors.ex / info.ex readers; existing error tests |
| output_field_formatter | CONSUMED | errors.ex:100 |
| zod_object_mode | CONSUMED | compiler/object_mode.ex |
| zod_import_path | CONSUMED | projectors/js.ex header; transport_codegen_courts_test (node-free emitted-line assertion) |
| require_tenant_parameters | CONSUMED | IdentitySchema; transport_codegen_courts_test |
| warn_on_missing_rpc_config | CONSUMED | domain compile warning; transport_codegen_courts_test |
| zod_mapping_overrides | CONSUMED | compiler/zod_type.ex:612; config_deep_test |
| zod_schema_suffix | CONSUMED (state only) | EmbeddedSchema; no output effect (wave3-f1d request 3) |
| not_found_error? | wired (this lane) | resource_facts.ex projection_option(nil, :not_found_error?) -> Config; test/ash_surface/config/consumer_courts_test.exs |
| typed_controller_base_path/mode, controller_namespace_output_dir, enable_controller_namespace_files | skipped | owned by T14b (running) |
| untyped_map_type, type_mapping_overrides, source_path_prefix, input_field_formatter, zod_infer_types, zod_import_into_generated, generate_zod_schemas, generate_validation_functions, import_into_generated, zod_output_file, phoenix_import_path, warn_on_missing_channel_returns, warn_on_non_public_publications, warn_on_non_rpc_references | operator-decision | OPERATOR-DECISIONS D23 (no emission site; wiring changes wire names or needs README wording) |
| valibot_import_into_generated, valibot_import_path, valibot_mapping_overrides, valibot_schema_suffix, generate_valibot_schemas | operator-decision | D1 (README has no Valibot sentence) |
| run_endpoint, validate_endpoint, typed_channels*, typed_controllers, typed_controller_* (rest), rpc_action_*/rpc_validation_* hooks and context types, generate_phx_channel_rpc_actions, router, policies, manifest, manifest_file, json_manifest_*, namespace_output_dir, enable_namespace_files, add_ash_internals_* | operator-decision | existing D3, D4, D5 |

No key was classified non_goal (no verbatim README sentence exists for any).

## Changes

- `lib/ash_surface/compiler/resource_facts.ex`: with no projection, `not_found_error?` now
  reads `AshSurface.Config.not_found_error?/0` (projection DSL default stays true and wins).
- New `test/ash_surface/config/consumer_courts_test.exs` (real Ash resource, real facts).
- `parity/court_map.json`: `config.key.not_found_error?` now lists the consumer test first,
  accessor test kept secondary (json valid).
- `docs/jira/v26.11.11/OPERATOR-DECISIONS.md`: appended D23.

## Commands

- `MIX_BUILD_ROOT=_build-f1cc mix test test/ash_surface/config test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs` -> 126 tests, 0 failures, exit 0.
- `MIX_BUILD_ROOT=_build-f1cc mix ash_surface.parity --json` exit 0; no config.* id in
  missing/errors lists. no_local_do allowlist unchanged.
- `_build-f1cc` deleted.

## Falsifier

Reverting the resource_facts edit makes the consumer test fail (override false yields true).
