# Wave 3 Lane Q1: Parity Coverage Gate

Standing: PARTIAL

The gate is built, non-vacuity proven, and run for real against the live tree. Standing is
PARTIAL because the gate exits 1: 187 of 403 capabilities are loudly MISSING (this list is
the remaining backlog). No row was marked pass without reading the named test title or
token; the divergence law (operator 2026-11-11) is encoded in the gate.

## Files (all new)

- `lib/mix/tasks/ash_surface.parity.ex` (`mix ash_surface.parity [--json] [--check-inventory]
  [--regenerate-inventory] [--reference PATH]`)
- `lib/ash_surface/parity/{inventory,court_map,register,report}.ex`
- `parity/capabilities.json` (generated; `--check-inventory` byte-compares a fresh derivation)
- `parity/court_map.json` (hand-authored, mechanically validated)
- `docs/KNOWN_DIVERGENCES.md` (KD schema with `better_because` + `court`; zero rows)
- `test/ash_surface/parity/{inventory,gate,gate_non_vacuity}_test.exs`
- `scripts/parity_inventory.exs` not created (optional; the mix task covers it).

## Method

- Inventory: `Code.string_to_quoted/1` AST walk over `~/ash_typescript/lib/**/*.ex` (reference
  HEAD 5d6e80aec1afcbabaf0831768c210fecd81bd869, not compiled, nothing executed). Sections:
  dsl (Spark Entity/Section + every schema option, resolving `++ @attr` splices), config
  (`Application.get_env(:ash_typescript, k)`), type (kind tables, aggregate kinds, constraint
  keys), error (`Rpc.Error` impls + wire `type:`), task (+ `switches`), verifier, transformer,
  codegen modules, tstype (exported TS names in emitted templates, moduledocs excluded),
  installer, runtime modules. Advisory (not ids): 180 test files, 754 describe blocks, 2754 tests.
