# Wave 3 Lane G4: Runtime Module Parity

Standing: PARTIAL

Runtime section: 33 of 41 ids pass or non_goal after this lane (before: 8 pass / 33 missing;
after: 34 pass / 5 non_goal / 0 broken / 2 missing). Two ids remain MISSING (below).

## Commands

- `mix test test/ash_surface/runtime_parity test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs` -> rc=0, `16 tests, 0 failures`.
- `mix ash_surface.parity` -> rc=1 (other lanes' backlog); runtime row `41  34/0/5/0/2`.
- `mix format --check-formatted` on the two new files -> rc=0.
- Co-running `test/ash_surface/parity` showed 8 failures in `gate_test`, `gate_hardening_test`,
  `gate_non_vacuity_test`; those files and `parity/` register code were being edited by other
  lanes during the run (e.g. shim test asserting live map sha unchanged). Not introduced here;
  UNVERIFIED whether they are green once the other lanes settle.

## Disposition (id -> counterpart -> court)

Court = `test/ash_surface/...`; all titles are checked by the gate.

| id | counterpart | court |
|----|-------------|-------|
| AshTypescript | config.ex (type overrides) | config_test "rejects override without import..." |
| Helpers | field_name.ex:30 compute | field_name_test "camel/pascal/snake..." |
| Manifest | AshSurface.from_manifest | from_manifest_test "action_ids are exactly..." |
| Manifest.Custom | custom.ash_surface placement | manifest_serializer_test, from_manifest_test |
| Resource | resource.ex + validator | typed_query_fields_test "compiled state..." |
| Resource.Info, Rpc.Info, Rpc | resource/info.ex:27-49 | typed_query_fields_test "typed_query is introspectable..." |
| Rpc.ErrorBuilder | errors.ex:29,133 | errors_test unknown_error / unhandled_error |
| Rpc.FieldExtractor | runtime_parity/field_selection.ex extract/2 (NEW) | runtime_parity/field_selection_test |
| Rpc.FieldProcessing.Atomizer | field_selection.ex atomize_requested_fields/4 (NEW) | field_selection_test (incl. no atom minting) |
| FieldSelector | field_selection.ex select/5 (NEW) + compiler/selection_schema.ex | field_selection_test, typed_query_fields_test, relationship_selection_schema_test |
| FieldSelector.Validation | field_selection.ex check_for_duplicates/5, validate_non_empty/3 (NEW) | field_selection_test, typed_query_fields_test |
| Rpc.InputFormatter | field_name.ex:151 client_to_internal; format_value(:input) (NEW) | field_name_test, field_selection_test |
| Rpc.OutputFormatter, Rpc.ValueFormatter | field_selection.ex format_value/5 (NEW) | field_selection_test |
| Rpc.RequestedFieldsProcessor | compiler/selection_schema.ex + select/5 | relationship_selection_schema_test, field_selection_test |
| Rpc.ValidationErrorSchemas | compiler/validation_error_schema.ex | error_schema_deep_test "ValidationErrorSchema" cases |
| TypeSystem.Introspection | compiler/type_facts.ex | manifest_type_dispatch_test |
| TypedChannel, .Dsl, .Info, .PayloadFormatter | compiler/section/channel + channel_discovery | section_channel_test, channel_discovery_test (node/zod parse) |
| TypedController, .Dsl, .Info | compiler/route_schema.ex, route introspector | route_schema_test, route_introspector_test |
| Rpc.Pipeline, Rpc.Request, Rpc.ResultProcessor, TypedController.RequestHandler, TypedController.Route | none | non_goal, README verbatim "it never actuates" (README.md:55, law 1) |

## Operator decisions

1. `Manifest.Dsl` (MISSING): Spark DSL extension that builds an app-wide Ash.Info.Manifest.
   ash_surface ingests manifests (`from_manifest`) and never builds one. Proposed README
   non-goal: "AshSurface does not assemble app-wide Ash manifests; it ingests the manifest Ash
   already produces." Needs README edit (not permitted to this lane).
2. `TypedChannel.Interception` (MISSING): compile-time injection of server-side Phoenix
   `handle_out` interception. ash_surface projects channel payload schemas only. Proposed README
   non-goal: "AshSurface does not intercept or rewrite server-side Phoenix channel traffic."
3. The five non_goal ids rely on the existing README law-1 sentence ("it never actuates"),
   read as: ash_surface has no server-side request-execution path (parse/run action/process
   result); execution is client dispatch admission, reconcile and UNKNOWN_AFTER_DISPATCH in
   `priv/static/ash_surface_runtime.mjs`. If the operator deems that sentence too loose,
   propose: "AshSurface ships no server-side RPC execution pipeline or controller request
   handler."
4. Several passes map by capability to existing courts (e.g. Resource.Info -> typed-query
   introspection); the operator may want dedicated Info-getter tests. The Info parity court
   `test/ash_surface_info_parity_court.exs` is not `_test.exs`, so `mix test` does not run it;
   it was deliberately not cited.

## Files changed

- NEW `lib/ash_surface/runtime_parity/field_selection.ex`
- NEW `test/ash_surface/runtime_parity/field_selection_test.exs`
- `parity/court_map.json` (31 runtime.module.* entries added/updated)
- NEW this receipt. `_build-g4` removed.
