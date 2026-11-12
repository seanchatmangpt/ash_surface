# Wave 3 Integration Plan (GITPLAN)

Standing: PARTIAL

Subject: /Users/sac/ash_surface, HEAD 28d97201734697942817d406db455a7b084d2969 (origin HEAD equal at read time).
Ownership result: 135 of 457 files owned, 322 UNOWNED (52 receipts lack a parseable Files-changed section; attribute UNOWNED manually before staging). Read-only inventory. Peer session ash-surface-39 edits the same tree: re-run `git status --porcelain` at integration;
this list is a snapshot. Ownership derived mechanically from 'Files changed' sections of
docs/zod-port/receipts/*.md (30 of 82 receipts carry such a section; path-token match, so UNOWNED = no receipt names it, not proof of peer origin).

## 1. Status classification

- Modified tracked: 67
- Untracked files (expanded, excluding _build-*): 390
- Untracked _build-* dirs: 25 (never commit)

### 1a. Modified tracked

- owners: UNOWNED
  - .formatter.exs
  - conformance/elixir/runner.exs
  - conformance/js/replay.mjs
  - lib/ash_surface/projectors/js.ex
  - lib/ash_surface/transport.ex
  - lib/ash_surface/vocabulary.ex
  - package-lock.json
  - priv/static/ash_surface_runtime.mjs
  - test/ash_a2a_verifier_court_test.exs
  - test/ash_surface/compiler_coverage_test.exs
  - test/ash_surface/compiler_test.exs
  - test/ash_surface/formatter_registration_canary_test.exs
  - test/ash_surface/ir_codec_golden_test.exs
  - test/ash_surface/ir_codec_test.exs
  - test/ash_surface/no_local_do_test.exs
  - test/ash_surface/projector/expo_client_reconcile_test.exs
  - test/ash_surface/projector/expo_client_test.exs
  - test/ash_surface/projector/expo_receipts_hash_test.exs
  - test/ash_surface/projector_hardening_test.exs
  - test/ash_surface/schema_section_test.exs
  - test/ash_surface_igniter_idempotence_court_test.exs
  - test/ash_surface_verifier_court_test.exs
  - test/js/conformance_replay.test.mjs
  - test/js/generated_client_reconcile_runner.mjs
  - test/js/generated_js_projector_runner.mjs
  - test/js/ir_projection.test.mjs
  - test/js/ir_projector_deep.test.mjs
  - test/js/zod_boundaries.test.mjs
- owners: lane-01,wave2-b1a
  - test/ash_surface/compiler/schema_section_test.exs
- owners: lane-01,wave3-s1f
  - lib/ash_surface/compiler/schema.ex
  - lib/ash_surface/compiler/section/schema.ex
- owners: lane-01,wave3-s1h
  - lib/ash_surface/projector/expo.ex
- owners: lane-02,wave3-s1f
  - lib/ash_surface/projectors/js/zod_guard.ex
- owners: lane-12,wave3-f1m,wave3-g3
  - lib/ash_surface/resource/validator.ex
- owners: lane-12,wave3-g2
  - ontology.ttl
- owners: lane-17
  - lib/ash_surface/ir.ex
  - lib/ash_surface/ir/codec.ex
  - lib/ash_surface/projector/ir_entry.ex
- owners: lane-17,wave2-b1a
  - lib/ash_surface/compiler.ex
- owners: lane-17,wave3-s1f
  - lib/ash_surface/compiler/ir.ex
- owners: lane-19
  - package.json
- owners: lane-20
  - CHANGELOG.md
  - README.md
  - TESTING.md
  - conformance/MANIFEST.json
  - conformance/js/reference.mjs
  - conformance/vectors/canonical_json.json [GENERATED]
  - conformance/vectors/ir_codec.json [GENERATED]
  - conformance/vectors/receipt_binding.json [GENERATED]
  - conformance/vectors/receipt_digest.json [GENERATED]
  - conformance/vectors/reconcile_status.json [GENERATED]
  - conformance/vectors/refusal_vocabulary.json [GENERATED]
  - conformance/vectors/surface_contract_digest.json [GENERATED]
  - conformance/vectors/surface_contract_refusal.json [GENERATED]
  - conformance/vectors/transport_facts_admission.json [GENERATED]
  - conformance/vectors/transport_outcome.json [GENERATED]
  - conformance/vectors/transport_selection.json [GENERATED]
  - docs/CONFORMANCE.md
  - scripts/chicago_census.txt
  - scripts/conformance_regen.exs
  - test/ash_surface/ir_test.exs
- owners: wave2-b1a
  - test/ash_surface/ash_section_truth_test.exs
  - test/ash_surface/compiler/ash_section_test.exs
- owners: wave2-b1a,wave3-s1f
  - lib/ash_surface/compiler/ash_truth.ex
- owners: wave3-f1m
  - lib/ash_surface.ex
- owners: wave3-f1mc
  - test/ash_surface_mock_discipline_test.exs
- owners: wave3-s1h
  - test/ash_surface/projector/generated_artifacts_exec_test.exs

### 1b. Untracked by area and owner (per-lane commit groups)

#### group UNOWNED (294 files)
- 304_trial.mjs  [SCRATCH]
- conformance/js/zod_eval.mjs
- docs/KNOWN_DIVERGENCES.md
- docs/jira/v26.11.11/COMPARISON-ash-typescript.md
- docs/jira/v26.11.11/L01-constraint-intake.md
- docs/jira/v26.11.11/L02-ir-contract.md
- docs/jira/v26.11.11/L04-constraint-zod.md
- docs/jira/v26.11.11/L05-expo-mirror.md
- docs/jira/v26.11.11/L06-zodguard-courts.md
- docs/jira/v26.11.11/L07-safeparse-envelope.md
- docs/jira/v26.11.11/L08-runtime-issues.md
- docs/jira/v26.11.11/L09-filter-operators.md
- docs/jira/v26.11.11/L10-query-envelopes.md
- docs/jira/v26.11.11/L11-selection-admission.md
- docs/jira/v26.11.11/L14-conformance-constraints.md
- docs/jira/v26.11.11/L16-fragment-courts.md
- docs/jira/v26.11.11/L17-safeparse-courts.md
- docs/jira/v26.11.11/L20-relationship-loads.md
- docs/jira/v26.11.11/L21-union-types.md
- docs/jira/v26.11.11/L22-calculations.md
- docs/jira/v26.11.11/L23-identities-tenant.md
- docs/jira/v26.11.11/OPERATOR-DECISIONS.md
- docs/jira/v26.11.11/OVERVIEW.md
- docs/jira/v26.11.11/PARITY-WAVE2-BACKLOG.md
- docs/jira/v26.11.11/PARITY-WAVE3-QUEUE.md
- docs/jira/v26.11.11/PROJECT-REVIEWS.md
- docs/jira/v26.11.11/_LANES.md
- docs/jira/v26.11.11/receipts/L01.md
- docs/jira/v26.11.11/receipts/L02.md
- docs/jira/v26.11.11/receipts/L04.md
- docs/jira/v26.11.11/receipts/L05.md
- docs/jira/v26.11.11/receipts/L06.md
- docs/jira/v26.11.11/receipts/L07.md
- docs/jira/v26.11.11/receipts/L08.md
- docs/jira/v26.11.11/receipts/L09.md
- docs/jira/v26.11.11/receipts/L10.md
- docs/jira/v26.11.11/receipts/L11.md
- docs/jira/v26.11.11/receipts/L14.md
- docs/jira/v26.11.11/receipts/L16.md
- docs/jira/v26.11.11/receipts/L17.md
- docs/jira/v26.11.11/receipts/L18.md
- docs/jira/v26.11.11/receipts/L20.md
- docs/jira/v26.11.11/receipts/L21.md
- docs/jira/v26.11.11/receipts/L22.md
- docs/jira/v26.11.11/receipts/L23.md
- docs/jira/v26.11.11/receipts/L24.md
- docs/jira/v26.11.11/receipts/L25.md
- docs/jira/v26.11.12/TODO-FIX-AND-FINISH.md
- docs/zod-port/CONTRACT.md
- docs/zod-port/SHIM-COURTS.md
- docs/zod-port/receipts/lane-01.md
- docs/zod-port/receipts/lane-02.md
- docs/zod-port/receipts/lane-03.md
- docs/zod-port/receipts/lane-04.md
- docs/zod-port/receipts/lane-05.md
- docs/zod-port/receipts/lane-06.md
- docs/zod-port/receipts/lane-07.md
- docs/zod-port/receipts/lane-08.md
- docs/zod-port/receipts/lane-09.md
- docs/zod-port/receipts/lane-10.md
- docs/zod-port/receipts/lane-11.md
- docs/zod-port/receipts/lane-12.md
- docs/zod-port/receipts/lane-13.md
- docs/zod-port/receipts/lane-14.md
- docs/zod-port/receipts/lane-15.md
- docs/zod-port/receipts/lane-16.md
- docs/zod-port/receipts/lane-17.md
- docs/zod-port/receipts/lane-18.md
- docs/zod-port/receipts/lane-19.md
- docs/zod-port/receipts/lane-20.md
- docs/zod-port/receipts/wave2-b1a.md
- docs/zod-port/receipts/wave2-ca.md
- docs/zod-port/receipts/wave2-cf.md
- docs/zod-port/receipts/wave2-ds.md
- docs/zod-port/receipts/wave2-em.md
- docs/zod-port/receipts/wave2-er.md
- docs/zod-port/receipts/wave2-fl.md
- docs/zod-port/receipts/wave2-id.md
- docs/zod-port/receipts/wave2-js.md
- docs/zod-port/receipts/wave2-qs.md
- docs/zod-port/receipts/wave2-rc.md
- docs/zod-port/receipts/wave2-rs.md
- docs/zod-port/receipts/wave2-un.md
- docs/zod-port/receipts/wave2-zg.md
- docs/zod-port/receipts/wave2-zt.md
- docs/zod-port/receipts/wave3-01.md
- docs/zod-port/receipts/wave3-02.md
- docs/zod-port/receipts/wave3-03.md
- docs/zod-port/receipts/wave3-04.md
- docs/zod-port/receipts/wave3-05.md
- docs/zod-port/receipts/wave3-06.md
- docs/zod-port/receipts/wave3-07.md
- docs/zod-port/receipts/wave3-08.md
- docs/zod-port/receipts/wave3-09.md
- docs/zod-port/receipts/wave3-10.md
- docs/zod-port/receipts/wave3-11.md
- docs/zod-port/receipts/wave3-12.md
- docs/zod-port/receipts/wave3-13.md
- docs/zod-port/receipts/wave3-14.md
- docs/zod-port/receipts/wave3-15.md
- docs/zod-port/receipts/wave3-17.md
- docs/zod-port/receipts/wave3-18.md
- docs/zod-port/receipts/wave3-19.md
- docs/zod-port/receipts/wave3-f1e.md
- docs/zod-port/receipts/wave3-f1g.md
- docs/zod-port/receipts/wave3-f1m.md
- docs/zod-port/receipts/wave3-f1mc.md
- docs/zod-port/receipts/wave3-f1om.md
- docs/zod-port/receipts/wave3-f1p.md
- docs/zod-port/receipts/wave3-f1r.md
- docs/zod-port/receipts/wave3-f1t.md
- docs/zod-port/receipts/wave3-g2.md
- docs/zod-port/receipts/wave3-g3.md
- docs/zod-port/receipts/wave3-g4.md
- docs/zod-port/receipts/wave3-g6.md
- docs/zod-port/receipts/wave3-opdec.md
- docs/zod-port/receipts/wave3-q1.md
- docs/zod-port/receipts/wave3-q2.md
- docs/zod-port/receipts/wave3-regr.md
- docs/zod-port/receipts/wave3-s1a.md
- docs/zod-port/receipts/wave3-s1b.md
- docs/zod-port/receipts/wave3-s1c.md
- docs/zod-port/receipts/wave3-s1d.md
- docs/zod-port/receipts/wave3-s1e.md
- docs/zod-port/receipts/wave3-s1f.md
- docs/zod-port/receipts/wave3-s1g.md
- docs/zod-port/receipts/wave3-s1h.md
- docs/zod-port/receipts/wave3-s1i.md
- docs/zod-port/receipts/wave3-s2.md
- docs/zod-port/receipts/wave3-s3a.md
- lib/ash_surface/envelope.ex
- lib/ash_surface/error_handler.ex
- lib/ash_surface/field_name/mapping.ex
- lib/ash_surface/ir/error_shape.ex
- lib/ash_surface/manifest/dsl.ex
- lib/ash_surface/naming.ex
- lib/ash_surface/parity/court_map.ex
- lib/ash_surface/parity/inventory.ex
- lib/ash_surface/parity/register.ex
- lib/ash_surface/parity/report.ex
- lib/ash_surface/parity/test_index.ex
- lib/ash_surface/parity_tests/inventory.ex
- lib/ash_surface/parity_tests/report.ex
- lib/ash_surface/parity_tests/skips.ex
- lib/ash_surface/resource/typed_query_fields.ex
- lib/mix/tasks/ash_surface.codegen.ex
- lib/mix/tasks/ash_surface.npm_install.ex
- lib/mix/tasks/ash_surface.parity.ex
- lib/mix/tasks/ash_surface.parity.tests.ex
- parity/capabilities.json  [GENERATED]
- priv/static/ash_surface_channel_transport.mjs
- scripts/parity_inventory.exs
- scripts/shim_court/courts/01_zod_type.sh
- scripts/shim_court/courts/02_union_schema.sh
- scripts/shim_court/courts/03_zod_guard.sh
- scripts/shim_court/courts/04_errors.sh
- scripts/shim_court/courts/05_runtime_transport.sh
- scripts/shim_court/courts/06_conformance_vector.sh
- scripts/shim_court/courts/07_parity_gate.sh
- scripts/shim_court/lib.sh
- scripts/shim_court/run_all.sh
- test/ash_surface/adversarial/container_renderers_adversarial_test.exs
- test/ash_surface/adversarial/envelope_renderers_adversarial_test.exs
- test/ash_surface/adversarial/route_channel_adversarial_test.exs
- test/ash_surface/adversarial/support.exs
- test/ash_surface/channel_discovery_test.exs
- test/ash_surface/codegen_runtime_copy_test.exs
- test/ash_surface/codegen_task_test.exs
- test/ash_surface/compiler/calculation_schema_errors_test.exs
- test/ash_surface/compiler/calculation_schema_kinds_test.exs
- test/ash_surface/compiler/constraint_validator_test.exs
- test/ash_surface/compiler/embedded_program_court_test.exs
- test/ash_surface/compiler/filter_schema_executed_test.exs
- test/ash_surface/compiler/filter_schema_facts_test.exs
- test/ash_surface/compiler/identity_schema_test.exs
- test/ash_surface/compiler/ir_wiring_test.exs
- test/ash_surface/compiler/number_literal_test.exs
- test/ash_surface/compiler/relationship_load_behaviour_test.exs
- test/ash_surface/compiler/s1g_schema_courts_test.exs
- test/ash_surface/compiler/schema_constraint_test.exs
- test/ash_surface/compiler/union_schema_test.exs
- test/ash_surface/compiler/zod_type_s3b_test.exs
- test/ash_surface/config_deep_test.exs
- test/ash_surface/config_test.exs
- test/ash_surface/digest_api_test.exs
- test/ash_surface/divergence_close/aggregate_selection_test.exs
- test/ash_surface/divergence_close/filter_divergence_test.exs
- test/ash_surface/dsl/route_presentation_parity_test.exs
- test/ash_surface/envelope_test.exs
- test/ash_surface/error_runtime_test.exs
- test/ash_surface/error_schema_deep_test.exs
- test/ash_surface/error_schema_test.exs
- test/ash_surface/errors_config_test.exs
- test/ash_surface/errors_test.exs
- test/ash_surface/f1e_errcfg_test.exs
- test/ash_surface/field_name_mapping_test.exs
- test/ash_surface/field_name_test.exs
- test/ash_surface/fixtures/calc_agg_fixture_test.exs
- test/ash_surface/fixtures/harness_ext_fixture_test.exs
- test/ash_surface/fixtures/identity_tenant_fixture_test.exs
- test/ash_surface/fixtures/mapped_names_fixture_test.exs
- test/ash_surface/fixtures/paging_fixture_test.exs
- test/ash_surface/fixtures/relations_fixture_test.exs
- test/ash_surface/fixtures/routes_router_fixture_test.exs
- test/ash_surface/fixtures/typed_containers_fixture_test.exs
- test/ash_surface/formatter_export_test.exs
- test/ash_surface/idempotence_court_wave3_test.exs
- test/ash_surface/inference_deep_test.exs
- test/ash_surface/inference_test.exs
- test/ash_surface/installer/installer_test.exs
- test/ash_surface/manifest_type_dispatch_test.exs
- test/ash_surface/naming_test.exs
- test/ash_surface/object_mode/object_mode_wiring_test.exs
- test/ash_surface/parity/gate_hardening_test.exs
- test/ash_surface/parity/gate_non_vacuity_test.exs
- test/ash_surface/parity/gate_test.exs
- test/ash_surface/parity/inventory_test.exs
- test/ash_surface/parity_deepen/dsl_runtime_courts_test.exs
- test/ash_surface/parity_deepen/schema_courts_test.exs
- test/ash_surface/parity_kinds/type_kinds_test.exs
- test/ash_surface/projector/expo_origin_test.exs
- test/ash_surface/projectors/js/zod_guard_test.exs
- test/ash_surface/projectors/js_declaration_order_test.exs
- test/ash_surface/projectors/js_mapped_fields_test.exs
- test/ash_surface/projectors/js_safeparse_test.exs
- test/ash_surface/projectors/js_schema_wiring_test.exs
- test/ash_surface/query_schema_wave2_test.exs
- test/ash_surface/resource/dsl_options_test.exs
- test/ash_surface/route_introspector_test.exs
- test/ash_surface/route_schema_test.exs
- test/ash_surface/runtime_parity/manifest_dsl_test.exs
- test/ash_surface/shim_court_selfcheck_test.exs
- test/ash_surface/transformers/manifest_transformers_test.exs
- test/ash_surface/transport_classify_test.exs
- test/ash_surface/typed_query_fields_test.exs
- test/ash_surface/vocabulary_issue_twin_test.exs
- test/ash_surface/zod_guard_regex_test.exs
- test/ash_surface/zod_type_parity_test.exs
- test/js/adversarial/runtime_zod_adversarial.test.mjs
- test/js/channel_transport.test.mjs
- test/js/constraint_validation_agreement.test.mjs
- test/js/generated_js_safeparse_runner.mjs
- test/js/generated_schema_wiring_runner.mjs
- test/js/http_transport.test.mjs
- test/js/http_transport_s3a.test.mjs
- test/js/runtime_issue_vocabulary.test.mjs
- test/js/transport_phase_classification.test.mjs
- test/malformed_specimens/typed_query_invalid_fields.ex
- test/malformed_specimens/typed_query_unknown_action.ex
- test/malformed_specimens/unknown_action_projection.ex
- test/support/channel_fixtures.ex
- test/support/zod_fixtures/calc_agg.ex
- test/support/zod_fixtures/constraints.ex
- test/support/zod_fixtures/harness_ext.ex
- test/support/zod_fixtures/identity_tenant.ex
- test/support/zod_fixtures/mapped_names.ex
- test/support/zod_fixtures/paging.ex
- test/support/zod_fixtures/relations.ex
- test/support/zod_fixtures/routes_router.ex
- test/support/zod_fixtures/typed_containers.ex
- test/ts/calculation_schema_runner.mjs
- test/ts/cases/calculations.json
- test/ts/cases/errors_union.json
- test/ts/cases/filters.json
- test/ts/cases/identities.json
- test/ts/cases/relationships_load.json
- test/ts/cases/sort_page.json
- test/ts/cases/unions.json
- test/ts/fragment_runner.mjs
- test/ts/inference/shouldFail/invalidFields.ts
- test/ts/inference/shouldFail/invalidSort.ts
- test/ts/inference/shouldFail/invalidStructure.ts
- test/ts/inference/shouldFail/loadRestrictions.ts
- test/ts/inference/shouldFail/noFieldsReadActions.ts
- test/ts/inference/shouldFail/typeMismatches.ts
- test/ts/inference/shouldFail/unionValidation.ts
- test/ts/inference/shouldFail/wrongPaginationTypes.ts
- test/ts/inference/shouldPass/calculations.ts
- test/ts/inference/shouldPass/compositePrimaryKey.ts
- test/ts/inference/shouldPass/conditionalPagination.ts
- test/ts/inference/shouldPass/embeddedResources.ts
- test/ts/inference/shouldPass/identities.ts
- test/ts/inference/shouldPass/inputOptionality.ts
- test/ts/inference/shouldPass/keywordTuple.ts
- test/ts/inference/shouldPass/loadRestrictions.ts
- test/ts/inference/shouldPass/nestedQueryOpts.ts
- test/ts/inference/shouldPass/noFields.ts
- test/ts/inference/shouldPass/operations.ts
- test/ts/inference/shouldPass/relationships.ts
- test/ts/inference/shouldPass/sortFields.ts
- test/ts/inference/shouldPass/typedMaps.ts
- test/ts/inference/shouldPass/typedStructs.ts
- test/ts/inference/shouldPass/unionTypes.ts
- test/ts/kinds_runner.mjs
#### group lane-01 (3 files)
- lib/ash_surface/compiler/union_schema.ex
- lib/ash_surface/compiler/zod_type.ex
- test/ash_surface/zod_type_core_test.exs
#### group lane-02 (1 files)
- test/ash_surface/zod_guard_grammar_test.exs
#### group lane-03 (2 files)
- lib/ash_surface/compiler/embedded_schema.ex
- test/ash_surface/compiler/embedded_schema_test.exs
#### group lane-04 (2 files)
- lib/ash_surface/compiler/filter_schema.ex
- test/ash_surface/compiler/filter_schema_test.exs
#### group lane-05 (2 files)
- lib/ash_surface/compiler/query_schema.ex
- test/ash_surface/query_schema_test.exs
#### group lane-06 (3 files)
- lib/ash_surface/compiler/relationship_schema.ex
- lib/ash_surface/compiler/selection_schema.ex
- test/ash_surface/compiler/relationship_selection_schema_test.exs
#### group lane-07 (2 files)
- lib/ash_surface/compiler/calculation_schema.ex
- test/ash_surface/compiler/calculation_schema_test.exs
#### group lane-11 (2 files)
- lib/ash_surface/compiler/section/channel.ex
- test/ash_surface/section_channel_test.exs
#### group lane-12 (1 files)
- lib/ash_surface/resource/info.ex
#### group lane-19 (10 files)
- test/ash_surface/ts/inference_tsc_test.exs
- test/ash_surface/ts/ts_compile_test.exs
- test/ash_surface/ts/zod_codegen_test.exs
- test/ash_surface/ts/zod_runtime_features_test.exs
- test/ash_surface/ts/zod_runtime_test.exs
- test/support/zod_fixtures.ex
- test/ts/cases.json
- test/ts/shouldFail/todo_input_misuse.ts
- test/ts/shouldPass/todo_input.ts
- test/ts/zod_runtime_runner.mjs
#### group lane-20 (12 files)
- conformance/vectors/calculation_envelope.json  [GENERATED]
- conformance/vectors/constraints.json  [GENERATED]
- conformance/vectors/error_envelope.json  [GENERATED]
- conformance/vectors/filter_operators.json  [GENERATED]
- conformance/vectors/identity_get.json  [GENERATED]
- conformance/vectors/query_envelope.json  [GENERATED]
- conformance/vectors/relationship_loads.json  [GENERATED]
- conformance/vectors/selection_admission.json  [GENERATED]
- conformance/vectors/transport_wire.json  [GENERATED]
- conformance/vectors/union_schema.json  [GENERATED]
- docs/jira/v26.11.11/README.md
- test/ts/cases/constraints.json
#### group wave2-b1a (2 files)
- lib/ash_surface/compiler/type_facts.ex
- test/ash_surface/compiler/section_schema_constraints_test.exs
#### group wave2-zt (1 files)
- test/ash_surface/zod_type_wave2_test.exs
#### group wave3-f1m (4 files)
- docs/jira/v26.11.11/PARITY-REGISTER.md
- lib/ash_surface/projectors/js/inference.ex
- test/ash_surface/metadata_projection_test.exs
- test/ash_surface/resource/validator_action_types_test.exs
#### group wave3-g1 (5 files)
- docs/zod-port/receipts/wave3-g1.md
- lib/ash_surface/config.ex
- lib/ash_surface/config/verifier.ex
- parity/court_map.json  [GENERATED]
- test/ash_surface/config/parity_keys_test.exs
#### group wave3-g2 (2 files)
- test/ash_surface/dsl/rpc_surface_parity_test.exs
- test/ash_surface/dsl/typed_controller_channel_parity_test.exs
#### group wave3-g3 (4 files)
- lib/ash_surface/domain.ex
- lib/ash_surface/resource/verifiers/checks.ex
- lib/ash_surface/verifier_checker.ex
- test/ash_surface/verifiers/g3_verifiers_test.exs
#### group wave3-g4 (2 files)
- lib/ash_surface/runtime_parity/field_selection.ex
- test/ash_surface/runtime_parity/field_selection_test.exs
#### group wave3-g5 (3 files)
- docs/zod-port/receipts/wave3-g5.md
- test/ash_surface/codegen_parity/codegen_modules_test.exs
- test/js/tstype_runtime_functions.test.mjs
#### group wave3-g6 (9 files)
- lib/ash_surface/installer/esbuild.ex
- lib/ash_surface/installer/framework.ex
- lib/ash_surface/installer/installer.ex
- lib/ash_surface/installer/package_json.ex
- lib/ash_surface/installer/tsconfig.ex
- lib/ash_surface/installer/vite.ex
- test/ash_surface/error_type_parity/error_type_parity_test.exs
- test/ash_surface/installer_parity/framework_parity_test.exs
- test/ash_surface/installer_parity/npm_install_task_test.exs
#### group wave3-s1a (3 files)
- test/ash_surface/compiler/calculation_schema_args_test.exs
- test/ash_surface/compiler/calculation_schema_s1a_test.exs
- test/ash_surface/compiler/relationship_schema_s1a_test.exs
#### group wave3-s1b (4 files)
- lib/ash_surface/compiler/error_schema.ex
- lib/ash_surface/error_formatter.ex
- lib/ash_surface/errors.ex
- test/ash_surface/errors_s1b_test.exs
#### group wave3-s1c (1 files)
- test/ash_surface/compiler/filter_schema_size_test.exs
#### group wave3-s1e (2 files)
- priv/static/ash_surface_http_transport.mjs
- test/js/http_transport_h5_m13.test.mjs
#### group wave3-s1f (11 files)
- lib/ash_surface/compiler/channel_discovery.ex
- lib/ash_surface/compiler/constraint_validator.ex
- lib/ash_surface/compiler/identity_schema.ex
- lib/ash_surface/compiler/number_literal.ex
- lib/ash_surface/compiler/object_mode.ex
- lib/ash_surface/compiler/resource_facts.ex
- lib/ash_surface/compiler/route_schema.ex
- lib/ash_surface/compiler/route_schema/introspector.ex
- lib/ash_surface/compiler/validation_error_schema.ex
- test/ash_surface/compiler/zod_type_wave3_test.exs
- test/ash_surface/projectors/js/zod_guard_wave3_test.exs
#### group wave3-s1h (1 files)
- test/ash_surface/projector/expo_wave3_s1h_court_test.exs
#### group wave3-s1i (2 files)
- lib/ash_surface/field_name.ex
- test/ash_surface/s1i_identity_selection_fieldname_test.exs

Staging protocol per group: `git add -- <explicit paths above>`; never `git add -A`/`.`. Modified-tracked files owned by a lane join that lane's group (1a). Files shared by several receipts are listed under the first matching receipt; commit in receipt order and re-check `git diff --cached --stat`.

### 1c. Generated / must-not-commit flags

- GENERATED (commit only with a regen receipt, verify generator first): parity/*.json, conformance/vectors/*.json, conformance/MANIFEST.json, priv/static/*.mjs, package-lock.json, scripts/chicago_census.txt. ggen.lock / generated resource.ex: none present in porcelain at read time.
- Must not commit: _build-*/ (25 dirs), node_modules/ (gitignored), 304_trial.mjs (root scratch, UNOWNED), /tmp scratch, shim_court_scratch.*.
- Note: parity/ is untracked as a whole directory; confirm intent (generated inventory) with parity owner receipts before staging.