- Court map entry forms: pass (`test` title must appear on a test/describe/property line, or
  `contains` token; `{leaf}` placeholder substitutes the id's last segment; `any_of`),
  divergence (KD row must be witnessed), non_goal (must quote README.md verbatim), unmapped
  (documented debt, counts MISSING).
- Divergence law: a KD row closes a capability only with non-empty `better_because`, an
  existing `court` file, and a receipt `Standing:` of ALIVE or PASS; otherwise MISSING. A
  non_goal without a verbatim README quote is MISSING. Receipt-lint: every KD row's receipt
  needs a closed-vocabulary `Standing:` line.
- Gate exit 1 on: any MISSING, any broken mapping (stale test/file/KD/receipt), any orphan map
  entry (matches no inventory id), any register lint problem, unreadable inputs.

## Commands and exact output

`MIX_BUILD_ROOT=_build-q1 mix test test/ash_surface/parity test/ash_surface/no_local_do_test.exs
test/ash_surface_mock_discipline_test.exs` -> `30 tests, 0 failures`.

`mix ash_surface.parity; echo rc=$?` -> rc=1 (counts below). `--json` rc=1.
`mix ash_surface.parity --check-inventory` -> `inventory identical: 403 capabilities`, rc=0.

```
total capabilities: 403
pass        144
divergence  0
non_goal    72
broken      0
missing     187
section      total pass/divergence/non_goal/broken/missing
codegen        43  5/0/13/0/25
config         65  7/0/0/0/58
dsl            64  29/0/0/0/35
error          34  30/0/0/0/4
installer       7  1/0/0/0/6
runtime        41  8/0/0/0/33
task            9  6/0/0/0/3
transformer     5  0/0/0/0/5
tstype         64  0/0/59/0/5
type           56  52/0/0/0/4
verifier       15  6/0/0/0/9
```

## Non-vacuity (gate_non_vacuity_test.exs)

Shim court on temp copies, sha256 restore verified: (a) delete a pass mapping -> exit 1 naming
the id; (b) mapping to a nonexistent test file / absent test title -> broken, exit 1; (c) fake
inventory id -> MISSING, exit 1; (d) corrupt-restore self-check detects a broken restore;
(e) deletion on a copy of the live register drops the pass count by 1 and leaves the live
file byte-identical; (f) a KD row with a PARTIAL receipt cannot close a capability. A shim the
gate accepts raises `VACUOUS GATE`. The fixture baseline is asserted green first.

## MISSING backlog (every id, ranked by section)
- `MISSING (187), ranked by section:`

### config (58)

- `config.key.add_ash_internals_to_jsdoc`
- `config.key.add_ash_internals_to_manifest`
- `config.key.controller_namespace_output_dir`
- `config.key.enable_controller_namespace_files`
- `config.key.enable_namespace_files`
- `config.key.generate_phx_channel_rpc_actions`
- `config.key.generate_valibot_schemas`
- `config.key.generate_validation_functions`
- `config.key.generate_zod_schemas`
- `config.key.import_into_generated`
- `config.key.input_field_formatter`
- `config.key.json_manifest_file`
- `config.key.json_manifest_filename_format`
- `config.key.manifest`
- `config.key.manifest_file`
- `config.key.namespace_output_dir`
- `config.key.not_found_error?`
- `config.key.phoenix_import_path`
- `config.key.policies`
- `config.key.require_tenant_parameters`
- `config.key.router`
- `config.key.rpc_action_after_channel_response_hook`
- `config.key.rpc_action_after_request_hook`
- `config.key.rpc_action_before_channel_push_hook`
- `config.key.rpc_action_before_request_hook`
- `config.key.rpc_action_channel_hook_context_type`
- `config.key.rpc_action_hook_context_type`
- `config.key.rpc_validation_after_channel_response_hook`
- `config.key.rpc_validation_after_request_hook`
- `config.key.rpc_validation_before_channel_push_hook`
- `config.key.rpc_validation_before_request_hook`
- `config.key.rpc_validation_channel_hook_context_type`
- `config.key.rpc_validation_hook_context_type`
- `config.key.run_endpoint`
- `config.key.source_path_prefix`
- `config.key.type_mapping_overrides`
- `config.key.typed_channels`
- `config.key.typed_channels_output_file`
- `config.key.typed_controller_after_request_hook`
- `config.key.typed_controller_base_path`
- `config.key.typed_controller_before_request_hook`
- `config.key.typed_controller_error_handler`
- `config.key.typed_controller_hook_context_type`
- `config.key.typed_controller_import_into_generated`
- `config.key.typed_controller_mode`
- `config.key.typed_controller_path_params_style`
- `config.key.typed_controller_show_raised_errors`
- `config.key.typed_controllers`
- `config.key.untyped_map_type`
- `config.key.valibot_import_into_generated`
- `config.key.valibot_import_path`
- `config.key.valibot_mapping_overrides`
- `config.key.valibot_schema_suffix`
- `config.key.validate_endpoint`
- `config.key.warn_on_missing_channel_returns`
- `config.key.warn_on_missing_rpc_config`
- `config.key.warn_on_non_public_publications`
- `config.key.warn_on_non_rpc_references`

### dsl (35)

- `dsl.rpc.entity.resource.option.resource`
- `dsl.rpc.entity.rpc_action.option.action`
- `dsl.rpc.entity.rpc_action.option.description`
- `dsl.rpc.entity.rpc_action.option.name`
- `dsl.rpc.entity.rpc_action.option.namespace`
- `dsl.rpc.entity.rpc_action.option.see`
- `dsl.rpc.entity.typed_query.option.description`
- `dsl.rpc.entity.typed_query.option.ts_fields_const_name`
- `dsl.rpc.entity.typed_query.option.ts_result_type_name`
- `dsl.rpc.section.typescript_rpc`
- `dsl.rpc.section.typescript_rpc.option.show_raised_errors?`
- `dsl.typed_channel.dsl.entity.resource`
- `dsl.typed_channel.dsl.entity.resource.option.module`
- `dsl.typed_channel.dsl.section.typed_channel`
- `dsl.typed_controller.dsl.entity.argument`
- `dsl.typed_controller.dsl.entity.argument.option.allow_nil?`
- `dsl.typed_controller.dsl.entity.argument.option.constraints`
- `dsl.typed_controller.dsl.entity.argument.option.default`
- `dsl.typed_controller.dsl.entity.argument.option.name`
- `dsl.typed_controller.dsl.entity.argument.option.type`
- `dsl.typed_controller.dsl.entity.route`
- `dsl.typed_controller.dsl.entity.route.option.constraints`
- `dsl.typed_controller.dsl.entity.route.option.deprecated`
- `dsl.typed_controller.dsl.entity.route.option.description`
- `dsl.typed_controller.dsl.entity.route.option.method`
- `dsl.typed_controller.dsl.entity.route.option.name`
- `dsl.typed_controller.dsl.entity.route.option.namespace`
- `dsl.typed_controller.dsl.entity.route.option.returns`
- `dsl.typed_controller.dsl.entity.route.option.run`
- `dsl.typed_controller.dsl.entity.route.option.see`
- `dsl.typed_controller.dsl.entity.route.option.valibot_schema_name`
- `dsl.typed_controller.dsl.entity.route.option.zod_schema_name`
- `dsl.typed_controller.dsl.section.typed_controller`
- `dsl.typed_controller.dsl.section.typed_controller.option.module_name`
- `dsl.typed_controller.dsl.section.typed_controller.option.namespace`

### runtime (33)

- `runtime.module.AshTypescript`
- `runtime.module.Helpers`
- `runtime.module.Manifest`
- `runtime.module.Manifest.Custom`
- `runtime.module.Manifest.Dsl`
- `runtime.module.Resource`
- `runtime.module.Resource.Info`
- `runtime.module.Rpc`
- `runtime.module.Rpc.ErrorBuilder`
- `runtime.module.Rpc.FieldExtractor`
- `runtime.module.Rpc.FieldProcessing.Atomizer`
- `runtime.module.Rpc.FieldProcessing.FieldSelector`
- `runtime.module.Rpc.FieldProcessing.FieldSelector.Validation`
- `runtime.module.Rpc.Info`
- `runtime.module.Rpc.InputFormatter`
- `runtime.module.Rpc.OutputFormatter`
- `runtime.module.Rpc.Pipeline`
- `runtime.module.Rpc.Request`
- `runtime.module.Rpc.RequestedFieldsProcessor`
- `runtime.module.Rpc.ResultProcessor`
- `runtime.module.Rpc.ValidationErrorSchemas`
- `runtime.module.Rpc.ValueFormatter`
- `runtime.module.TypeSystem.Introspection`
- `runtime.module.TypedChannel`
- `runtime.module.TypedChannel.Dsl`
- `runtime.module.TypedChannel.Info`
- `runtime.module.TypedChannel.Interception`
- `runtime.module.TypedChannel.PayloadFormatter`
- `runtime.module.TypedController`
- `runtime.module.TypedController.Dsl`
- `runtime.module.TypedController.Info`
- `runtime.module.TypedController.RequestHandler`
- `runtime.module.TypedController.Route`

### codegen (25)

- `codegen.module.Codegen`
- `codegen.module.Codegen.Helpers`
- `codegen.module.Codegen.ImportResolver`
- `codegen.module.Codegen.ResourceSchemas`
- `codegen.module.Codegen.SchemaFormatter`
- `codegen.module.Codegen.SharedSchemaGenerator`
- `codegen.module.Codegen.TypeDiscovery`
- `codegen.module.Codegen.ValibotSchemaGenerator`
- `codegen.module.Rpc.Codegen.FunctionGenerators.ChannelRenderer`
- `codegen.module.Rpc.Codegen.FunctionGenerators.FunctionCore`
- `codegen.module.Rpc.Codegen.FunctionGenerators.HttpRenderer`
- `codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator`
- `codegen.module.Rpc.Codegen.FunctionGenerators.TypedQueries`
- `codegen.module.Rpc.Codegen.FunctionNames`
- `codegen.module.Rpc.Codegen.Helpers.ActionIntrospection`
- `codegen.module.Rpc.Codegen.Helpers.ConfigBuilder`
- `codegen.module.Rpc.Codegen.Helpers.PayloadBuilder`
- `codegen.module.Rpc.Codegen.JsonManifestGenerator`
- `codegen.module.Rpc.Codegen.ManifestGenerator`
- `codegen.module.Rpc.Codegen.RpcConfigCollector`
- `codegen.module.TypedChannel.Codegen`
- `codegen.module.TypedController.Codegen`
- `codegen.module.TypedController.Codegen.RouteConfigCollector`
- `codegen.module.TypedController.Codegen.RouteRenderer`
- `codegen.module.TypedController.Codegen.RouterIntrospector`

### verifier (9)

- `verifier.VerifierChecker`
- `verifier.VerifyMapFieldNames`
- `verifier.VerifyMappableTypes`
- `verifier.VerifyMetadataFieldNames`
- `verifier.VerifyRpcWarnings`
- `verifier.VerifyTypedChannel`
- `verifier.VerifyTypedController`
- `verifier.VerifyUniqueInputFieldNames`
- `verifier.VerifyUniqueTypeNames`

### installer (6)

- `installer.module.Installer.Esbuild`
- `installer.module.Installer.Framework`
- `installer.module.Installer.Inertia`
- `installer.module.Installer.LandingPage`
- `installer.module.Installer.Layout`
- `installer.module.Installer.Vite`

### transformer (5)

- `transformer.BuildManifest`
- `transformer.DecorateManifest`
- `transformer.FoldArgumentConstraints`
- `transformer.GenerateController`
- `transformer.PersistFormattedFields`

### tstype (5)

- `tstype.buildCSRFHeaders`
- `tstype.create`
- `tstype.getPhoenixCSRFToken`
- `tstype.on`
- `tstype.unsubscribe`

### error (4)

- `error.impl.AshAuthentication.Errors.AuthenticationFailed`
- `error.impl.AshAuthentication.Errors.InvalidToken`
- `error.type.authentication_failed`
- `error.type.invalid_token`

### type (4)

- `type.constraint.escape?`
- `type.constraint.instance_of`
- `type.kind.binary_id`
- `type.kind.date_time`

### task (3)

- `task.codegen.flag.run_endpoint`
- `task.codegen.flag.validate_endpoint`
- `task.npm_install`

## UNVERIFIED

- `pass` rows built on `contains {leaf}` over topical files (config.key.*, error.impl.*,
  error.type.*, type.constraint.*, dsl.rpc.entity.rpc_action.option.*) assert the file names
  the key, not that each assertion is deep; the title-pinned rows were read, the
  token-pinned rows were not individually read.
- 72 non_goal rows rest on the README quote ("no generated `.ts`, no `.d.ts`, no `tsc` build
  step") for TS declaration emitters/types; the README does not itself enumerate them.
- Test files cited by passes are being edited by other lanes; the gate re-validates on each run.
- Several cited tests (`typed_query_fields_test.exs`, `metadata_projection_test.exs`,
  `errors_config_test.exs`) are untracked or modified in git at write time.
- `verifier.VerifyMetadataFieldNames` is unmapped because `validator_action_types_test.exs`
  pins show_metadata validation as a divergence (w3-07 debt).

## Requests

- Other lanes: close rows by landing tests whose titles/tokens the map names, or add map
  entries in `parity/court_map.json` (the gate flags stale entries). Divergences need a
  KD row with `better_because` + court + ALIVE/PASS receipt.
- Coordinator: stage `parity/`, `lib/ash_surface/parity/`, `lib/mix/tasks/ash_surface.parity.ex`,
  `docs/KNOWN_DIVERGENCES.md`, `test/ash_surface/parity/` explicitly (all untracked).
- Re-run `mix ash_surface.parity --regenerate-inventory` if the reference checkout moves.
