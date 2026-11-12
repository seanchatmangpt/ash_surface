# Wave 3 Lane G5 Receipt

Standing: PARTIAL_ALIVE

Slice: 25 `codegen.module.*` ids + 5 `tstype.*` ids. 29 of 30 now pass; 1 left MISSING.

## Commands

- `mix test test/ash_surface/codegen_parity test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs`: exit 0, 14 tests, 0 failures.
- `node --test test/js/tstype_runtime_functions.test.mjs`: 5 tests, 5 pass.
- `mix format --check-formatted` on the new test file: exit 0.
- `mix ash_surface.parity`: exit 1 (other lanes' ids). codegen section 29/0/13/0/1
  (pass/div/non_goal/broken/missing), tstype 5/0/59/0/0. Before: the 25 + 5 ids were
  MISSING (Q1 receipt); after: only ValibotSchemaGenerator MISSING. No parity ERROR rows
  from this lane's ids.

## Dispositions

| id | counterpart | court |
|----|-------------|-------|
| Codegen | mix/tasks/ash_surface.codegen.ex | codegen_task_test (byte-identical rerun; --check drift) |
| Codegen.Helpers | field_name.ex | field_name_mapping_test precedence |
| Codegen.ImportResolver | projectors/js.ex header/1 | codegen_modules_test import resolution |
| Codegen.ResourceSchemas | js.ex schema_consts | js_schema_wiring_test (node + real zod) |
| Codegen.SchemaFormatter | field_name.ex | field_name_mapping_test formatter collision |
| Codegen.SharedSchemaGenerator | js.ex declaration order | js_declaration_order_test Kahn sort |
| Codegen.TypeDiscovery | js.ex dependency expansion | js_declaration_order_test array/missing dep |
| Codegen.ValibotSchemaGenerator | none | MISSING (see Operator decisions) |
| ChannelRenderer | priv/static channel transport | channel_transport.test.mjs (createChannelTransport) |
| FunctionCore | js.ex dispatch descriptors | js_projector_test structured refusal |
| HttpRenderer | priv/static http transport | http_transport.test.mjs (createHttpTransport) |
| JsdocGenerator | js.ex header/namespace_block JSDoc | codegen_modules_test jsdoc |
| TypedQueries | typed_query DSL, QUERY_SCHEMAS | typed_query_fields_test |
| FunctionNames | js.ex sanitize/ns_name | codegen_modules_test function naming |
| ActionIntrospection | compiler discovery | compiler_discovery_test DiscoverOnce 2 |
| ConfigBuilder | http transport options | http_transport.test.mjs (beforeRequest) |
| PayloadBuilder | js.ex ACTIONS/SCHEMAS/QUERY_SCHEMAS | codegen_modules_test payload builder |
| JsonManifestGenerator | Contract serializer | manifest_serializer_test round-trip |
| ManifestGenerator | Contract serializer | manifest_serializer_test golden |
| RpcConfigCollector | compiler intake | compiler_discovery_test five-section IR |
| TypedChannel.Codegen | section/channel.ex | section_channel_test |
| TypedController.Codegen | route_schema.ex | route_schema_test node-executed parse |
| RouteConfigCollector | route_schema.ex | route_schema_test path/query split |
| RouteRenderer | route_schema.ex | route_schema_test POST body |
| RouterIntrospector | route_schema/introspector | route_introspector_test |
| tstype.buildCSRFHeaders / getPhoenixCSRFToken / create / on / unsubscribe | priv/static transports | test/js/tstype_runtime_functions.test.mjs |

JS court-map references use `contains` (the parity gate's title matcher recognizes only
Elixir `test "..."` lines); each token is a code identifier in an executed node test.

## Operator decisions

- `codegen.module.Codegen.ValibotSchemaGenerator`: no README/CONTRACT text names Valibot as a
  non-goal. Proposed README wording: "Zod is the only boundary-schema library; no Valibot
  emission." Evidence: README line 128 ("Zod supplies executable boundary schemas"). Left MISSING.
- Several mappings (Helpers, SchemaFormatter, ConfigBuilder, FunctionCore) are by-behavior
  counterparts, not ports of the reference tests; stricter ports are optional follow-up.

## Files changed

- test/ash_surface/codegen_parity/codegen_modules_test.exs (new)
- test/js/tstype_runtime_functions.test.mjs (new)
- parity/court_map.json (30 entries; tstype 5 re-pointed)
- docs/zod-port/receipts/wave3-g5.md
- _build-g5 deleted.

No lib/ changes. Requests for other lanes: none.