## 2. Cleanup inventory (sizes in KB via du -sk)

- _build-t0: 327308 KB
- _build-f1dc: 326008 KB
- _build-coord: 326004 KB
- _build-b1a: 324692 KB
- _build-f1k: 296260 KB
- _build-g4b: 280024 KB
- _build-f1rf: 278328 KB
- _build-g3b: 181608 KB
- _build-f1tr: 162548 KB
- _build-f1or: 162152 KB
- _build-f1ff: 162144 KB
- _build-w316: 162124 KB
- _build-w316-igniter-court: 154964 KB
- _build-f1sg: 154956 KB
- _build-s3b2: 139036 KB
- _build-f1tb: 137168 KB
- _build-w316b: 135248 KB
- _build-s2bb: 135248 KB
- _build-f1ob: 135248 KB
- _build-f1ffb: 135248 KB
- _build-f1d: 122364 KB
- _build-g2b: 113592 KB
- _build-s2b: 87520 KB
- _build-s3b: 17068 KB
- _build-f1gh: 10468 KB
- _build-w315: 0 KB


Live processes at read time (ps): mix test/ash_surface.parity beam runs from ~9:51-9:59PM using the shared `_build` plus `cp -R _build _build-t0` in flight (pid 24381). Lanes are RUNNING: every `_build-*` is STILL-IN-USE until its lane receipt lands and `ps` shows no beam/cp/mix. The ps output does not expose MIX_BUILD_ROOT per process; before delete run `lsof +D <dir> | head` per dir (empty = safe).
- _build-w315: 0 KB, empty, safe now.
- All other _build-*: safe-to-delete-at-integration (lane build roots are leases per same-checkout-fanout law), after lsof confirms no holder. `_build-coord` belongs to the coordinator: delete last.

