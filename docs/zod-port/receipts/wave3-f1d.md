# Wave 3 Lane F1-deepen: Real Courts For Shallow And Vacuous Parity Rows

Standing: PARTIAL

27 court_map entries now point at executed behavior tests under
`test/ash_surface/parity_deepen/`. None of the 27 is named by the hardened gate as
ERROR or MISSING (checked on the live run). Standing is PARTIAL because the config-key
consumer sweep finds most keys have no renderer consumer (listed below), and the
shared config table rows now read MISSING under the hardened gate (not owned here).

## Files

- New: `test/ash_surface/parity_deepen/{schema_courts,dsl_runtime_courts,transport_codegen_courts,mapped_names_courts}_test.exs`
- Edited: `parity/court_map.json` (only the ids below, line-targeted block replacement,
  each re-read at write time; json valid after). No `lib/` edits.

## Before / after (court: file, title)

S = schema_courts, D = dsl_runtime_courts, T = transport_codegen_courts, M = mapped_names_courts.

| id | after (assertion) |
|---|---|
| codegen.module.Codegen.SharedSchemaGenerator | S "an embedded resource referenced several times...": N refs inline identically (count == 3), no const, ZodGuard, node+zod accept/refuse per site. Skipped flunk test no longer cited |
| config.key.zod_schema_suffix (was unmapped prefix hit) | S: default "ZodSchema", put_env override, Verifier refuses 5 and "1 bad", no suffix leak in inlined output |
| ...FunctionGenerators.ChannelRenderer | T: node, Phoenix-shaped channel: event, timeout, beforePush/afterResponse order, idempotency payload, error reply code |
| ...FunctionGenerators.HttpRenderer | T: beforeRequest->fetch->afterRequest order, fetchOptions/headers pass-through; emitted Expo client wiring run under node (abs/relative endpoint, baseUrl, GET, signal, origin refusal) |
| ...Helpers.ConfigBuilder | T: same hook-order test + throwing beforeRequest never fetches, swapped URL origin re-checked |
| ...FunctionGenerators.TypedQueries | T: manifest DSL JSON of typed_query, typed-query input envelope strict/optional/ZodGuard |
| ...Helpers.PayloadBuilder | T: emitted QUERY_SCHEMAS slots by name, absent -> null, frozen record executed under zod |
| codegen.module.Codegen.TypeMapper | S: hand-written 36-kind table vs `ZodType.base` and `fragment` (one test per kind), table == `ZodType.kinds()`, override, unmapped |
| runtime.module.Rpc | D: `AshSurface.Resource.sections/0` surface section, entities, options |
| runtime.module.Rpc.Info | D: Projections lookup/split/absent/presentation keys |
| runtime.module.Resource.Info | D: field_names/argument_names read back, non-extension resource not compiled/raises |
| runtime.module.AshTypescript | D: digest invariants, from_manifest digest verify/forgery, profile refusal, action_id/runtime_source |
| runtime.module.Helpers | D: FieldName.format/parse_input (no atom minting)/parse_sort, Naming |
| verifier.VerifyMappedFieldNames | M: field_names and argument_names accept + refusal codes via real Spark verifier |
| dsl.rpc.entity.rpc_action | D: defaults vs set options, duplicate and get/get_by conflict refusals |
| ...rpc_action.option.deprecated | D: default nil, true/false/message round trip, only its own field differs in compiled state. No JSDoc consumer exists (request 1) |
| dsl.manifest.opt_schema.option.domains | D: `:ash_domains` selection admits only chosen domains; empty admits none |
| ...typed_channel...option.topic | T: topic through discovery and Channel.build, nil when absent, distinct per channel |
| dsl.rpc.section.typescript_rpc | D: section options reach Info and manifest DSL serialization; undeclared -> `%{}` |
| ...typescript_rpc.option.namespace | D: resource namespace overrides domain; absent inherits |
| type.aggregate.integer | S: sum over :integer == `z.number().nullable()` under node |
| type.kind.count / type.kind.sum | S: count never null/int; sum nullable, metadata `\| null` vs `{number}` |
| type.aggregate.* (prefix) | S: ten literal-titled per-kind tests (`:avg` ... `:custom`) against hand-written expressions |
| config.key.require_tenant_parameters | T: IdentitySchema.render_tenant_schema under env true/false, fact wins |
| config.key.zod_import_path | T: emitted artifact import line under env |
| config.key.warn_on_missing_rpc_config | T: domain compile stderr warning on/off |

