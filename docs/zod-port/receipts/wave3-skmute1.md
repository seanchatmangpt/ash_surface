# wave3-skmute1

Standing: PARTIAL

Lane SK-mutE1 (read-only skeptic). Scratch `/tmp/ske1` (tar copy `w/`, node_modules+deps
symlinked, `MIX_BUILD_ROOT=/tmp/ske1/_b`). Scope: 57 files in test/ash_surface/ported/rpc/{c,e,
run_action} named in none of skmuta..d (list `/tmp/ske1/files.txt`; all-skip gap files excluded).
Harness `/tmp/ske1/mut.py`, `mut2.py`; raw `/tmp/ske1/out/`. 53 mutations (34 + 19; m12, r20
NOMATCH, unrun); every restore sha256 == baseline, live repo untouched. Each mutation ran all 57
files once; red = failing test absent from that file's isolated baseline.

Baseline: 56 files green; private_arguments_ir_surface_test already-red (2 failures, "private
argument is excluded from validation error schema", `assert error_schema =~ camel(pub)`), so it
cannot show red on those two.

## Red (mutation to file)

- field_formatter mapped-name -> compute: rpc_run_action_{field_mapping,user},
  rpc_function_generation_mapped_fields
- output_formatter key -> internal_key: pagination_advanced, working_comprehensive, restricted_schema
- value_formatter union output unwrapped: union_types, union_calculation, embedded, working_comprehensive
- ResultProcessor: page :count dropped (nested_query_opts_{pipeline,result}, restricted_schema);
  keyset swap (nested_query_opts_result); plain_map string fallback (result_processor_plain_map);
  nested-template drop (struct_field_filtering); extract_resource_field/nested field
  (calculations, relationships, crud, keyword, embedded, generic_actions, typed_map_embedded_rows,
  rpc_get_actions); Date/Atom/Duration/keyword normalization (generic_actions, result_processor_
  {duration,keyword}); typed_map_return (rpc_run_action_tuple, nested_map_field_formatting);
  member_in_template (union_types)
- Pipeline: tenant param (optional_tenant_{ir,pipeline}); missing get_by (rpc_get_actions{,_ir});
  page keys (pagination_advanced); top-level page (top_level_strictness); sort/filter (sort_filter)
- Validator: option/typed_query/admission/identity (verify_* four files); zod_type
  integer/regex/min (zod_constraints, zod_mapped_fields, zod_declaration_order);
  typed_query client_fields (typed_query_codegen_surface); ir tenant (optional_tenant_ir)

## Survived-vacuous (no flip under any mutation tried)

Repair-request section below.

## Repair request (by file)

Mutations that left each file green; add an assertion that fails under it.

- namespace_manifest_surface_test, namespace_resolution_test: not targeted (Domain/namespace
  modules unmutated); needs a namespace-resolution flip (Domain.Info.namespace override).
- output_field_formatting_surface_test, ts_runtime_validation_surface_test,
  rpc_field_argument_mapping_surface_test: survived output_formatter key, field_formatter
  mapping, value_formatter keys-only, result extract mutations.
- private_arguments_ir_surface_test: already-red (2 failures); repair baseline first.
- rpc_composite_primary_key_{ir_surface,surface}_test: survived Pipeline composite-PK guard
  (`length(pk) > 1` -> `> 9`); identity filter unasserted.
- rpc_get_actions_global_config_surface_test: survived tenant/get_by/IR mutations.
- tuple_newtype_input_test: survived ValueFormatter tuple index (`elem(value, 0)`), field_extractor
  tuple -> %{}; asserts nothing on input tuple values.
- typed_query_field_mapping_cross_domain_surface_test, typed_query_codegen_gap_test,
  typed_query_field_mapping_cross_domain_gap_test, valibot_constraints_gap_test: survived
  (gap files mostly @tag skip; the surface file asserts no mapped name).
- exotic_type_facts_test: survived TypeFacts `:items` constraint drop; no TypeFacts flip tried
  beyond it.
- rpc_run_action_aggregates, _ltree, _untyped_maps, _vector surface tests: survived
  value_formatter vector/NotLoaded, result_processor Decimal, extract_resource_field.
- Also survived by every file: ValueFormatter vector/tuple/keyword branches, validator
  duplicate/kind/admission/naming refusals (m19,m20,m23,m25,m26), Pipeline extra-get_by
  (m14), `unconstrained_map_action?` (r09), primitive fallback (r10), scoped sort/filter
  (r11,r12), identity_schema tenant fragments (m30,m31): no file in scope covers them.

UNVERIFIED: files with `[]` above were hit by a small, non-exhaustive mutation set.