/tmp scratch (du -sk):
- /tmp/gs-lane12: 1063248 KB, likely lane-12 scratch clone; verify no holder via lsof, then safe at integration.
- /tmp/g1_parity.txt..g6_new.json, g*_test.exs/.log/.out (about 30 small files, <80 KB each): safe at integration (logs).
- /tmp/gate*.log/.out/.err, gate-compile.log, gate-test.log, gen_actions.txt, gen_funcs.txt, ggen.lock.orig: safe at integration; keep /tmp/ggen.lock.orig until ggen.lock restore decision made.
- /tmp/guard-*-wm-6287.txt: 4 files, small; pid-tagged, peer-session owned possibly: leave unless pid 6287 dead.
- /Users/sac/.cache/tmp/shim_court_scratch.CckWYA: 171244 KB; STILL-IN-USE if a shim-court is running (a court restores a file from it); check `ps` for shim_court before delete.

No deletions performed by this lane. Deletion is a coordinator transition; thin APFS snapshots after deletion per disk-cleanup rule.

## 3. test/ash_surface/projectors/js/ tracked status

`git ls-files test/ash_surface/projectors/js` returned nothing: directory is UNTRACKED (untracked, listed as `?? test/ash_surface/projectors/js/`). Contents: zod_guard_test.exs, zod_guard_wave3_test.exs. Stage by explicit file path with the js/zod_guard lane group.

## 4. Commit and push protocol

```
# per group (message written with the Write tool to /tmp/msg-<group>.txt first)
git add -- <explicit paths>
git diff --cached --stat
git commit -F /tmp/msg-<group>.txt
# merge only; never rebase, never force push, no stash
git fetch origin && git merge origin/main     # if origin moved (peer ash-surface-39)
git push origin main
# verify (never trust push output)
git ls-remote origin refs/heads/main | grep $(git rev-parse HEAD) || echo PUSH-NOT-LANDED
```
Retry push x3 on transient GitHub 500, then re-run ls-remote verify. Do not chain commit and push with `&&` alone; check `git rev-parse HEAD` changed after commit. Before each commit re-run `git status --porcelain` scoped to the group, since ash-surface-39 edits the same tree: stage only paths this plan assigns; leave unknown paths unstaged.

## Attribution

Refreshed by wave3-cu (lane I21), 2026-11-12. Source: read-only `git status --porcelain -uall` (excluding `_build-*`, `node_modules/`): 880 untracked + 106 modified = 986 paths at read time (peer session edits the same tree; re-run at integration). Evidence: exact path, brace-list expansion (`dir/{a,b}_x.ext`), or basename named in `docs/zod-port/**/*.md` and `docs/jira/v26.11.11/**/*.md` (excluding this plan and the attrib/gitplan/cu receipts); generator evidence from `scripts/conformance_regen.exs`. Weak = directory/stem-token evidence only. File mtimes not used. Receipt: `docs/zod-port/receipts/wave3-cu.md`. Prior section (wave3-attrib, 397 untracked) is superseded.

Counts: OWNED=939 (of which weak=377), GENERATED=22, SCRATCH=1, UNKNOWN=24. Untracked: GENERATED=11, OWNED=865, UNKNOWN=4. Modified: GENERATED=11, OWNED=75, UNKNOWN=20.

### Previously-UNKNOWN (23) resolution

| File | Now | Receipt(s) | Evidence |
|---|---|---|---|
| `lib/ash_surface/installer/esbuild.ex` | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/installer/framework.ex` | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/installer/vite.ex` | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/parity/register.ex` | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `lib/ash_surface/parity/test_index.ex` | OWNED | wave3-f1gh | path named |
| `lib/ash_surface/parity_tests/report.ex` | OWNED | wave3-t0 | path named via brace list |
| `lib/ash_surface/parity_tests/skips.ex` | OWNED | wave3-t0 | path named via brace list |
| `test/ash_surface/compiler/embedded_program_court_test.exs` | OWNED | wave3-f1rf | path named |
| `test/ash_surface/idempotence_court_wave3_test.exs` | OWNED | wave3-16 | path named |
| `test/ash_surface/parity/inventory_test.exs` | OWNED | wave3-q1 | path named via brace list |
| `test/ash_surface/parity_deepen/dsl_runtime_courts_test.exs` | OWNED | wave3-f1d | path named via brace list |
| `test/ash_surface/parity_kinds/type_kinds_test.exs` | OWNED | wave3-f1k | path named |
| `test/ash_surface/transformers/manifest_transformers_test.exs` | OWNED | wave3-g3b | path named via brace list |
| `test/ash_surface/ts/ts_compile_test.exs` | OWNED | lane-19 | path named via brace list |
| `test/js/transport_phase_classification.test.mjs` | UNKNOWN | - | no receipt names path/basename |
| `test/support/zod_fixtures/calc_agg.ex` | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/paging.ex` | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/relations.ex` | OWNED | wave3-05 | path named via brace list |
| `test/ts/cases/filters.json` | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/identities.json` | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/sort_page.json` | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/unions.json` | OWNED | wave3-06 | path named via brace list |
| `test/ts/kinds_runner.mjs` | OWNED | wave3-f1k | path named |

Resolutions by named receipt line: `parity_tests/{inventory,skips,report}.ex` and `parity_tests/{gate_non_vacuity,skips}_test.exs` are in wave3-t0 Files-changed; `manifest_transformers_test.exs` and `fold_argument_constraints_test.exs` in wave3-g3b; `parity_kinds/*` and `test/ts/kinds_runner.mjs` in wave3-f1k. `parity_deepen/*` is named by directory in wave3-f1af, f1d, f1un, opd2, t3 (weak). `test/js/transport_phase_classification.test.mjs` remains UNKNOWN: no receipt in docs names it.

### UNKNOWN (leave unstaged; operator questions)

- `test/ash_surface/envelope_test.exs` (untracked): no receipt names path, basename, or directory
- `test/ash_surface/projectors/js_embedded_filter_export_test.exs` (untracked): no receipt names path, basename, or directory
- `test/js/transport_phase_classification.test.mjs` (untracked): no receipt names path, basename, or directory
- `test/support/ported/ash_names.ex` (untracked): no receipt names path, basename, or directory
- `lib/ash_surface/a2a_bridge.ex` (modified): no receipt names path, basename, or directory
- `lib/ash_surface/agent_card_artifact.ex` (modified): no receipt names path, basename, or directory
- `test/aex_spark_dead_surface_court.exs` (modified): no receipt names path, basename, or directory
- `test/airo_surface_pin_w675_test.exs` (modified): no receipt names path, basename, or directory
- `test/ash_a2a_composition_court.exs` (modified): no receipt names path, basename, or directory
- `test/ash_a2a_info_parity_court.exs` (modified): no receipt names path, basename, or directory
- `test/ash_r2rml_composition_court.exs` (modified): no receipt names path, basename, or directory
- `test/ash_r2rml_info_parity_court.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface/a2a_bridge_test.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface/health_http_mapping_test.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface/transport_fallback_test.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface/transport_falsifiers_test.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface_composition_court.exs` (modified): no receipt names path, basename, or directory
- `test/ash_surface_spark_parity_court_test.exs` (modified): no receipt names path, basename, or directory
- `test/audit_trail_composition_court.exs` (modified): no receipt names path, basename, or directory
- `test/audit_trail_info_parity_court.exs` (modified): no receipt names path, basename, or directory
- `test/docs_nav_coverage_test.exs` (modified): no receipt names path, basename, or directory
- `test/notification_extension_composition_court.exs` (modified): no receipt names path, basename, or directory
- `test/notification_extension_info_parity_court.exs` (modified): no receipt names path, basename, or directory
- `test/tokyo_depeg_surface_test.exs` (modified): no receipt names path, basename, or directory

Operator questions:

1. `test/js/transport_phase_classification.test.mjs`, `test/ash_surface/envelope_test.exs`, `test/ash_surface/projectors/js_embedded_filter_export_test.exs`, `test/support/ported/ash_names.ex`: which lane/session authored these, and commit or discard?
2. Modified tracked files with no naming receipt (a2a_bridge, agent_card_artifact, composition/info-parity/spark-parity courts, health_http_mapping, transport_fallback/falsifiers, docs_nav_coverage, tokyo_depeg): likely the mock-discipline/fleet-wide format or ash-surface-39 edits; confirm owner before staging, else leave out of the wave commit.
3. `test/support/ported/**` and `test/ash_surface/ported/**` OWNED rows rest on directory evidence; confirm bulk-stage as one ported-tests group.

### Cleanup inventory refresh (read-only; deletion is coordinator's at integration)

`_build-*` dirs present (KB via `du -sk`): coord 337972, b1a 324692, f1tb-igniter-court 315572, f1fw 174328, ce 174088, cp 173940, skl 164196, f1tr 162548, f1or 162152, f1ff 162144, w316 162124, w316-igniter-court 154964, cp-igniter-court 154960, cq 129972, s3b 17068, cv 7644, ct 6836, cs 2212, cr 1884, w315 0. Total about 2.8 GB. cr/cs/ct/cv are likely in-flight lanes; verify lane-done first. None appear in `git status` (ignored).

`/tmp` scratch still present: 931 entries (about 900 are `__KMP_REGISTERED_LIB_*` OpenMP markers, not ours). Lane scratch: `/tmp/*.exs` probes (act_fix, art, ce_probe, ct_probe, eh, f1dump{,2,3}, f1k_probe, fs_probe, g3b_probe, g3t, g4b, gu8d_probe, inspect_action, inv, l04*, l05_mirror, l21_example, l22_example, p, p2, p25-p28, ...), `/tmp/attrib.{py,json}`, `/tmp/attrib_counts.json`, `/tmp/attrib_section.md`, `/tmp/cu_attrib.py`, `/tmp/cu_rows.json`, `/tmp/cp_ash_surface.log`, `/tmp/ash_surface_lineage_{bench_4623,stale_49479}`, `/tmp/census_contract.txt`. Repo-root scratch: `304_trial.mjs` (untracked, SCRATCH).

### Per-file table

