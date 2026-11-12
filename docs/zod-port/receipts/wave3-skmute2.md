# Wave 3 Skeptic Mutation E2 (SK-mutE2)

Standing: PARTIAL

Lane SK-mutE2, read-only mutation skeptic, repo /Users/sac/ash_surface. Scratch: /tmp/ske2 (explicit tar of live repo, node_modules and deps symlinked, build root /tmp/ske2/_b seeded from _build/test/lib). Live tree never mutated.

## Method

- Scope: 48 test files under ported/{rpc/a,rpc/b,rpc/d,top,manifest,resource,codegen,typed_controller,typed_channel,ts} named (with or without .exs) in none of skmuta/b/c/d. Excluded: 14 entirely-skipped *_gap files (codegen/install, manifest_relationship_query_capabilities, rpc/a/error_protocol, rpc/b/manifest_generator, rpc_validate_action_read_action, top/codegen_check, top/resource_schema_mapped_fields, top/typescript_codegen, top/typescript_field_names_precedence, top/typescript_filter, ts/valibot, ts/zod/constraint_validation) and support/*.exs. Partially skipped json_manifest_generator_gap (22/36 skip) kept. 11 further files turned out to be named extensionless in the receipts (map_field_names_utility, persist_formatted_fields, calculation_field_formatting, field_formatting_comprehensive, formatter_artifact_gap, union_field_formatting, struct_field_selection, constraint_validation_fail, channel_verify, base_path, verify_typed_controller) and are not reported.
- Baseline: per-file isolated run, 59 green except channel_verify_test (5 failures, `Item is not a Spark DSL module`, already-red in isolation and in the 785-test full run; named in skmutb/skmutd, out of scope).
- Mutations: 38 single-edit mutations (M01-M17, S01-S15, T01-T06) applied to scratch lib, scope run once per mutation; red = failing test name absent from baseline. Restore sha256 == baseline sha256 for all 38 (EQ). Mutation M-series ran the 59-file set, S/T series ran survivor subsets.

## Result

All 48 in-scope files went red under at least one mutation; 0 already-red, 0 fully survived. Mutation key: M01 FieldName camel casing flipped; M03/M04/S10 ErrorBuilder/Errors type strings; M05 enable_filter/sort branch removed; M08 Pipeline success envelope false; M09 load restriction allow->deny; M10/S01/S02 Config hook predicates or->and; M11 has_more negated; S04 normalize_primitive ForbiddenField passthrough; S05/S06 ActionManifest get/actionType; S07/S08 FieldSelector throw tags; S11 RouteSchema namespace source; S13 ZodType integer; S14 forbidden token in field_selector.ex; S15 Compat input required? negated; T01 Config ignores env; T02 default true; T03 Fold allow_empty? default; T04 Fold union allowed; T05 RouteSchema drops .strict(); T06 FieldSelector forced snake_case.

| file | red under (failing tests added) |
|---|---|
| rpc/a/calculation_field_selection_test.exs | S07(2) |
| rpc/a/calculations_surface_test.exs | M01(11), M08(10) |
| rpc/a/channel_lifecycle_hooks_config_test.exs | S01(2), S02(2) |
| rpc/a/comprehensive_integration_surface_test.exs | M01(22), M03(1), M08(15) |
| rpc/a/custom_type_schema_test.exs | M01(2) |
| rpc/a/embedded_argument_rpc_surface_test.exs | M01(8), M04(1), M08(5) |
| rpc/a/embedded_argument_test.exs | M01(4) |
| rpc/a/enable_filter_surface_test.exs | M01(2), M05(4) |
| rpc/a/enable_sort_surface_test.exs | M01(2), M05(5) |
| rpc/a/entrypoint_resolution_surface_test.exs | M01(1), M08(1) |
| rpc/a/error_handling_surface_test.exs | M01(4), M03(2) |
| rpc/a/error_protocol_surface_test.exs | S10(1) |
| rpc/a/error_redaction_surface_test.exs | M01(2) |
| rpc/a/error_scenarios_surface_test.exs | M01(10), M03(1) |
| rpc/a/first_aggregate_complex_types_surface_test.exs | M01(4), M08(3) |
| rpc/a/forbidden_field_redaction_test.exs | S04(2) |
| rpc/a/input_field_formatting_surface_test.exs | M01(3), M08(3) |
| rpc/a/input_parsing_stress_surface_test.exs | M01(28), M08(26) |
| rpc/b/json_manifest_generator_gap_test.exs | S11(1) |
| rpc/b/json_manifest_generator_surface_test.exs | S05(2), S06(6), S15(1) |
| rpc/b/keyword_field_formatting_surface_test.exs | M01(2), M08(2) |
| rpc/b/keyword_field_validation_test.exs | S07(2), S08(1) |
| rpc/b/lifecycle_hooks_config_test.exs | M10(2) |
| rpc/b/load_restrictions_surface_test.exs | M01(21), M08(12), M09(10) |
| rpc/b/manifest_generator_config_test.exs | T01(3), T02(1) |
| rpc/b/map_field_name_rpc_surface_test.exs | M01(9), M08(9) |
| rpc/b/map_field_name_selection_test.exs | T06(4) |
| rpc/d/identity_and_struct_shapes_surface_test.exs | M01(5) |
| rpc/d/rpc_identities_surface_test.exs | M01(17), M08(7) |
| rpc/d/rpc_input_optionality_test.exs | S15(4) |
| rpc/d/rpc_integration_surface_test.exs | M01(11), M03(2) |
| rpc/d/rpc_mapped_identity_fields_surface_test.exs | M01(2), M08(2) |
| rpc/d/rpc_metadata_surface_test.exs | M01(35), M08(35) |
| rpc/d/rpc_optional_fields_surface_test.exs | M01(8), M08(6) |
| rpc/d/rpc_validate_action_surface_test.exs | M01(8), M08(10) |
| rpc/d/rpc_validation_error_structure_surface_test.exs | M01(12), M03(1), M08(1) |
| rpc/d/run_typed_query_runner_surface_test.exs | M01(14), M08(11), M11(1) |
| rpc/d/run_typed_query_surface_test.exs | M01(1) |
| rpc/d/runtime_source_of_truth_guard_test.exs | S14(1) |
| rpc/d/sort_and_filter_types_ir_surface_test.exs | M05(3) |
| rpc/d/sort_and_filter_types_surface_test.exs | M05(1) |
| rpc/d/struct_argument_integration_surface_test.exs | M01(5), M08(4) |
| rpc/d/struct_argument_test.exs | M01(1) |
| ts/root/custom_zod_overrides_test.exs | M01(1) |
| ts/root/entry_points_test.exs | S13(1) |
| ts/should_pass/zod_route_cases_test.exs | T05(2) |
| typed_controller/fold_argument_constraints_test.exs | T03(2), T04(1) |
| typed_controller/namespace_test.exs | S11(5) |

## Repair requests (grouped by file)

- rpc/a/error_protocol_surface_test.exs: only InvalidChanges type (S10, 1 test) flips; no test pins NotFound/Required/Forbidden/InvalidAttribute `type`/`short_message` strings from Errors; add exact-map assertions per error class.
- rpc/a/forbidden_field_redaction_test.exs: M12 (extract_value ForbiddenField -> :skip instead of nil) survives; the struct-with-ForbiddenField test does not pin that the key is present with nil rather than omitted.
- rpc/b/json_manifest_generator_surface_test.exs: M15 (actions sorted desc by functionName) survives; "function names are unique" never asserts ordering. Add sorted-order assertion. S03 manifest_file default also unpinned (manifest_generator_config_test.exs only tests configured value).
- rpc/b/json_manifest_generator_gap_test.exs: only 1 test flips (S11); non-skipped tests carry few lib-sensitive assertions.
- rpc/b/manifest_generator_config_test.exs: S03 (manifest_file default "x.md") survives; add default-nil assertions for manifest_file/0 and json_manifest_file/0.
- rpc/d/runtime_source_of_truth_guard_test.exs: string-grep guard only; S14 flips it via a literal token, but M09-style behaviour flips do not (expected for a guard). Acceptable; note only the 5 listed pipeline files are guarded - pipeline.ex/result_processor.ex are not in @runtime_files.
- rpc/d/rpc_validate_action_surface_test.exs / rpc/d/sort_and_filter_types_surface_test.exs: M06 (top-level page unsupported -> :ok) and M07 (unknown_page_keys admitted) survive across the ENTIRE scope: no in-scope test asserts {:pagination_not_supported, :top_level, :unsupported} nor {:unknown_page_keys, _}.
- rpc/d/run_typed_query_surface_test.exs / run_typed_query_runner_surface_test.exs: M16 (typed_query_not_found carries :x instead of requested name) survives scope-wide; assert vars.typed_query_name equals the requested name.
- rpc/a/calculation_field_selection_test.exs: S09 (complex_type throw tag changed) survives; no test pins {:requires_field_selection, :complex_type, ...}.
- typed_controller/fold_argument_constraints_test.exs: S12 (fold_arguments returns reversed order) survives; all tests use one argument. Add a 2+ argument ordering test.
- ts/root/entry_points_test.exs, rpc/d/struct_argument_test.exs, rpc/d/run_typed_query_surface_test.exs, rpc/a/error_redaction_surface_test.exs, ts/root/custom_zod_overrides_test.exs: flip under exactly one mutation (1-2 tests); thin single-mutation coverage.

Scratch left at /tmp/ske2 (out/*.txt per-mutation outputs, mut.py table).