## Rows left MISSING and why

- `codegen.module.Rpc.Codegen.FunctionGenerators.ChannelRenderer` has no emitter: nothing in
  `lib/` emits `createChannelTransport` (only `priv/static` defines it); the court tests the
  runtime transport, not generated wiring (request 2).
- Config consumer sweep. Keys with an on-disk consumer and a consumer-effect assertion:
  require_tenant_parameters, zod_import_path, warn_on_missing_rpc_config (this lane);
  output_field_formatter, always_regenerate, zod_object_mode, show_raised_errors (existing
  tests). `not_found_error?` is read only by `Config.Verifier` (no renderer effect).
  Accessor-only (no renderer/runtime consumer, operator-visible gap): add_ash_internals_to_jsdoc,
  add_ash_internals_to_manifest, controller_namespace_output_dir, enable_controller_namespace_files,
  enable_namespace_files, generate_phx_channel_rpc_actions, generate_valibot_schemas,
  generate_validation_functions, generate_zod_schemas, import_into_generated, input_field_formatter,
  json_manifest_file, json_manifest_filename_format, manifest, manifest_file, namespace_output_dir,
  phoenix_import_path, policies, router, all rpc_action_* / rpc_validation_* hook and
  context_type keys, run_endpoint, validate_endpoint, source_path_prefix, type_mapping_overrides,
  typed_channels, typed_channels_output_file, all typed_controller_* keys, typed_controllers,
  untyped_map_type, valibot_* keys, warn_on_missing_channel_returns, warn_on_non_public_publications,
  warn_on_non_rpc_references. `zod_schema_suffix` reaches only `EmbeddedSchema` state, which the
  inline law never renders.
- Under the hardened gate the shared `config.key.*` rows (`parity_keys_test.exs` titles are
  interpolated, keys sit outside test bodies) currently report MISSING/ERROR (54 MISSING in the
  last run). Not edited here (outside owned ids); fix is literal-titled per-key tests.

## Requests (no lib edits made)

1. `deprecated`: nothing in `lib/` emits JSDoc `@deprecated` from the projection option.
2. No generator emits `createChannelTransport` wiring (Expo client wires HTTP only).
3. `config.zod_schema_suffix` has no output consumer (inlined references carry no names).
4. `test/ash_surface/no_local_do_test.exs` fails on another lane's file
   `lib/ash_surface/runtime_parity/requested_fields/field_selector.ex` (`Ash.Query.for_read`);
   not caused by this lane.
5. Premise rot observed: `ZodType` map/keyword/tuple/struct changed to `z.record(z.string(), z.any())`
   concurrently; the TypeMapper table was re-pinned to that.

## Commands (build root `_build-f1d`, copied from `_build/test`)

- `mix test test/ash_surface/parity_deepen test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs`: 103 tests, 1 failure (the field_selector
  tripwire above, request 4); the only failing test is `NoLocalDoTest`, all parity_deepen
  and mock-discipline tests passed.
- `mix format --check-formatted test/ash_surface/parity_deepen/*.exs`: exit 0.
- `mix ash_surface.parity` (MIX_ENV=test): rc 1; `parity: total=403 pass=218 divergence=0
  non_goal=79 broken=35 missing=71`; zero lines name the 27 ids above.
- No `Process.sleep`, no mocks, no `apply` in the new files (grep clean).