| File | State | Class | Receipt(s)/generator | Evidence |
|---|---|---|---|---|
| `.formatter.exs` | modified | OWNED | wave2-cf,wave3-10,PARITY-REGISTER | path named |
| `304_trial.mjs` | untracked | SCRATCH | - | named only as disk-cleanup item in PARITY-WAVE2-BACKLOG; do not commit |
| `CHANGELOG.md` | modified | OWNED | CONTRACT,lane-20,wave3-11,PARITY-WAVE2-BACKLOG,L18 | path named |
| `README.md` | modified | OWNED | CONTRACT,wave3-t16,lane-20,README,wave3-tsa11 | path named |
| `TESTING.md` | modified | OWNED | CONTRACT,lane-20,wave3-f1tr,wave3-19,PARITY-WAVE2-BACKLOG | path named |
| `conformance/MANIFEST.json` | modified | OWNED | lane-20,wave3-04,wave3-f1ff,wave3-t3,wave3-01 | path named |
| `conformance/elixir/runner.exs` | modified | OWNED | wave3-04,wave3-01,L14,L14-conformance-constraints | path named |
| `conformance/js/reference.mjs` | modified | OWNED | lane-20,wave3-s1f,wave3-04,L14,L14-conformance-constraints | path named |
| `conformance/js/replay.mjs` | modified | OWNED | wave3-s1e,wave3-s3a,wave3-04,wave3-f1or,wave3-f1ff | path named |
| `conformance/js/zod_eval.mjs` | untracked | OWNED | wave3-04 | path named |
| `conformance/vectors/calculation_envelope.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/canonical_json.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/constraints.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/error_envelope.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/filter_operators.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/identity_get.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/ir_codec.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/query_envelope.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/receipt_binding.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/receipt_digest.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/reconcile_status.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/refusal_vocabulary.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/relationship_loads.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/selection_admission.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/surface_contract_digest.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/surface_contract_refusal.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/transport_facts_admission.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/transport_outcome.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/transport_selection.json` | modified | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/transport_wire.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `conformance/vectors/union_schema.json` | untracked | GENERATED | scripts/conformance_regen.exs | vector kind in conformance_regen.exs |
| `docs/CONFORMANCE.md` | modified | OWNED | CONTRACT,lane-20,wave3-04,L14,L14-conformance-constraints | path named |
| `docs/KNOWN_DIVERGENCES.md` | untracked | OWNED | wave3-f1rw,wave3-q1,wave3-gu8-kd06,wave3-gu9,wave3-gu9-kd07 | path named |
| `docs/jira/v26.11.11/COMPARISON-ash-typescript.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/INTEGRATION-PLAN.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L01-constraint-intake.md` | untracked | OWNED | L01 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L02-ir-contract.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L04-constraint-zod.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L05-expo-mirror.md` | untracked | OWNED | L05 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L06-zodguard-courts.md` | untracked | OWNED | L20-relationship-loads | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L07-safeparse-envelope.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L08-runtime-issues.md` | untracked | OWNED | L08 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L09-filter-operators.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L10-query-envelopes.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L11-selection-admission.md` | untracked | OWNED | L11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L14-conformance-constraints.md` | untracked | OWNED | L14 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L16-fragment-courts.md` | untracked | OWNED | L16 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L17-safeparse-courts.md` | untracked | OWNED | L17 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L20-relationship-loads.md` | untracked | OWNED | L20 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L21-union-types.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L22-calculations.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/L23-identities-tenant.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/OPERATOR-DECISIONS.md` | untracked | OWNED | wave3-opdec,wave3-gu9,wave3-f1m,wave3-t6b,wave3-opd2 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/OVERVIEW.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/PARITY-REGISTER.md` | untracked | OWNED | CONTRACT,L24,wave3-f1dc,wave3-11,wave3-regr | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/PARITY-WAVE2-BACKLOG.md` | untracked | OWNED | wave3-11,PARITY-WAVE3-QUEUE,PARITY-REGISTER | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/PARITY-WAVE3-QUEUE.md` | untracked | OWNED | TEST-PORT-CONTRACT | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/PROJECT-REVIEWS.md` | untracked | OWNED | PARITY-WAVE3-QUEUE | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/README.md` | untracked | OWNED | L25 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/_LANES.md` | untracked | OWNED | wave3-11 | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L01.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L02.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L04.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L05.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L06.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L07.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L08.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L09.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L10.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L11.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L14.md` | untracked | OWNED | L14-conformance-constraints | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L16.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L17.md` | untracked | OWNED | L17,L17-safeparse-courts | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L18.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L20.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L21.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L22.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L23.md` | untracked | OWNED | L23-identities-tenant | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L24.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.11/receipts/L25.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/jira/v26.11.12/TODO-FIX-AND-FINISH.md` | untracked | OWNED | PARITY-WAVE3-QUEUE | path named |
| `docs/zod-port/CONTRACT.md` | untracked | OWNED | _LANES,wave3-11,PARITY-WAVE2-BACKLOG,PARITY-WAVE3-QUEUE | lane/receipt doc self-owned |
| `docs/zod-port/RPC-PIPELINE-CORE.md` | untracked | OWNED | wave3-t6b,PARITY-WAVE3-QUEUE | lane/receipt doc self-owned |
| `docs/zod-port/SHIM-COURTS.md` | untracked | OWNED | - | lane/receipt doc self-owned |
| `docs/zod-port/TEST-PORT-CONTRACT.md` | untracked | OWNED | wave3-tsa10,wave3-t1,wave3-gu10,wave3-t6b,wave3-t17 | lane/receipt doc self-owned |
| `docs/zod-port/TEST-PORT-PLAN.md` | untracked | OWNED | wave3-t0,TEST-PORT-CONTRACT | lane/receipt doc self-owned |
| `docs/zod-port/receipts/lane-01.md` | untracked | OWNED | lane-01 | receipt self-owned |
| `docs/zod-port/receipts/lane-02.md` | untracked | OWNED | lane-02 | receipt self-owned |
| `docs/zod-port/receipts/lane-03.md` | untracked | OWNED | lane-03 | receipt self-owned |
| `docs/zod-port/receipts/lane-04.md` | untracked | OWNED | lane-04 | receipt self-owned |
| `docs/zod-port/receipts/lane-05.md` | untracked | OWNED | lane-05 | receipt self-owned |
| `docs/zod-port/receipts/lane-06.md` | untracked | OWNED | lane-06 | receipt self-owned |
| `docs/zod-port/receipts/lane-07.md` | untracked | OWNED | lane-07 | receipt self-owned |
| `docs/zod-port/receipts/lane-08.md` | untracked | OWNED | lane-08 | receipt self-owned |
| `docs/zod-port/receipts/lane-09.md` | untracked | OWNED | lane-09 | receipt self-owned |
| `docs/zod-port/receipts/lane-10.md` | untracked | OWNED | lane-10 | receipt self-owned |
| `docs/zod-port/receipts/lane-11.md` | untracked | OWNED | lane-11 | receipt self-owned |
| `docs/zod-port/receipts/lane-12.md` | untracked | OWNED | lane-12 | receipt self-owned |
| `docs/zod-port/receipts/lane-13.md` | untracked | OWNED | lane-13 | receipt self-owned |
| `docs/zod-port/receipts/lane-14.md` | untracked | OWNED | lane-14 | receipt self-owned |
| `docs/zod-port/receipts/lane-15.md` | untracked | OWNED | lane-15 | receipt self-owned |
| `docs/zod-port/receipts/lane-16.md` | untracked | OWNED | lane-16 | receipt self-owned |
| `docs/zod-port/receipts/lane-17.md` | untracked | OWNED | lane-17 | receipt self-owned |
| `docs/zod-port/receipts/lane-18.md` | untracked | OWNED | lane-18 | receipt self-owned |
| `docs/zod-port/receipts/lane-19.md` | untracked | OWNED | lane-19 | receipt self-owned |
| `docs/zod-port/receipts/lane-20.md` | untracked | OWNED | lane-20 | receipt self-owned |
| `docs/zod-port/receipts/wave2-b1a.md` | untracked | OWNED | wave2-b1a | receipt self-owned |
| `docs/zod-port/receipts/wave2-ca.md` | untracked | OWNED | wave2-ca | receipt self-owned |
| `docs/zod-port/receipts/wave2-cf.md` | untracked | OWNED | wave2-cf | receipt self-owned |
| `docs/zod-port/receipts/wave2-ds.md` | untracked | OWNED | wave2-ds | receipt self-owned |
| `docs/zod-port/receipts/wave2-em.md` | untracked | OWNED | wave2-em | receipt self-owned |
| `docs/zod-port/receipts/wave2-er.md` | untracked | OWNED | wave2-er | receipt self-owned |
| `docs/zod-port/receipts/wave2-fl.md` | untracked | OWNED | wave2-fl | receipt self-owned |
| `docs/zod-port/receipts/wave2-id.md` | untracked | OWNED | wave2-id | receipt self-owned |
| `docs/zod-port/receipts/wave2-js.md` | untracked | OWNED | wave2-js | receipt self-owned |
| `docs/zod-port/receipts/wave2-qs.md` | untracked | OWNED | wave2-qs | receipt self-owned |
| `docs/zod-port/receipts/wave2-rc.md` | untracked | OWNED | wave2-rc | receipt self-owned |
| `docs/zod-port/receipts/wave2-rs.md` | untracked | OWNED | wave2-rs | receipt self-owned |
| `docs/zod-port/receipts/wave2-un.md` | untracked | OWNED | wave2-un | receipt self-owned |
| `docs/zod-port/receipts/wave2-zg.md` | untracked | OWNED | wave2-zg | receipt self-owned |
| `docs/zod-port/receipts/wave2-zt.md` | untracked | OWNED | wave2-zt | receipt self-owned |
| `docs/zod-port/receipts/wave3-01.md` | untracked | OWNED | wave3-01 | receipt self-owned |
| `docs/zod-port/receipts/wave3-02.md` | untracked | OWNED | wave3-02 | receipt self-owned |
| `docs/zod-port/receipts/wave3-03.md` | untracked | OWNED | wave3-03 | receipt self-owned |
| `docs/zod-port/receipts/wave3-04.md` | untracked | OWNED | wave3-04 | receipt self-owned |
| `docs/zod-port/receipts/wave3-05.md` | untracked | OWNED | wave3-05 | receipt self-owned |
| `docs/zod-port/receipts/wave3-06.md` | untracked | OWNED | wave3-06 | receipt self-owned |
| `docs/zod-port/receipts/wave3-07.md` | untracked | OWNED | wave3-07 | receipt self-owned |
| `docs/zod-port/receipts/wave3-08.md` | untracked | OWNED | wave3-08 | receipt self-owned |
| `docs/zod-port/receipts/wave3-09.md` | untracked | OWNED | wave3-09 | receipt self-owned |
| `docs/zod-port/receipts/wave3-10.md` | untracked | OWNED | wave3-10 | receipt self-owned |
| `docs/zod-port/receipts/wave3-11.md` | untracked | OWNED | wave3-11 | receipt self-owned |
| `docs/zod-port/receipts/wave3-12.md` | untracked | OWNED | wave3-12 | receipt self-owned |
| `docs/zod-port/receipts/wave3-13.md` | untracked | OWNED | wave3-13 | receipt self-owned |
| `docs/zod-port/receipts/wave3-14.md` | untracked | OWNED | wave3-14 | receipt self-owned |
| `docs/zod-port/receipts/wave3-15.md` | untracked | OWNED | wave3-15 | receipt self-owned |
| `docs/zod-port/receipts/wave3-16.md` | untracked | OWNED | wave3-16 | receipt self-owned |
| `docs/zod-port/receipts/wave3-17.md` | untracked | OWNED | wave3-17 | receipt self-owned |
| `docs/zod-port/receipts/wave3-18.md` | untracked | OWNED | wave3-18 | receipt self-owned |
| `docs/zod-port/receipts/wave3-19.md` | untracked | OWNED | wave3-19 | receipt self-owned |
| `docs/zod-port/receipts/wave3-attrib.md` | untracked | OWNED | wave3-attrib | receipt self-owned |
| `docs/zod-port/receipts/wave3-cf.md` | untracked | OWNED | wave3-cf | receipt self-owned |
| `docs/zod-port/receipts/wave3-cg.md` | untracked | OWNED | wave3-cg | receipt self-owned |
| `docs/zod-port/receipts/wave3-ch.md` | untracked | OWNED | wave3-ch | receipt self-owned |
| `docs/zod-port/receipts/wave3-ci.md` | untracked | OWNED | wave3-ci | receipt self-owned |
| `docs/zod-port/receipts/wave3-cj.md` | untracked | OWNED | wave3-cj | receipt self-owned |
| `docs/zod-port/receipts/wave3-cn.md` | untracked | OWNED | wave3-cn | receipt self-owned |
| `docs/zod-port/receipts/wave3-co.md` | untracked | OWNED | wave3-co | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1af.md` | untracked | OWNED | wave3-f1af | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1cc.md` | untracked | OWNED | wave3-f1cc | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1ck.md` | untracked | OWNED | wave3-f1ck | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1cr.md` | untracked | OWNED | wave3-f1cr | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1d.md` | untracked | OWNED | wave3-f1d | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1dc.md` | untracked | OWNED | wave3-f1dc | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1dm.md` | untracked | OWNED | wave3-f1dm | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1e.md` | untracked | OWNED | wave3-f1e | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1ec.md` | untracked | OWNED | wave3-f1ec | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1en.md` | untracked | OWNED | wave3-f1en | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1ff.md` | untracked | OWNED | wave3-f1ff | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1fs.md` | untracked | OWNED | wave3-f1fs | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1fw.md` | untracked | OWNED | wave3-f1fw | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1g.md` | untracked | OWNED | wave3-f1g | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1gh.md` | untracked | OWNED | wave3-f1gh | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1k.md` | untracked | OWNED | wave3-f1k | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1kd.md` | untracked | OWNED | wave3-f1kd | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1m.md` | untracked | OWNED | wave3-f1m | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1mc.md` | untracked | OWNED | wave3-f1mc | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1nb.md` | untracked | OWNED | wave3-f1nb | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1nd.md` | untracked | OWNED | wave3-f1nd | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1om.md` | untracked | OWNED | wave3-f1om | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1or.md` | untracked | OWNED | wave3-f1or | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1p.md` | untracked | OWNED | wave3-f1p | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1r.md` | untracked | OWNED | wave3-f1r | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1rf.md` | untracked | OWNED | wave3-f1rf | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1rp.md` | untracked | OWNED | wave3-f1rp | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1rw.md` | untracked | OWNED | wave3-f1rw | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1sa.md` | untracked | OWNED | wave3-f1sa | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1sg.md` | untracked | OWNED | wave3-f1sg | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1sh.md` | untracked | OWNED | wave3-f1sh | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1t.md` | untracked | OWNED | wave3-f1t | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1tr.md` | untracked | OWNED | wave3-f1tr | receipt self-owned |
| `docs/zod-port/receipts/wave3-f1un.md` | untracked | OWNED | wave3-f1un | receipt self-owned |
| `docs/zod-port/receipts/wave3-g1.md` | untracked | OWNED | wave3-g1 | receipt self-owned |
| `docs/zod-port/receipts/wave3-g2.md` | untracked | OWNED | wave3-g2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-g2b.md` | untracked | OWNED | wave3-g2b | receipt self-owned |
| `docs/zod-port/receipts/wave3-g3.md` | untracked | OWNED | wave3-g3 | receipt self-owned |
| `docs/zod-port/receipts/wave3-g3b.md` | untracked | OWNED | wave3-g3b | receipt self-owned |
| `docs/zod-port/receipts/wave3-g4.md` | untracked | OWNED | wave3-g4 | receipt self-owned |
| `docs/zod-port/receipts/wave3-g4b.md` | untracked | OWNED | wave3-g4b | receipt self-owned |
| `docs/zod-port/receipts/wave3-g5.md` | untracked | OWNED | wave3-g5 | receipt self-owned |
| `docs/zod-port/receipts/wave3-g6.md` | untracked | OWNED | wave3-g6 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gitplan.md` | untracked | OWNED | wave3-gitplan | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu10.md` | untracked | OWNED | wave3-gu10 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu11.md` | untracked | OWNED | wave3-gu11 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu12.md` | untracked | OWNED | wave3-gu12 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu2.md` | untracked | OWNED | wave3-gu2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu7.md` | untracked | OWNED | wave3-gu7 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu8-kd06.md` | untracked | OWNED | wave3-gu8-kd06 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu8.md` | untracked | OWNED | wave3-gu8 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu9-kd07.md` | untracked | OWNED | wave3-gu9-kd07 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gu9.md` | untracked | OWNED | wave3-gu9 | receipt self-owned |
| `docs/zod-port/receipts/wave3-gutq.md` | untracked | OWNED | wave3-gutq | receipt self-owned |
| `docs/zod-port/receipts/wave3-opd2.md` | untracked | OWNED | wave3-opd2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-opdec.md` | untracked | OWNED | wave3-opdec | receipt self-owned |
| `docs/zod-port/receipts/wave3-pg.md` | untracked | OWNED | wave3-pg | receipt self-owned |
| `docs/zod-port/receipts/wave3-q1.md` | untracked | OWNED | wave3-q1 | receipt self-owned |
| `docs/zod-port/receipts/wave3-q2.md` | untracked | OWNED | wave3-q2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-regr.md` | untracked | OWNED | wave3-regr | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1a.md` | untracked | OWNED | wave3-s1a | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1b.md` | untracked | OWNED | wave3-s1b | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1c.md` | untracked | OWNED | wave3-s1c | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1d.md` | untracked | OWNED | wave3-s1d | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1e.md` | untracked | OWNED | wave3-s1e | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1f.md` | untracked | OWNED | wave3-s1f | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1g.md` | untracked | OWNED | wave3-s1g | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1h.md` | untracked | OWNED | wave3-s1h | receipt self-owned |
| `docs/zod-port/receipts/wave3-s1i.md` | untracked | OWNED | wave3-s1i | receipt self-owned |
| `docs/zod-port/receipts/wave3-s2.md` | untracked | OWNED | wave3-s2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-s2b.md` | untracked | OWNED | wave3-s2b | receipt self-owned |
| `docs/zod-port/receipts/wave3-s3a.md` | untracked | OWNED | wave3-s3a | receipt self-owned |
| `docs/zod-port/receipts/wave3-s3b.md` | untracked | OWNED | wave3-s3b | receipt self-owned |
| `docs/zod-port/receipts/wave3-skledger.md` | untracked | OWNED | wave3-skledger | receipt self-owned |
| `docs/zod-port/receipts/wave3-sknodo.md` | untracked | OWNED | wave3-sknodo | receipt self-owned |
| `docs/zod-port/receipts/wave3-t0.md` | untracked | OWNED | wave3-t0 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t1.md` | untracked | OWNED | wave3-t1 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t10.md` | untracked | OWNED | wave3-t10 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t11.md` | untracked | OWNED | wave3-t11 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t12.md` | untracked | OWNED | wave3-t12 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t13.md` | untracked | OWNED | wave3-t13 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t14.md` | untracked | OWNED | wave3-t14 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t14b.md` | untracked | OWNED | wave3-t14b | receipt self-owned |
| `docs/zod-port/receipts/wave3-t15.md` | untracked | OWNED | wave3-t15 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t16.md` | untracked | OWNED | wave3-t16 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t16b.md` | untracked | OWNED | wave3-t16b | receipt self-owned |
| `docs/zod-port/receipts/wave3-t17.md` | untracked | OWNED | wave3-t17 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t2.md` | untracked | OWNED | wave3-t2 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t3.md` | untracked | OWNED | wave3-t3 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t4.md` | untracked | OWNED | wave3-t4 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t5-fixtures-ready.md` | untracked | OWNED | wave3-t5-fixtures-ready | receipt self-owned |
| `docs/zod-port/receipts/wave3-t5.md` | untracked | OWNED | wave3-t5 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t6.md` | untracked | OWNED | wave3-t6 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t6b.md` | untracked | OWNED | wave3-t6b | receipt self-owned |
| `docs/zod-port/receipts/wave3-t7.md` | untracked | OWNED | wave3-t7 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t8.md` | untracked | OWNED | wave3-t8 | receipt self-owned |
| `docs/zod-port/receipts/wave3-t9.md` | untracked | OWNED | wave3-t9 | receipt self-owned |
| `docs/zod-port/receipts/wave3-tsa10.md` | untracked | OWNED | wave3-tsa10 | receipt self-owned |
| `docs/zod-port/receipts/wave3-tsa11.md` | untracked | OWNED | wave3-tsa11 | receipt self-owned |
| `lib/ash_surface.ex` | modified | OWNED | wave3-t15,wave3-18,wave3-01,wave3-f1sg,wave3-g4b | path named |
| `lib/ash_surface/a2a_bridge.ex` | modified | UNKNOWN | - | no receipt names path/basename |
| `lib/ash_surface/agent_card_artifact.ex` | modified | UNKNOWN | - | no receipt names path/basename |
| `lib/ash_surface/compiler.ex` | modified | OWNED | lane-17,L02,L02-ir-contract,wave3-01,wave3-t16b | path named |
| `lib/ash_surface/compiler/ash_truth.ex` | modified | OWNED | L01,L23 | path named |
| `lib/ash_surface/compiler/calculation_schema.ex` | untracked | OWNED | wave3-f1om | path named via brace list |
| `lib/ash_surface/compiler/channel_discovery.ex` | untracked | OWNED | wave2-rc,wave3-s1d | path named |
| `lib/ash_surface/compiler/constraint_validator.ex` | untracked | OWNED | wave3-s1f,wave3-14 | path named |
| `lib/ash_surface/compiler/embedded_schema.ex` | untracked | OWNED | wave3-f1om,wave3-s1g | path named via brace list |
| `lib/ash_surface/compiler/error_schema.ex` | untracked | OWNED | lane-08 | path named |
| `lib/ash_surface/compiler/filter_schema.ex` | untracked | OWNED | wave2-fl,L09,wave3-s1c,wave3-f1dc,wave3-f1dm | path named |
| `lib/ash_surface/compiler/identity_schema.ex` | untracked | OWNED | L23-identities-tenant,wave3-s1i,L23,wave2-id | path named |
| `lib/ash_surface/compiler/ir.ex` | modified | OWNED | lane-17,wave3-01 | path named |
| `lib/ash_surface/compiler/number_literal.ex` | untracked | OWNED | wave3-f1ff | path named |
| `lib/ash_surface/compiler/object_mode.ex` | untracked | OWNED | wave3-f1om | path named via brace list |
| `lib/ash_surface/compiler/query_schema.ex` | untracked | OWNED | wave3-s1f | path named via brace list |
| `lib/ash_surface/compiler/record_schema.ex` | untracked | OWNED | wave3-gu2 | path named |
| `lib/ash_surface/compiler/relationship_schema.ex` | untracked | OWNED | wave3-f1om | path named via brace list |
| `lib/ash_surface/compiler/resource_facts.ex` | untracked | OWNED | wave3-tsa11,wave3-tsa10,wave3-01,wave3-t4,wave3-f1cc | path named |
| `lib/ash_surface/compiler/route_schema.ex` | untracked | OWNED | wave3-s1h,wave3-g2,wave2-rc,wave3-g2b,lane-10 | path named |
| `lib/ash_surface/compiler/route_schema/fold.ex` | untracked | OWNED | wave3-ch,wave3-g3b | path named |
| `lib/ash_surface/compiler/route_schema/introspector.ex` | untracked | OWNED | wave3-s1h,wave2-rc | path named |
| `lib/ash_surface/compiler/route_schema/verifier.ex` | untracked | OWNED | wave3-t14b | path named |
| `lib/ash_surface/compiler/schema.ex` | modified | OWNED | L16-fragment-courts,L10,L20-relationship-loads,L06,L11-selection-admission | path named |
| `lib/ash_surface/compiler/section/channel.ex` | untracked | OWNED | wave2-rc,lane-11,wave3-s1d | path named |
| `lib/ash_surface/compiler/section/schema.ex` | modified | OWNED | wave3-t16b | path named |
| `lib/ash_surface/compiler/selection_schema.ex` | untracked | OWNED | wave2-rs,L22-calculations,lane-06,L11,wave3-s1i | path named |
| `lib/ash_surface/compiler/type_facts.ex` | untracked | OWNED | wave3-t7,wave3-f1sa,wave3-t3,wave2-b1a,wave3-t2 | path named |
| `lib/ash_surface/compiler/union_schema.ex` | untracked | OWNED | wave3-s1g | path named via brace list |
| `lib/ash_surface/compiler/validation_error_schema.ex` | untracked | OWNED | wave3-s1g | path named via brace list |
| `lib/ash_surface/compiler/zod_type.ex` | untracked | OWNED | wave3-s1f | path named via brace list |
| `lib/ash_surface/config.ex` | untracked | OWNED | wave3-g1,wave2-cf,wave3-t9,wave3-12,lane-14 | path named |
| `lib/ash_surface/config/verifier.ex` | untracked | OWNED | wave3-g1,wave2-cf,lane-14,wave3-f1ck | path named |
| `lib/ash_surface/domain.ex` | untracked | OWNED | wave3-f1t,wave3-g3,PARITY-REGISTER | path named |
| `lib/ash_surface/envelope.ex` | untracked | OWNED | wave2-rc | path named |
| `lib/ash_surface/error_formatter.ex` | untracked | OWNED | wave3-12,lane-09 | path named |
| `lib/ash_surface/error_handler.ex` | untracked | OWNED | lane-20,lane-09 | path named |
| `lib/ash_surface/errors.ex` | untracked | OWNED | wave3-g2,wave3-s1b,wave3-12,wave2-er,lane-09 | path named |
| `lib/ash_surface/field_name.ex` | untracked | OWNED | lane-13,wave3-f1fs,wave3-t1,wave3-t3,wave3-f1fw | path named |
| `lib/ash_surface/field_name/mapping.ex` | untracked | OWNED | wave3-13 | path named |
| `lib/ash_surface/installer/esbuild.ex` | untracked | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/installer/framework.ex` | untracked | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/installer/installer.ex` | untracked | OWNED | wave2-cf,wave3-t3 | path named |
| `lib/ash_surface/installer/package_json.ex` | untracked | OWNED | wave2-er | path named via brace list |
| `lib/ash_surface/installer/tsconfig.ex` | untracked | OWNED | wave2-er | path named via brace list |
| `lib/ash_surface/installer/vite.ex` | untracked | OWNED | wave3-g6 | path named via brace list |
| `lib/ash_surface/ir.ex` | modified | OWNED | lane-17,L02,L02-ir-contract,wave3-01 | path named |
| `lib/ash_surface/ir/codec.ex` | modified | OWNED | lane-17,L02,L02-ir-contract,wave3-01 | path named |
| `lib/ash_surface/ir/error_shape.ex` | untracked | OWNED | lane-08 | path named |
| `lib/ash_surface/manifest/action_manifest.ex` | untracked | OWNED | wave3-tsa10,wave3-gu9 | path named |
| `lib/ash_surface/manifest/dsl.ex` | untracked | OWNED | wave3-f1sg,wave3-g4b | path named |
| `lib/ash_surface/naming.ex` | untracked | OWNED | lane-13 | path named |
| `lib/ash_surface/parity/court_map.ex` | untracked | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `lib/ash_surface/parity/inventory.ex` | untracked | OWNED | wave3-q1 | path named via brace list |
| `lib/ash_surface/parity/register.ex` | untracked | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `lib/ash_surface/parity/report.ex` | untracked | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `lib/ash_surface/parity/test_index.ex` | untracked | OWNED | wave3-f1gh | path named |
| `lib/ash_surface/parity_tests/inventory.ex` | untracked | OWNED | wave3-t0 | path named via brace list |
| `lib/ash_surface/parity_tests/report.ex` | untracked | OWNED | wave3-t0 | path named via brace list |
| `lib/ash_surface/parity_tests/skips.ex` | untracked | OWNED | wave3-t0 | path named via brace list |
| `lib/ash_surface/projector/expo.ex` | modified | OWNED | wave3-s1h,wave3-s1e,wave3-s3a,L05,L05-expo-mirror | path named |
| `lib/ash_surface/projector/ir_entry.ex` | modified | OWNED | lane-17,wave3-01 | path named |
| `lib/ash_surface/projectors/js.ex` | modified | OWNED | L07-safeparse-envelope,lane-15,L07,wave3-02,L17-safeparse-courts | path named |
| `lib/ash_surface/projectors/js/inference.ex` | untracked | OWNED | lane-13,lane-18,wave3-08,wave3-f1sh | path named |
| `lib/ash_surface/projectors/js/zod_guard.ex` | modified | OWNED | wave2-zt,L10,L10-query-envelopes,wave3-s1f,L06-zodguard-courts | path named |
| `lib/ash_surface/resource/info.ex` | untracked | OWNED | lane-12 | path named |
| `lib/ash_surface/resource/typed_query_fields.ex` | untracked | OWNED | wave3-09 | path named |
| `lib/ash_surface/resource/validator.ex` | modified | OWNED | wave3-t12,wave3-08,PARITY-WAVE2-BACKLOG,wave3-g3,lane-12 | path named |
| `lib/ash_surface/resource/verifiers/action_type_field_names.ex` | untracked | OWNED | wave3-t4 | path named |
| `lib/ash_surface/resource/verifiers/checks.ex` | untracked | OWNED | wave3-t3,wave3-t4,wave3-g3 | path named |
| `lib/ash_surface/runtime_parity/field_selection.ex` | untracked | OWNED | wave3-g4 | path named |
| `lib/ash_surface/runtime_parity/requested_fields/atomizer.ex` | untracked | OWNED | wave3-f1fw | basename named (weak) |
| `lib/ash_surface/runtime_parity/requested_fields/compat.ex` | untracked | OWNED | wave3-f1nd,wave3-f1d,PARITY-WAVE3-QUEUE | directory-only evidence (weak) |
| `lib/ash_surface/runtime_parity/requested_fields/field_selector.ex` | untracked | OWNED | wave3-f1nd,wave3-f1d,PARITY-WAVE3-QUEUE | path named |
| `lib/ash_surface/runtime_parity/requested_fields/introspection.ex` | untracked | OWNED | wave3-f1nd,wave3-f1d,PARITY-WAVE3-QUEUE | directory-only evidence (weak) |
| `lib/ash_surface/runtime_parity/requested_fields/load_restrictions.ex` | untracked | OWNED | wave3-f1nd,wave3-f1d,PARITY-WAVE3-QUEUE | directory-only evidence (weak) |
| `lib/ash_surface/runtime_parity/requested_fields/validation.ex` | untracked | OWNED | wave3-f1nd,wave3-f1d,PARITY-WAVE3-QUEUE | directory-only evidence (weak) |
| `lib/ash_surface/runtime_parity/requested_fields_processor.ex` | untracked | OWNED | wave3-t5 | path named |
| `lib/ash_surface/runtime_parity/rpc/error_builder.ex` | untracked | OWNED | wave3-t6b,wave3-f1ec | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/field_extractor.ex` | untracked | OWNED | wave3-t6b | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/field_formatter.ex` | untracked | OWNED | wave3-t6b | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/input_formatter.ex` | untracked | OWNED | wave3-t6b,wave3-f1fw | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/output_formatter.ex` | untracked | OWNED | wave3-t6b | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/pipeline.ex` | untracked | OWNED | wave3-f1tr,wave3-pg,wave3-sknodo,wave3-f1af,wave3-f1nd | path named |
| `lib/ash_surface/runtime_parity/rpc/request.ex` | untracked | OWNED | wave3-t6b | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/result_processor.ex` | untracked | OWNED | wave3-t6b | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/support.ex` | untracked | OWNED | wave3-s2,wave3-t14,wave3-t6b,wave3-s2b,wave3-f1fw | basename named (weak) |
| `lib/ash_surface/runtime_parity/rpc/typed_query.ex` | untracked | OWNED | wave3-gutq | path named |
| `lib/ash_surface/runtime_parity/rpc/value_formatter.ex` | untracked | OWNED | wave3-t11 | path named |
| `lib/ash_surface/transport.ex` | modified | OWNED | wave3-18 | path named |
| `lib/ash_surface/verifier_checker.ex` | untracked | OWNED | wave3-g3 | path named |
| `lib/ash_surface/vocabulary.ex` | modified | OWNED | L08-runtime-issues,wave3-17,PARITY-WAVE2-BACKLOG,L08 | path named |
| `lib/mix/tasks/ash_surface.codegen.ex` | untracked | OWNED | CONTRACT,wave3-t1,wave2-cf,lane-15,wave3-03 | path named |
| `lib/mix/tasks/ash_surface.npm_install.ex` | untracked | OWNED | lane-16 | path named |
| `lib/mix/tasks/ash_surface.parity.ex` | untracked | OWNED | wave3-q1,wave3-f1gh,PARITY-WAVE3-QUEUE | path named |
| `lib/mix/tasks/ash_surface.parity.tests.ex` | untracked | OWNED | wave3-t0 | path named |
| `ontology.ttl` | modified | OWNED | CONTRACT,lane-20,wave3-g2,wave2-ds,wave3-f1t | path named |
| `package-lock.json` | modified | OWNED | wave3-03 | path named |
| `package.json` | modified | OWNED | CONTRACT,wave3-pg,wave3-f1gh,L06,wave3-f1nd | path named |
| `parity/capabilities.json` | untracked | OWNED | wave3-q2 | path named via brace list |
| `parity/court_map.json` | untracked | OWNED | wave3-q2 | path named via brace list |
| `parity/test_inventory.json` | untracked | GENERATED | scripts/conformance_regen.exs | parity.tests --regenerate-inventory |
| `parity/test_ledger.json` | untracked | OWNED | wave3-tsa11,wave3-t14,wave3-f1sa,wave3-gu7,wave3-gu9 | path named |
| `playground/.gitignore` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/AGENTS.md` | untracked | OWNED | PROJECT-REVIEWS | basename named (weak) |
| `playground/README.md` | untracked | OWNED | CONTRACT,wave3-t16,lane-20,README,wave3-tsa11 | basename named (weak) |
| `playground/assets/client.jsx` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/assets/component/surface_playground.jsx` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/assets/test/live_check.mjs` | untracked | OWNED | wave3-pg | basename named (weak) |
| `playground/assets/test/zod.test.mjs` | untracked | OWNED | wave3-pg | basename named (weak) |
| `playground/assets/validate.mjs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/assets/zod_entry.mjs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/build.mjs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/bun.lock` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/config/config.exs` | untracked | OWNED | PROJECT-REVIEWS | basename named (weak) |
| `playground/config/dev.exs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/config/prod.exs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/config/test.exs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/lib/playground/application.ex` | untracked | OWNED | PROJECT-REVIEWS | basename named (weak) |
| `playground/lib/playground/surface.ex` | untracked | OWNED | PROJECT-REVIEWS,wave3-t15,wave3-18,wave3-01,wave3-f1sg | basename named (weak) |
| `playground/lib/playground_web/endpoint.ex` | untracked | OWNED | PROJECT-REVIEWS | basename named (weak) |
| `playground/lib/playground_web/error_html.ex` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/lib/playground_web/page_controller.ex` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/lib/playground_web/router.ex` | untracked | OWNED | PROJECT-REVIEWS | basename named (weak) |
| `playground/mix.exs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/mix.lock` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/package.json` | untracked | OWNED | wave3-pg | path named |
| `playground/shared/zod_fixtures.ex` | untracked | OWNED | wave3-pg | path named |
| `playground/test/playground_web/page_test.exs` | untracked | OWNED | wave3-pg | stem/dir-token match (weak) |
| `playground/test/test_helper.exs` | untracked | OWNED | PROJECT-REVIEWS,wave3-f1p,wave3-07,wave3-t0,TEST-PORT-PLAN | basename named (weak) |
| `priv/static/ash_surface_channel_transport.mjs` | untracked | OWNED | wave3-s1d,wave2-js | path named |
| `priv/static/ash_surface_http_transport.mjs` | untracked | OWNED | wave3-s1e,wave3-s3a,wave3-f1or,PARITY-REGISTER,wave2-js | path named |
| `priv/static/ash_surface_runtime.mjs` | modified | OWNED | wave3-s2,L07-safeparse-envelope,L08-runtime-issues,wave3-17,SHIM-COURTS | path named |
| `scripts/chicago_census.txt` | modified | OWNED | lane-20,wave3-f1tr,wave3-19,wave3-04 | path named |
| `scripts/conformance_regen.exs` | modified | OWNED | CONTRACT,lane-20,wave3-s1f,wave3-04,wave3-f1ff | path named |
| `scripts/parity_inventory.exs` | untracked | OWNED | wave3-q1,wave3-f1gh,PARITY-WAVE3-QUEUE | path named |
| `scripts/shim_court/courts/01_zod_type.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/02_union_schema.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/03_zod_guard.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/04_errors.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/05_runtime_transport.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/06_conformance_vector.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/courts/07_parity_gate.sh` | untracked | OWNED | SHIM-COURTS | directory-only evidence (weak) |
| `scripts/shim_court/lib.sh` | untracked | OWNED | SHIM-COURTS,PARITY-WAVE3-QUEUE | path named |
| `scripts/shim_court/run_all.sh` | untracked | OWNED | wave3-q2,SHIM-COURTS | path named |
| `test/aex_spark_dead_surface_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/airo_surface_pin_w675_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_a2a_composition_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_a2a_composition_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_a2a_info_parity_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_a2a_spark_parity_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_a2a_transformer_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_a2a_verifier_court_test.exs` | modified | OWNED | wave3-01 | path named |
| `test/ash_r2rml_composition_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_r2rml_igniter_idempotence_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_r2rml_info_parity_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_r2rml_spark_parity_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_r2rml_transformer_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_r2rml_verifier_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/ash_surface/a2a_bridge_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/adversarial/container_renderers_adversarial_test.exs` | untracked | OWNED | wave3-s2 | path named |
| `test/ash_surface/adversarial/envelope_renderers_adversarial_test.exs` | untracked | OWNED | wave3-s2 | path named |
| `test/ash_surface/adversarial/route_channel_adversarial_test.exs` | untracked | OWNED | wave3-s2b,wave3-ci | path named |
| `test/ash_surface/adversarial/support.exs` | untracked | OWNED | wave3-s2 | path named |
| `test/ash_surface/ash_section_truth_test.exs` | modified | OWNED | wave2-b1a | path named |
| `test/ash_surface/channel_discovery_test.exs` | untracked | OWNED | wave3-s1d | path named |
| `test/ash_surface/codegen_parity/codegen_modules_test.exs` | untracked | OWNED | wave3-g5 | path named |
| `test/ash_surface/codegen_runtime_copy_test.exs` | untracked | OWNED | wave3-03 | path named |
| `test/ash_surface/codegen_task_test.exs` | untracked | OWNED | wave3-t1,wave2-cf,lane-15,wave3-f1m | path named |
| `test/ash_surface/compiler/ash_section_test.exs` | modified | OWNED | L01,L01-constraint-intake | path named |
| `test/ash_surface/compiler/calculation_schema_args_test.exs` | untracked | OWNED | wave3-s1a,wave2-ca | path named |
| `test/ash_surface/compiler/calculation_schema_errors_test.exs` | untracked | OWNED | wave2-ca | path named |
| `test/ash_surface/compiler/calculation_schema_kinds_test.exs` | untracked | OWNED | wave2-ca | path named |
| `test/ash_surface/compiler/calculation_schema_s1a_test.exs` | untracked | OWNED | wave3-s1a | path named |
| `test/ash_surface/compiler/calculation_schema_shorthand_test.exs` | untracked | OWNED | wave3-f1sh | path named |
| `test/ash_surface/compiler/calculation_schema_test.exs` | untracked | OWNED | lane-07,wave2-ca | path named |
| `test/ash_surface/compiler/constraint_validator_test.exs` | untracked | OWNED | wave3-14 | path named |
| `test/ash_surface/compiler/embedded_program_court_test.exs` | untracked | OWNED | wave3-f1rf | path named |
| `test/ash_surface/compiler/embedded_schema_test.exs` | untracked | OWNED | wave3-s1g | path named via brace list |
| `test/ash_surface/compiler/filter_schema_executed_test.exs` | untracked | OWNED | wave2-fl | path named |
| `test/ash_surface/compiler/filter_schema_facts_test.exs` | untracked | OWNED | wave2-fl,wave3-f1dm | path named |
| `test/ash_surface/compiler/filter_schema_size_test.exs` | untracked | OWNED | wave3-f1fs,wave3-tsa10,wave3-s1c | path named |
| `test/ash_surface/compiler/filter_schema_test.exs` | untracked | OWNED | L16,wave2-fl,L01,L02,L09 | path named |
| `test/ash_surface/compiler/identity_schema_test.exs` | untracked | OWNED | wave2-id | path named |
| `test/ash_surface/compiler/ir_wiring_test.exs` | untracked | OWNED | wave3-01,PARITY-REGISTER | path named |
| `test/ash_surface/compiler/number_literal_test.exs` | untracked | OWNED | wave3-f1ff,wave3-f1kd,wave3-f1r | path named |
| `test/ash_surface/compiler/relationship_load_behaviour_test.exs` | untracked | OWNED | wave2-rs | path named |
| `test/ash_surface/compiler/relationship_schema_s1a_test.exs` | untracked | OWNED | wave3-s1a | path named |
| `test/ash_surface/compiler/relationship_selection_schema_test.exs` | untracked | OWNED | wave3-s1a,wave2-rs,lane-06 | path named |
| `test/ash_surface/compiler/s1g_schema_courts_test.exs` | untracked | OWNED | wave3-s1g | path named via brace list |
| `test/ash_surface/compiler/schema_constraint_test.exs` | untracked | OWNED | L16-fragment-courts,L16,wave3-f1ff,L01-constraint-intake,L04 | path named |
| `test/ash_surface/compiler/schema_section_test.exs` | modified | OWNED | wave3-f1tr,wave3-f1en,wave3-t2,L04,lane-01 | path named |
| `test/ash_surface/compiler/section_schema_constraints_test.exs` | untracked | OWNED | wave2-b1a | path named |
| `test/ash_surface/compiler/struct_argument_zod_court_test.exs` | untracked | OWNED | wave3-f1sa | path named |
| `test/ash_surface/compiler/union_schema_test.exs` | untracked | OWNED | wave2-un,wave2-er | path named |
| `test/ash_surface/compiler/zod_type_s3b_test.exs` | untracked | OWNED | wave3-g1,wave3-s3b | path named |
| `test/ash_surface/compiler/zod_type_wave3_test.exs` | untracked | OWNED | wave3-s1f | path named |
| `test/ash_surface/compiler_coverage_test.exs` | modified | OWNED | L02,L02-ir-contract,wave3-01,wave2-b1a | path named |
| `test/ash_surface/compiler_test.exs` | modified | OWNED | L02,L02-ir-contract,wave3-01,wave2-b1a | path named |
| `test/ash_surface/config/consumer_courts_test.exs` | untracked | OWNED | wave3-f1cc | path named |
| `test/ash_surface/config/parity_key_courts_test.exs` | untracked | OWNED | wave3-f1ck | path named |
| `test/ash_surface/config/parity_keys_test.exs` | untracked | OWNED | wave3-f1gh,wave3-g1 | path named |
| `test/ash_surface/config_deep_test.exs` | untracked | OWNED | wave2-cf | path named |
| `test/ash_surface/config_test.exs` | untracked | OWNED | wave2-cf,lane-14 | path named |
| `test/ash_surface/digest_api_test.exs` | untracked | OWNED | wave3-18 | path named |
| `test/ash_surface/divergence_close/aggregate_selection_test.exs` | untracked | OWNED | wave3-f1dc,wave3-f1dm | path named |
| `test/ash_surface/divergence_close/field_naming_divergence_test.exs` | untracked | OWNED | wave3-f1fw | path named |
| `test/ash_surface/divergence_close/filter_divergence_test.exs` | untracked | OWNED | wave3-f1dc,wave3-f1dm | path named |
| `test/ash_surface/divergence_close/filter_functions_test.exs` | untracked | OWNED | wave3-f1dm | path named |
| `test/ash_surface/divergence_close/record_value_divergence_test.exs` | untracked | OWNED | wave3-f1kd | path named |
| `test/ash_surface/divergence_close/time_kind_divergence_test.exs` | untracked | OWNED | wave3-f1kd | path named |
| `test/ash_surface/dsl/route_presentation_parity_test.exs` | untracked | OWNED | wave3-g2b | path named |
| `test/ash_surface/dsl/rpc_surface_parity_test.exs` | untracked | OWNED | wave3-g2 | path named |
| `test/ash_surface/dsl/typed_controller_channel_parity_test.exs` | untracked | OWNED | wave3-g2,wave3-g2b | path named |
| `test/ash_surface/enum_zod_court_test.exs` | untracked | OWNED | wave3-f1en | path named |
| `test/ash_surface/envelope_test.exs` | untracked | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/error_runtime_test.exs` | untracked | OWNED | lane-09 | path named |
| `test/ash_surface/error_schema_deep_test.exs` | untracked | OWNED | wave3-s1g | path named |
| `test/ash_surface/error_schema_test.exs` | untracked | OWNED | lane-08 | path named |
| `test/ash_surface/error_type_parity/error_type_parity_test.exs` | untracked | OWNED | wave3-f1tr,wave3-g6 | path named |
| `test/ash_surface/errors_config_test.exs` | untracked | OWNED | wave3-g2,wave3-12 | path named |
| `test/ash_surface/errors_impl_leaf_test.exs` | untracked | OWNED | wave3-f1m | path named |
| `test/ash_surface/errors_s1b_test.exs` | untracked | OWNED | wave3-s1b | path named |
| `test/ash_surface/errors_test.exs` | untracked | OWNED | PARITY-WAVE2-BACKLOG,wave3-gu8 | path named |
| `test/ash_surface/f1_errcamel_test.exs` | untracked | OWNED | wave3-f1ec | path named |
| `test/ash_surface/f1e_errcfg_test.exs` | untracked | OWNED | wave3-f1e | basename named (weak) |
| `test/ash_surface/field_name_mapping_test.exs` | untracked | OWNED | wave3-f1t,wave3-13 | path named |
| `test/ash_surface/field_name_test.exs` | untracked | OWNED | wave3-13 | path named |
| `test/ash_surface/fixtures/calc_agg_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/harness_ext_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/identity_tenant_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/mapped_names_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/paging_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/relations_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/routes_router_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/fixtures/typed_containers_fixture_test.exs` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/ash_surface/formatter_export_test.exs` | untracked | OWNED | wave2-ds | path named via brace list |
| `test/ash_surface/formatter_registration_canary_test.exs` | modified | OWNED | wave2-ds | path named via brace list |
| `test/ash_surface/health_http_mapping_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/idempotence_court_wave3_test.exs` | untracked | OWNED | wave3-16 | path named |
| `test/ash_surface/inference_deep_test.exs` | untracked | OWNED | wave3-08 | path named |
| `test/ash_surface/inference_test.exs` | untracked | OWNED | lane-18,wave3-08 | path named |
| `test/ash_surface/installer/installer_test.exs` | untracked | OWNED | wave2-cf,lane-16 | path named |
| `test/ash_surface/installer_parity/framework_parity_test.exs` | untracked | OWNED | wave3-g6 | path named via brace list |
| `test/ash_surface/installer_parity/npm_install_task_test.exs` | untracked | OWNED | wave3-g6 | path named via brace list |
| `test/ash_surface/ir_codec_golden_test.exs` | modified | OWNED | L02,wave3-01,wave3-f1sg,wave3-f1cr | path named |
| `test/ash_surface/ir_codec_test.exs` | modified | OWNED | L02,L02-ir-contract,wave3-01 | path named |
| `test/ash_surface/ir_test.exs` | modified | OWNED | lane-20,wave3-01 | path named |
| `test/ash_surface/manifest_type_dispatch_test.exs` | untracked | OWNED | wave3-f1p,wave3-07 | path named |
| `test/ash_surface/metadata_projection_test.exs` | untracked | OWNED | wave3-08 | path named |
| `test/ash_surface/naming_test.exs` | untracked | OWNED | lane-13,wave3-13 | path named |
| `test/ash_surface/no_local_do_bang_court_test.exs` | untracked | OWNED | wave3-tsa11,wave3-gu11,wave3-f1nb,wave3-f1sh | path named |
| `test/ash_surface/no_local_do_test.exs` | modified | OWNED | wave3-s1h,wave3-g2,wave3-s1a,wave3-f1t,wave3-q1 | path named |
| `test/ash_surface/object_mode/object_mode_wiring_test.exs` | untracked | OWNED | wave3-f1om | path named |
| `test/ash_surface/parity/gate_hardening_test.exs` | untracked | OWNED | wave3-f1gh | path named via brace list |
| `test/ash_surface/parity/gate_non_vacuity_test.exs` | untracked | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `test/ash_surface/parity/gate_test.exs` | untracked | OWNED | wave3-f1gh,wave3-q1 | path named via brace list |
| `test/ash_surface/parity/inventory_test.exs` | untracked | OWNED | wave3-q1 | path named via brace list |
| `test/ash_surface/parity_deepen/dsl_runtime_courts_test.exs` | untracked | OWNED | wave3-f1d | path named via brace list |
| `test/ash_surface/parity_deepen/mapped_names_courts_test.exs` | untracked | OWNED | wave3-f1d | path named via brace list |
| `test/ash_surface/parity_deepen/schema_courts_test.exs` | untracked | OWNED | wave3-f1d | path named via brace list |
| `test/ash_surface/parity_deepen/transport_codegen_courts_test.exs` | untracked | OWNED | wave3-f1d | path named via brace list |
| `test/ash_surface/parity_kinds/error_types_test.exs` | untracked | OWNED | wave3-f1k | path named |
| `test/ash_surface/parity_kinds/type_kinds_test.exs` | untracked | OWNED | wave3-f1k | path named |
| `test/ash_surface/parity_tests/gate_non_vacuity_test.exs` | untracked | OWNED | wave3-t0 | path named via brace list |
| `test/ash_surface/parity_tests/skips_test.exs` | untracked | OWNED | wave3-t0 | path named via brace list |
| `test/ash_surface/ported/codegen/action_introspection_newtype_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/aggregate_calculation_support_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/embedded_entrypoint_discovery_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/install_gap_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/install_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/pagination_types_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/codegen/relationship_markers_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/manifest/codegen_type_dispatch_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/decorator_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/manifest_custom_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/manifest_entrypoint_action_decoration_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/manifest_relationship_query_capabilities_gap_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/manifest_relationship_query_capabilities_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/persist_resource_lookups_surface_test.exs` | untracked | OWNED | wave3-t4 | basename named (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_argument_type_field_names_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_composite_type_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_custom_ash_type_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_new_type_return_types_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_new_type_wrapping_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_resource_return_types_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_return_type_field_names_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_struct_types_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_action_types_valid_field_names_surface_test.exs` | untracked | OWNED | wave3-f1un,wave3-t4 | directory-only evidence (weak) |
| `test/ash_surface/ported/manifest/verify_mappable_types_surface_test.exs` | untracked | OWNED | wave3-f1un | path named |
| `test/ash_surface/ported/resource/map_field_names_utility_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/map_field_names_valid_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/persist_formatted_fields_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/typescript_field_names_codegen_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/typescript_field_names_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/verify_field_names_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/verify_map_field_names_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/resource/verify_nested_map_field_names_test.exs` | untracked | OWNED | wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/calculation_field_selection_test.exs` | untracked | OWNED | wave3-t8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/calculations_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/channel_lifecycle_hooks_config_test.exs` | untracked | OWNED | wave3-t8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/codegen_determinism_test.exs` | untracked | OWNED | wave3-t8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/comprehensive_integration_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/custom_type_schema_test.exs` | untracked | OWNED | wave3-gu8-kd06,wave3-f1un | path named |
| `test/ash_surface/ported/rpc/a/embedded_argument_rpc_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/embedded_argument_test.exs` | untracked | OWNED | wave3-gu8-kd06 | path named |
| `test/ash_surface/ported/rpc/a/enable_filter_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/enable_sort_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/entrypoint_resolution_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/error_handling_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/error_protocol_gap_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/error_protocol_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/error_redaction_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/error_scenarios_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/first_aggregate_complex_types_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/forbidden_field_redaction_test.exs` | untracked | OWNED | wave3-t8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/input_field_formatting_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/a/input_parsing_stress_surface_test.exs` | untracked | OWNED | wave3-gu8 | basename named (weak) |
| `test/ash_surface/ported/rpc/b/json_manifest_generator_gap_test.exs` | untracked | OWNED | wave3-cg | basename named (weak) |
| `test/ash_surface/ported/rpc/b/json_manifest_generator_surface_test.exs` | untracked | OWNED | wave3-gu9-kd07 | path named |
| `test/ash_surface/ported/rpc/b/keyword_field_formatting_surface_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/keyword_field_validation_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/lifecycle_hooks_config_test.exs` | untracked | OWNED | wave3-t8 | basename named (weak) |
| `test/ash_surface/ported/rpc/b/load_restrictions_surface_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/load_restrictions_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/manifest_generator_config_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/manifest_generator_gap_test.exs` | untracked | OWNED | wave3-cg | basename named (weak) |
| `test/ash_surface/ported/rpc/b/manifest_generator_surface_test.exs` | untracked | OWNED | wave3-gu9-kd07 | basename named (weak) |
| `test/ash_surface/ported/rpc/b/map_field_name_rpc_surface_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/b/map_field_name_selection_test.exs` | untracked | OWNED | wave3-gu9-kd07,wave3-t9 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/namespace_gap_test.exs` | untracked | OWNED | wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/namespace_manifest_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/namespace_resolution_test.exs` | untracked | OWNED | wave3-tsa10,wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/nested_map_field_formatting_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/nested_query_opts_pipeline_gap_test.exs` | untracked | OWNED | wave3-gu10,wave3-t10 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/nested_query_opts_pipeline_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/nested_query_opts_result_test.exs` | untracked | OWNED | wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/nested_query_opts_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/optional_tenant_for_all_actions_gap_test.exs` | untracked | OWNED | wave3-gu10,wave3-t10 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/optional_tenant_ir_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/optional_tenant_pipeline_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/output_field_formatting_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/pagination_advanced_gap_test.exs` | untracked | OWNED | wave3-gu10,wave3-t10 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/pagination_advanced_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/private_arguments_ir_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/private_arguments_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/restricted_schema_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/result_processor_duration_test.exs` | untracked | OWNED | wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/result_processor_keyword_test.exs` | untracked | OWNED | wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/result_processor_plain_map_test.exs` | untracked | OWNED | wave3-t10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_composite_primary_key_gap_test.exs` | untracked | OWNED | wave3-gu10,wave3-t10 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/rpc_composite_primary_key_ir_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_composite_primary_key_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_field_argument_mapping_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_function_generation_mapped_fields_gap_test.exs` | untracked | OWNED | wave3-gu10,wave3-t10 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/c/rpc_function_generation_mapped_fields_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_get_actions_global_config_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_get_actions_ir_surface_test.exs` | untracked | OWNED | wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/rpc/c/rpc_get_actions_surface_test.exs` | untracked | OWNED | wave3-gu10 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/identity_and_struct_shapes_surface_test.exs` | untracked | OWNED | wave3-tsa11,wave3-f1sa | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_identities_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_input_optionality_test.exs` | untracked | OWNED | wave3-t11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_integration_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_mapped_identity_fields_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_metadata_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_optional_fields_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_pipeline_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_validate_action_read_action_gap_test.exs` | untracked | OWNED | wave3-t11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_validate_action_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/rpc_validation_error_structure_surface_test.exs` | untracked | OWNED | wave3-f1ec | path named |
| `test/ash_surface/ported/rpc/d/run_typed_query_runner_surface_test.exs` | untracked | OWNED | wave3-gutq | path named |
| `test/ash_surface/ported/rpc/d/run_typed_query_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/runtime_source_of_truth_guard_test.exs` | untracked | OWNED | wave3-t11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/sort_and_filter_types_ir_surface_test.exs` | untracked | OWNED | wave3-tsa11,wave3-gutq | basename named (weak) |
| `test/ash_surface/ported/rpc/d/sort_and_filter_types_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/struct_argument_integration_surface_test.exs` | untracked | OWNED | wave3-gu11 | basename named (weak) |
| `test/ash_surface/ported/rpc/d/struct_argument_test.exs` | untracked | OWNED | wave3-gu11,wave3-t11 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/struct_field_filtering_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/support/e.exs` | untracked | OWNED | wave3-gu12,wave3-t12 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/e/support/fixtures.exs` | untracked | OWNED | wave3-gu12,wave3-t12 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/e/top_level_strictness_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/ts_runtime_validation_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/tuple_newtype_input_test.exs` | untracked | OWNED | wave3-gu12,wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/typed_map_embedded_rows_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/typed_query_codegen_gap_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/typed_query_codegen_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/typed_query_field_mapping_cross_domain_gap_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/typed_query_field_mapping_cross_domain_surface_test.exs` | untracked | OWNED | wave3-gu12,wave3-t12 | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/e/valibot_constraints_gap_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/verify_identities_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/verify_metadata_field_names_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/verify_rpc_options_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/verify_rpc_public_actions_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/verify_typed_query_fields_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/working_comprehensive_surface_test.exs` | untracked | OWNED | wave3-gu12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/zod_constraints_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/zod_declaration_order_test.exs` | untracked | OWNED | wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/e/zod_mapped_fields_test.exs` | untracked | OWNED | wave3-f1fw,wave3-t12 | basename named (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_aggregates_test.exs` | untracked | OWNED | wave3-t5 | basename named (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_calculations_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_crud_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_custom_types_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_embedded_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_generic_actions_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_keyword_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_relationships_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_tuple_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_typed_structs_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/rfp/requested_fields_processor_union_types_test.exs` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/ash_surface/ported/rpc/run_action/exotic_type_facts_test.exs` | untracked | OWNED | wave3-t7 | path named |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_aggregates_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_calculations_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_crud_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_embedded_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_field_mapping_gap_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_field_mapping_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_generic_actions_gap_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_generic_actions_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_keyword_gap_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_keyword_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_ltree_gap_test.exs` | untracked | OWNED | wave3-t7 | basename named (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_ltree_surface_test.exs` | untracked | OWNED | wave3-gu7 | basename named (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_relationships_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_sort_filter_gap_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_sort_filter_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_tuple_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_union_calculation_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_union_types_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_untyped_maps_gap_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_untyped_maps_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_user_surface_test.exs` | untracked | OWNED | wave3-f1fw | basename named (weak) |
| `test/ash_surface/ported/rpc/run_action/rpc_run_action_vector_surface_test.exs` | untracked | OWNED | wave3-t7,wave3-f1af,wave3-gu7,wave3-t6b | directory-only evidence (weak) |
| `test/ash_surface/ported/top/aggregate_field_formatting_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/calculation_field_formatting_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/codegen_check_gap_test.exs` | untracked | OWNED | wave3-cf,wave3-t1,wave3-f1un,wave3-gu2,wave3-f1fw | directory-only evidence (weak) |
| `test/ash_surface/ported/top/codegen_check_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/custom_types_test.exs` | untracked | OWNED | wave3-t1,wave3-t5 | basename named (weak) |
| `test/ash_surface/ported/top/embedded_generic_action_return_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/embedded_resource_field_formatting_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/empty_manifest_codegen_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/error_formatter_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/field_formatter_atom_safety_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/field_formatter_struct_clause_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/field_formatting_comprehensive_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/filter_formatting_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/filter_mapped_fields_test.exs` | untracked | OWNED | wave3-t1,wave3-f1fw | basename named (weak) |
| `test/ash_surface/ported/top/formatter_artifact_gap_test.exs` | untracked | OWNED | wave3-cf | path named |
| `test/ash_surface/ported/top/formatter_artifact_test.exs` | untracked | OWNED | wave3-f1fw | path named |
| `test/ash_surface/ported/top/non_field_calculation_test.exs` | untracked | OWNED | wave3-t1,wave3-f1fw | basename named (weak) |
| `test/ash_surface/ported/top/relationship_field_formatting_test.exs` | untracked | OWNED | wave3-t1 | basename named (weak) |
| `test/ash_surface/ported/top/resource_schema_mapped_fields_gap_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/resource_schema_mapped_fields_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/support/t1.exs` | untracked | OWNED | wave3-t1 | path named |
| `test/ash_surface/ported/top/support/t2.exs` | untracked | OWNED | wave3-t1 | directory-only evidence (weak) |
| `test/ash_surface/ported/top/support/ts_action_call_extractor.exs` | untracked | OWNED | wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/ts_action_call_extractor_test.exs` | untracked | OWNED | wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/type_mapping_overrides_test.exs` | untracked | OWNED | wave3-f1un | path named |
| `test/ash_surface/ported/top/typescript_codegen_gap_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_codegen_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_field_names_precedence_gap_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_field_names_precedence_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_filter_gap_test.exs` | untracked | OWNED | wave3-gu2,wave3-f1fw,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_filter_test.exs` | untracked | OWNED | wave3-tsa11,wave3-gu2,wave3-f1fw,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/typescript_sort_test.exs` | untracked | OWNED | wave3-tsa11,wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/union_field_formatting_test.exs` | untracked | OWNED | wave3-gu2,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/union_types_test.exs` | untracked | OWNED | wave3-t5,wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/top/verifier_checker_test.exs` | untracked | OWNED | wave3-t2 | basename named (weak) |
| `test/ash_surface/ported/ts/root/custom_zod_overrides_test.exs` | untracked | OWNED | wave3-t17 | path named |
| `test/ash_surface/ported/ts/root/entry_points_test.exs` | untracked | OWNED | wave3-t17 | path named |
| `test/ash_surface/ported/ts/root/struct_field_selection_test.exs` | untracked | OWNED | wave3-t17,wave3-f1sh | path named |
| `test/ash_surface/ported/ts/should_fail/inference_fail_cases_test.exs` | untracked | OWNED | wave3-t16 | basename named (weak) |
| `test/ash_surface/ported/ts/should_fail/typed_controller_results_fail_test.exs` | untracked | OWNED | wave3-t16b | basename named (weak) |
| `test/ash_surface/ported/ts/should_pass/inference_cases_test.exs` | untracked | OWNED | wave3-t15 | path named |
| `test/ash_surface/ported/ts/should_pass/zod_route_cases_test.exs` | untracked | OWNED | wave3-t15 | path named |
| `test/ash_surface/ported/ts/valibot/valibot_gap_test.exs` | untracked | OWNED | wave3-t17 | path named |
| `test/ash_surface/ported/ts/zod/constraint_validation_fail_test.exs` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ash_surface/ported/ts/zod/constraint_validation_gap_test.exs` | untracked | OWNED | wave3-t16,wave3-t16b | basename named (weak) |
| `test/ash_surface/ported/ts/zod/constraint_validation_pass_test.exs` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ash_surface/ported/ts/zod/custom_type_schemas_test.exs` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ash_surface/ported/ts/zod/support/zod_cases.exs` | untracked | OWNED | wave3-t16 | path named |
| `test/ash_surface/ported/ts/zod/zod_usage_test.exs` | untracked | OWNED | wave3-t16 | basename named (weak) |
| `test/ash_surface/ported/typed_channel/channel_payload_test.exs` | untracked | OWNED | wave3-t13 | basename named (weak) |
| `test/ash_surface/ported/typed_channel/channel_runtime_gap_test.exs` | untracked | OWNED | wave3-t13 | basename named (weak) |
| `test/ash_surface/ported/typed_channel/channel_verify_test.exs` | untracked | OWNED | wave3-t13 | basename named (weak) |
| `test/ash_surface/ported/typed_controller/base_path_test.exs` | untracked | OWNED | wave3-t14b | basename named (weak) |
| `test/ash_surface/ported/typed_controller/codegen_enforcement_test.exs` | untracked | OWNED | wave3-t14b | basename named (weak) |
| `test/ash_surface/ported/typed_controller/codegen_test.exs` | untracked | OWNED | wave3-t14,wave3-t1,wave3-gu2,wave3-t9,wave3-t3 | basename named (weak) |
| `test/ash_surface/ported/typed_controller/fold_argument_constraints_test.exs` | untracked | OWNED | wave3-t14,wave3-ch,wave3-g3b | basename named (weak) |
| `test/ash_surface/ported/typed_controller/namespace_test.exs` | untracked | OWNED | wave3-t14,wave3-tsa10 | basename named (weak) |
| `test/ash_surface/ported/typed_controller/request_handler_gap_test.exs` | untracked | OWNED | wave3-t14,wave3-t14b | basename named (weak) |
| `test/ash_surface/ported/typed_controller/router_introspection_test.exs` | untracked | OWNED | wave3-t14 | basename named (weak) |
| `test/ash_surface/ported/typed_controller/support/tc_support.exs` | untracked | OWNED | wave3-t14 | basename named (weak) |
| `test/ash_surface/ported/typed_controller/verify_typed_controller_test.exs` | untracked | OWNED | wave3-t14b | basename named (weak) |
| `test/ash_surface/projector/expo_client_reconcile_test.exs` | modified | OWNED | wave3-f1g,wave2-js | path named |
| `test/ash_surface/projector/expo_client_test.exs` | modified | OWNED | wave2-js | path named |
| `test/ash_surface/projector/expo_origin_test.exs` | untracked | OWNED | wave3-f1or | basename named (weak) |
| `test/ash_surface/projector/expo_receipts_hash_test.exs` | modified | OWNED | L07,L05-expo-mirror,wave3-10 | path named |
| `test/ash_surface/projector/expo_wave3_s1h_court_test.exs` | untracked | OWNED | wave3-s1h | path named |
| `test/ash_surface/projector/generated_artifacts_exec_test.exs` | modified | OWNED | wave3-s1h,wave3-f1g,L17,L07,wave2-b1a | path named |
| `test/ash_surface/projector_hardening_test.exs` | modified | OWNED | L07 | path named |
| `test/ash_surface/projectors/js/zod_guard_test.exs` | untracked | OWNED | L06-zodguard-courts,L24,L06,wave2-zg,L17 | path named |
| `test/ash_surface/projectors/js/zod_guard_wave3_test.exs` | untracked | OWNED | wave3-s1f | path named |
| `test/ash_surface/projectors/js_declaration_order_test.exs` | untracked | OWNED | wave3-15 | path named |
| `test/ash_surface/projectors/js_embedded_filter_export_test.exs` | untracked | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/projectors/js_mapped_fields_test.exs` | untracked | OWNED | wave3-07,wave3-15 | path named |
| `test/ash_surface/projectors/js_named_refs_test.exs` | untracked | OWNED | wave3-f1rw,wave3-f1m | path named |
| `test/ash_surface/projectors/js_projector_test.exs` | modified | OWNED | L17,L07,wave3-02 | path named |
| `test/ash_surface/projectors/js_safeparse_test.exs` | untracked | OWNED | L17,L07,wave3-02,L17-safeparse-courts | path named |
| `test/ash_surface/projectors/js_schema_wiring_test.exs` | untracked | OWNED | wave3-02 | path named |
| `test/ash_surface/projectors_coverage_test.exs` | modified | OWNED | wave3-f1tr,wave3-f1un,wave3-opd2 | path named |
| `test/ash_surface/query_schema_test.exs` | untracked | OWNED | lane-05,wave2-qs,PARITY-REGISTER | path named |
| `test/ash_surface/query_schema_wave2_test.exs` | untracked | OWNED | wave2-qs,PARITY-REGISTER | path named |
| `test/ash_surface/resource/dsl_options_test.exs` | untracked | OWNED | wave2-ds | path named |
| `test/ash_surface/resource/validator_action_types_test.exs` | untracked | OWNED | wave3-f1p,wave3-07,wave3-t4,wave3-t12,wave3-10 | path named |
| `test/ash_surface/route_introspector_test.exs` | untracked | OWNED | wave3-s1h | path named |
| `test/ash_surface/route_schema_test.exs` | untracked | OWNED | wave3-s1h,wave3-f1rw,wave3-g2b,lane-10 | path named |
| `test/ash_surface/rpc_action_deprecated_test.exs` | untracked | OWNED | wave3-t15 | path named |
| `test/ash_surface/runtime_parity/field_selection_test.exs` | untracked | OWNED | wave3-f1af,wave3-g4 | path named |
| `test/ash_surface/runtime_parity/manifest_dsl_test.exs` | untracked | OWNED | wave3-g4b | path named |
| `test/ash_surface/s1i_identity_selection_fieldname_test.exs` | untracked | OWNED | wave3-s1i,wave3-f1om | path named |
| `test/ash_surface/schema_section_test.exs` | modified | OWNED | wave3-f1tr,wave2-un,wave3-f1en,wave3-f1kd | path named |
| `test/ash_surface/section_channel_test.exs` | untracked | OWNED | lane-11 | path named |
| `test/ash_surface/shim_court_selfcheck_test.exs` | untracked | OWNED | wave3-q2,SHIM-COURTS | path named |
| `test/ash_surface/transformers/fold_argument_constraints_test.exs` | untracked | OWNED | wave3-g3b | path named via brace list |
| `test/ash_surface/transformers/manifest_transformers_test.exs` | untracked | OWNED | wave3-g3b | path named via brace list |
| `test/ash_surface/transport_classify_test.exs` | untracked | OWNED | wave3-18 | path named |
| `test/ash_surface/transport_fallback_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/transport_falsifiers_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface/ts/inference_tsc_test.exs` | untracked | OWNED | wave3-19,wave3-06,wave3-07,TEST-PORT-PLAN | path named |
| `test/ash_surface/ts/ts_compile_test.exs` | untracked | OWNED | lane-19 | path named via brace list |
| `test/ash_surface/ts/zod_codegen_test.exs` | untracked | OWNED | lane-19 | path named via brace list |
| `test/ash_surface/ts/zod_runtime_features_test.exs` | untracked | OWNED | wave3-06 | path named |
| `test/ash_surface/ts/zod_runtime_test.exs` | untracked | OWNED | lane-19 | path named via brace list |
| `test/ash_surface/typed_query_fields_test.exs` | untracked | OWNED | wave3-g2,wave3-f1t,wave3-09 | path named |
| `test/ash_surface/verifiers/g3_verifiers_test.exs` | untracked | OWNED | wave3-f1un,wave3-t12,wave3-g3 | path named |
| `test/ash_surface/vocabulary_issue_twin_test.exs` | untracked | OWNED | wave3-17 | path named |
| `test/ash_surface/zod_guard_grammar_test.exs` | untracked | OWNED | lane-02 | path named |
| `test/ash_surface/zod_guard_regex_test.exs` | untracked | OWNED | wave2-zg | path named |
| `test/ash_surface/zod_type_core_test.exs` | untracked | OWNED | wave2-zt | path named via brace list |
| `test/ash_surface/zod_type_parity_test.exs` | untracked | OWNED | wave2-zt | path named via brace list |
| `test/ash_surface/zod_type_wave2_test.exs` | untracked | OWNED | wave2-zt | path named via brace list |
| `test/ash_surface_composition_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface_igniter_idempotence_court_test.exs` | modified | OWNED | wave3-f1tr,wave2-cf | path named |
| `test/ash_surface_info_parity_court.exs` | modified | OWNED | OPERATOR-DECISIONS,wave3-g4 | path named |
| `test/ash_surface_mock_discipline_test.exs` | modified | OWNED | wave3-t16,wave3-g2,wave3-gu12,wave3-tsa11,wave3-q1 | path named |
| `test/ash_surface_spark_parity_court_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ash_surface_transformer_court_test.exs` | modified | OWNED | wave3-f1tr,wave3-f1un | path named |
| `test/ash_surface_verifier_court_test.exs` | modified | OWNED | wave3-g2,wave2-ds,wave3-f1t,wave3-09,wave3-co | path named |
| `test/audit_trail_composition_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/audit_trail_igniter_idempotence_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/audit_trail_info_parity_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/audit_trail_spark_parity_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/audit_trail_transformer_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/audit_trail_verifier_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/docs_nav_coverage_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/js/adversarial/runtime_zod_adversarial.test.mjs` | untracked | OWNED | wave3-s2 | path named |
| `test/js/channel_transport.test.mjs` | untracked | OWNED | wave3-t16,wave3-t15,wave3-s1d,wave2-js,OPERATOR-DECISIONS | path named |
| `test/js/conformance_replay.test.mjs` | modified | OWNED | wave3-s3a,wave3-04,wave3-t3,L14 | path named |
| `test/js/constraint_validation_agreement.test.mjs` | untracked | OWNED | wave3-14 | path named |
| `test/js/generated_client_reconcile_runner.mjs` | modified | OWNED | wave3-f1g,wave2-js | path named |
| `test/js/generated_js_projector_runner.mjs` | modified | OWNED | L07-safeparse-envelope,L07,L17-safeparse-courts | path named |
| `test/js/generated_js_safeparse_runner.mjs` | untracked | OWNED | L17,L17-safeparse-courts | path named |
| `test/js/generated_schema_wiring_runner.mjs` | untracked | OWNED | wave3-02,wave3-15 | path named |
| `test/js/http_transport.test.mjs` | untracked | OWNED | wave3-s1e,wave3-s3a,wave2-js | path named |
| `test/js/http_transport_h5_m13.test.mjs` | untracked | OWNED | wave3-s1e,wave3-s3a | path named |
| `test/js/http_transport_s3a.test.mjs` | untracked | OWNED | wave3-s3a | path named |
| `test/js/ir_projection.test.mjs` | modified | OWNED | L07-safeparse-envelope,L07 | path named |
| `test/js/ir_projector_deep.test.mjs` | modified | OWNED | L07-safeparse-envelope,L07 | path named |
| `test/js/runtime_issue_vocabulary.test.mjs` | untracked | OWNED | wave3-17 | path named |
| `test/js/transport_phase_classification.test.mjs` | untracked | UNKNOWN | - | no receipt names path/basename |
| `test/js/tstype_runtime_functions.test.mjs` | untracked | OWNED | wave3-g5 | path named |
| `test/js/zod_boundaries.test.mjs` | modified | OWNED | L08 | path named |
| `test/malformed_specimens/typed_query_invalid_fields.ex` | untracked | OWNED | wave3-09 | directory-only evidence (weak) |
| `test/malformed_specimens/typed_query_unknown_action.ex` | untracked | OWNED | wave3-09 | directory-only evidence (weak) |
| `test/malformed_specimens/unknown_action_projection.ex` | untracked | OWNED | wave3-09 | directory-only evidence (weak) |
| `test/notification_extension_composition_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/notification_extension_igniter_idempotence_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/notification_extension_info_parity_court.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/notification_extension_spark_parity_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/notification_extension_transformer_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/notification_extension_verifier_court_test.exs` | modified | OWNED | wave3-f1tr | path named |
| `test/support/channel_fixtures.ex` | untracked | OWNED | wave2-rc,wave2-rs,wave2-zg,wave2-ca,wave2-id | path named |
| `test/support/ported/README.md` | untracked | OWNED | wave3-t5-fixtures-ready | path named |
| `test/support/ported/ash_names.ex` | untracked | UNKNOWN | - | no receipt names path/basename |
| `test/support/ported/domain.ex` | untracked | OWNED | wave3-f1t,wave3-g3,PARITY-REGISTER | basename named (weak) |
| `test/support/ported/resources/article.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/calculations/creator_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/calculations/item_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/calculations/metadata_report_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/calculations/self_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/calculations/summary_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/content.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/task_metadata.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_content/checklist_content.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_content/link_content.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_content/text_content.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_metadata.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_metadata/adjusted_priority_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/todo_metadata/formatted_summary_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/zod_order/node_a.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/zod_order/node_b.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/zod_order/node_c.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/zod_order/node_d.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/embedded/zod_order/node_e.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/empty_resource.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/attachment_file.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/attachment_link.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/data_content_map.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/deep_nested_settings.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/history_entry.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/inner_config.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/input_data_map.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/location_tuple.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/nested_profile.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/nested_settings.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/options.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/preferences_keyword.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/process_profile_result.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/profile.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/resource.ex` | untracked | OWNED | CONTRACT,lane-20,wave3-g2,wave2-ds,wave3-f1t | basename named (weak) |
| `test/support/ported/resources/input_parsing/stats.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/tagged_status.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/input_parsing/text_content.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/map_field_resource.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/nested_array_constraints.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/nested_map_resource.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/no_relationships_resource.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/not_exposed.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/org_comment.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/org_todo.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/post.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/post_comment.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/struct_filter_user.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/subscription.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/task.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/tenant_setting.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | path named |
| `test/support/ported/resources/todo/color_palette.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo/date_calculations.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo/owner_calculation.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo/percentage.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo/priority_score.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo/status.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/todo_comment.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/typed_structs/suggestion.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/typed_structs/task_stats.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/typed_structs/todo_statistics.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/typed_structs/todo_timestamp.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/user.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/resources/user_settings.ex` | untracked | OWNED | wave3-f1tr,wave3-t5,wave3-s2b,wave3-g3b | directory-only evidence (weak) |
| `test/support/ported/rfp.ex` | untracked | OWNED | wave3-t5,TEST-PORT-PLAN | stem/dir-token match (weak) |
| `test/support/ported/rpc.ex` | untracked | OWNED | wave3-t6b,wave3-gu11,RPC-PIPELINE-CORE | path named |
| `test/support/ported/rpc_fixtures.ex` | untracked | OWNED | wave3-t6b,RPC-PIPELINE-CORE | path named |
| `test/support/ported/rpc_validate.ex` | untracked | OWNED | wave3-gu11 | path named |
| `test/support/ported/tsa10.ex` | untracked | OWNED | wave3-tsa10 | path named |
| `test/support/ported/typed_query_fixture.ex` | untracked | OWNED | wave3-gutq | path named |
| `test/support/ported/types/ash_money_money_stub.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/content_item.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/custom_identifier.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/custom_metadata.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/geo_point.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/route_result_summary.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/types/route_settings.ex` | untracked | OWNED | wave3-f1tr,wave3-tsa10,wave3-t5-fixtures-ready,wave3-t5,wave3-t6b | stem/dir-token match (weak) |
| `test/support/ported/verify_action_types_helper.ex` | untracked | OWNED | wave3-t4 | path named |
| `test/support/zod_fixtures.ex` | untracked | OWNED | CONTRACT,wave3-pg,lane-19,wave2-id | path named |
| `test/support/zod_fixtures/calc_agg.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/constraints.ex` | untracked | OWNED | wave2-b1a | path named |
| `test/support/zod_fixtures/harness_ext.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/identity_tenant.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/mapped_names.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/paging.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/relations.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/routes_router.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/support/zod_fixtures/struct_arg.ex` | untracked | OWNED | wave3-f1sa | path named |
| `test/support/zod_fixtures/typed_containers.ex` | untracked | OWNED | wave3-05 | path named via brace list |
| `test/tokyo_depeg_surface_test.exs` | modified | UNKNOWN | - | no receipt names path/basename |
| `test/ts/calculation_schema_runner.mjs` | untracked | OWNED | wave2-ca | path named |
| `test/ts/cases.json` | untracked | OWNED | lane-19 | path named |
| `test/ts/cases/calculations.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/constraints.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/errors_union.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/filters.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/identities.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/relationships_load.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/sort_page.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/cases/unions.json` | untracked | OWNED | wave3-06 | path named via brace list |
| `test/ts/fragment_runner.mjs` | untracked | OWNED | wave3-05 | path named |
| `test/ts/inference/shouldFail/invalidFields.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/invalidSort.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/invalidStructure.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/loadRestrictions.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/noFieldsReadActions.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/typeMismatches.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/unionValidation.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldFail/wrongPaginationTypes.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/calculations.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/compositePrimaryKey.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/conditionalPagination.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/embeddedResources.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/identities.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/inputOptionality.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/keywordTuple.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/loadRestrictions.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/nestedQueryOpts.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/noFields.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/operations.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/relationships.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/sortFields.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/typedMaps.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/typedStructs.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference/shouldPass/unionTypes.ts` | untracked | OWNED | wave3-06 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/argsWithFieldConstraints.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/complexScenarios.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/customTypes.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/firstAggregates.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/genericActionTypedStruct.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/get.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/getBy.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/hoistedSatisfiesFields.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/metadata.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/noArgCalculations.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/noFieldsTypeInference.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/precisePaginationTypes.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/structArguments.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/unionCalculationSyntax.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t15/shouldPass/untypedMaps.ts` | untracked | OWNED | wave3-t15 | directory-only evidence (weak) |
| `test/ts/inference_t16/shouldFail/firstAggregates.ts` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ts/inference_t16/shouldFail/invalidCalcArgs.ts` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ts/inference_t16/shouldFail/nestedQueryOpts.ts` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ts/inference_t16/shouldFail/nonFieldCalculations.ts` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ts/inference_t16/shouldFail/operations.ts` | untracked | OWNED | wave3-t16 | directory-only evidence (weak) |
| `test/ts/inference_t17/shouldPass/structFieldSelection.ts` | untracked | OWNED | wave3-f1sh,wave3-t17 | path named via brace list |
| `test/ts/inference_t17/shouldPass/testStructFieldSelection.ts` | untracked | OWNED | wave3-f1sh,wave3-t17 | path named via brace list |
| `test/ts/kinds_runner.mjs` | untracked | OWNED | wave3-f1k | path named |
| `test/ts/shouldFail/todo_input_misuse.ts` | untracked | OWNED | lane-19 | path named |
| `test/ts/shouldPass/todo_input.ts` | untracked | OWNED | wave3-06,lane-19 | path named |
| `test/ts/zod_runtime_runner.mjs` | untracked | OWNED | lane-19 | path named |
| `test/ts/zod_t16_runner.mjs` | untracked | OWNED | wave3-t16 | path named |
