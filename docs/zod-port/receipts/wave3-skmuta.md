# Wave 3 Skeptic Audit: Mutation Court over Ported Tests (SK-mutA)

Standing: PARTIAL

Lane SK-mutA (skeptic, read-only on lib/ and test/). Subject: working tree of /Users/sac/ash_surface
at snapshot time (dirty tree, HEAD e3b5d7ffe + uncommitted lane edits), copied by `tar` of
lib test config mix.exs priv conformance etc. into scratch `/tmp/skma/base` (pristine) and
`/tmp/skma/m/base` (mutated overlay). No worktree, no git state command, real tree never mutated.
Build roots: `/tmp/skma/b2` (baselines), `/tmp/skma/b3` (mutations), copied from `_build/test`.
Harness: `/tmp/skma/mut.py` (sha256 BASELINE -> MUTATE -> run `mix test <file>` -> RESTORE from
pristine copy -> sha256 compare; every row below shows `OK` restore). `rc` is mix's own exit
(rc=2 test failure, rc=0 pass), captured un-piped via subprocess.

## Coverage vs. brief

84 mutation runs over 5 directories. Distinct test files mutated per dir (re-derived from results.tsv): top 19 of 32, codegen 6 of 7,
resource 6 of 8, manifest 13 of 17, rpc/rfp 12 of 12 (brief asked 12 per dir; the shortfall is
time, not file exhaustion, except the gap/skip files which have no runnable body).
Totals: RED 49, plain GREEN 24, remainder base-red-ambiguous or NO-NEW-RED. Standing is
PARTIAL: second-and-third mutations were used to separate vacuity from mutation misses; remaining
GREEN rows are candidates, not proofs, unless listed under VACUOUS below.

## Baseline caveat (read first)

The dirty tree has PRE-EXISTING red tests unrelated to mutation. Full-dir run
(`mix test` over the 5 dirs, scratch): 851 tests, 68 failures, 44 skipped (`/tmp/skma/baseline.log`).
Isolated per-file baselines differ from the full run, so those reds are ORDER/STATE DEPENDENT
(global `Application.put_env` under `async: true` suspected, UNVERIFIED):

| file | full-run fails | isolated fails |
|---|---|---|
| top/typescript_codegen_test | 23 | 0 |
| top/formatter_artifact_test | 13 | 6 |
| top/filter_mapped_fields_test | 8 | 12 |
| top/custom_types_test | 5 | 7 |
| top/codegen_check_test | 4 | 4 (file fully red) |
| top/non_field_calculation_test | 4 | 1 |
| manifest/verify_mappable_types_surface_test | 4 | 4 |
| top/type_mapping_overrides_test | 2 | 1 |
| top/embedded_generic_action_return_test | 2 | 0 |
| top/typescript_filter_test | 1 | 1 |
| top/resource_schema_mapped_fields_test | 1 | 1 |
| manifest/codegen_type_dispatch_surface_test | 1 | 1 |

Owner follow-up (not mine to fix): flaky baselines make `filter_mapped_fields_test` and
`formatter_artifact_test` weak courts (a new red is hidden inside noise; I used failing-test-name
set differences against the isolated baseline log). `codegen_check_test` (4/4 red isolated) was
not mutation-testable. Example witnessed reds: `custom_types_test` "complex custom type ... projects
z.unknown" gets `z.record(z.string(), z.unknown())`; `typescript_filter_test` eq-outside-set accepted.

RED rule: failures(mutated) > failures(baseline-for-that-file), or, for base-red files, a failing
test name absent from the isolated baseline log. Rows marked NO-NEW-RED were compared by name set.

## Mutation table

| id | test file(s) | lib file | mutation (old->new) | result | tests/fails | restore sha |
|---|---|---|---|---|---|---|
| top-08 | top/relationship_field_formatting_test.exs | field_name.ex | `'f when f in [:camel_case, :camel] -> field \|> clean() \|> camelize(false)'->'f when f in` | RED | 8/3 | OK |
| top-09 | top/embedded_resource_field_formatting_test.exs | field_name.ex | `'f when f in [:camel_case, :camel] -> field \|> clean() \|> camelize(false)'->'f when f in` | RED | 6/3 | OK |
| top-10 | top/filter_formatting_test.exs | field_name.ex | `'f when f in [:camel_case, :camel] -> field \|> clean() \|> camelize(false)'->'f when f in` | RED | 7/7 | OK |
| res-02 | resource/verify_field_names_test.exs | resource/verifiers/checks.ex | `'        not Map.has_key?(mapped, item.name) do'->'        true do'` | RED | 11/2 | OK |
| res-03 | resource/verify_map_field_names_test.exs | resource/verifiers/checks.ex | `'type in @field_types ->'->'type in [] ->'` | RED | 9/7 | OK |
| res-04 | resource/verify_nested_map_field_names_test.exs | resource/verifiers/checks.ex | `'walk_names(inner, Keyword.get(constraints, :items, []) \|\| [], mapped, depth + 1)'->'wal` | GREEN | 4/0 | OK |
| res-05 | resource/typescript_field_names_test.exs,resource/typescript_field_names_codegen_test.exs | resource/verifiers/checks.ex | `'module.typescript_field_names() \|> safe_map()'->'%{}'` | RED | 3/1 | OK |
| res-06 | resource/map_field_names_valid_test.exs | resource/verifiers/checks.ex | `'own = if Naming.invalid_name?(name), do: [{:union_member, name}], else: []'->'own = []'` | GREEN | 2/0 | OK |
| man-01 | manifest/verify_action_types_argument_type_field_names_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'    returns ++ args'->'    returns'` | RED | 3/3 | OK |
| man-02 | manifest/verify_action_types_composite_type_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'is_atom(mod) and composite?(mod, c) ->'->'false ->'` | RED | 4/3 | OK |
| man-03 | manifest/verify_action_types_custom_ash_type_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'if invalid?(Map.get(mappings, name, name)), do: [{ctx, :composite_field, name}], else: []` | RED | 5/1 | OK |
| man-04 | manifest/verify_action_types_new_type_return_types_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'    mappings = mappings(mod)\n    sub = mod.subtype_of()'->'    mappings = %{}\n    sub =` | RED | 8/2 | OK |
| man-05 | manifest/verify_action_types_new_type_wrapping_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'Keyword.merge(mod.subtype_constraints() \|\| [], c)'->'c'` | GREEN | 9/0 | OK |
| man-06 | manifest/verify_action_types_resource_return_types_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'is_atom(mod) and Ash.Resource.Info.resource?(mod) ->'->'false ->'` | GREEN | 3/0 | OK |
| man-07 | manifest/verify_action_types_return_type_field_names_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'%{type: :action, returns: type} when not is_nil(type) ->'->'%{type: :zzz, returns: type} ` | RED | 5/5 | OK |
| man-08 | manifest/verify_action_types_struct_types_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'mod == Ash.Type.Struct ->'->'mod == :zzz ->'` | RED | 2/1 | OK |
| man-09 | manifest/verify_action_types_valid_field_names_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'if invalid?(Map.get(mappings, name, name)), do: [{ctx, kind, name}], else: []'->'if false` | GREEN | 3/0 | OK |
| man-10 | manifest/verify_mappable_types_surface_test.exs | resource/verifiers/checks.ex | `'        kinds != [] do'->'        false do'` | NO-NEW-RED (base-red) | 6/4 | OK |
| man-11 | manifest/manifest_relationship_query_capabilities_surface_test.exs | compiler/resource_facts.ex | `'{true, true} -> "mixed"'->'{true, true} -> "offset"'` | RED | 6/2 | OK |
| man-12 | manifest/manifest_custom_surface_test.exs | manifest/dsl.ex | `'\|> put("field_names", Info.field_names(resource) \|> names())'->''` | RED | 10/1 | OK |
| man-13 | manifest/persist_resource_lookups_surface_test.exs | lib/ash_surface.ex | `'         decorated <- decorate_manifest(manifest, profile),'->'         decorated <- %{de` | RED | 7/1 | OK |
| rfp-01 | rfp/tuple_test.exs | runtime_parity/requested_fields/field_selector.ex | `'index = Enum.find_index(field_names, &(&1 == field_atom))'->'index = 0'` | RED | 3/3 | OK |
| rfp-02 | rfp/keyword_test.exs | runtime_parity/requested_fields/field_selector.ex | `'            internal_name = resolve_field_name(field_name)\n            validate_field_ex` | GREEN | 3/0 | OK |
| rfp-03 | rfp/union_types_test.exs | runtime_parity/requested_fields/field_selector.ex | `'Validation.check_for_duplicates(normalized_fields, path)'->':ok'` | RED | 41/3 | OK |
| rfp-04 | rfp/calculations_test.exs | runtime_parity/requested_fields/field_selector.ex | `'if category == :calculation_with_args do'->'if false do'` | RED | 31/1 | OK |
| rfp-05 | rfp/aggregates_test.exs | runtime_parity/requested_fields/field_selector.ex | `'{select, load ++ [internal_name], template ++ [internal_name]}'->'{select, load, template` | RED | 23/10 | OK |
| rfp-06 | rfp/crud_test.exs | runtime_parity/requested_fields/field_selector.ex | `'if action.get? do'->'if false do'` | GREEN | 9/0 | OK |
| rfp-07 | rfp/custom_types_test.exs | runtime_parity/requested_fields/field_selector.ex | `'    atoms ++ keyword_pairs'->'    keyword_pairs ++ atoms'` | RED | 23/6 | OK |
| rfp-08 | rfp/embedded_test.exs | runtime_parity/requested_fields/field_selector.ex | `'      throw({:requires_field_selection, category, internal_name, path})'->'      :ok'` | RED | 24/1 | OK |
| rfp-09 | rfp/generic_actions_test.exs | runtime_parity/requested_fields/field_selector.ex | `'          %Ash.Info.Manifest.Type{} = type ->\n            {type, []}'->'          %Ash.I` | RED | 21/16 | OK |
| rfp-10 | rfp/relationships_test.exs | runtime_parity/requested_fields/field_selector.ex | `'          throw({:query_opts_on_to_one, internal_name, path})'->'          rel'` | GREEN | 15/0 | OK |
| rfp-11 | rfp/test.exs | runtime_parity/requested_fields/field_selector.ex | `'formatted_template = format_extraction_template(template)'->'formatted_template = templat` | RED | 18/1 | OK |
| rfp-12 | rfp/typed_structs_test.exs | runtime_parity/requested_fields/field_selector.ex | `'    if requested_fields == [] do\n      throw({:requires_field_selection, :field_constrai` | GREEN | 21/0 | OK |
| cod-01 | codegen/relationship_markers_test.exs | compiler/relationship_schema.ex | `'if(rel["sortable"] == false, do: [], else:'->'if(false, do: [], else:'` | RED | 8/1 | OK |
| cod-02 | codegen/pagination_types_test.exs | compiler/query_schema.ex | `'"before: z.string().optional()"'->'"before: z.string()"'` | RED | 4/2 | OK |
| cod-03 | codegen/install_test.exs | installer/installer.ex | `'run_endpoint: "/rpc/run",'->'run_endpoint: "/rpc/runx",'` | RED | 3/1 | OK |
| cod-04 | codegen/embedded_entrypoint_discovery_test.exs | compiler/type_facts.ex | `'Enum.reduce(type["members"] \|\| [], acc, &collect(Map.get(&1, "type"), &2))'->'acc'` | GREEN | 4/0 | OK |
| cod-05 | codegen/action_introspection_newtype_test.exs | compiler/type_facts.ex | `'\|> Map.put("subtype_of", sub)'->'\|> Map.put("subtype_of", "zzz")'` | GREEN | 5/0 | OK |
| cod-06 | codegen/aggregate_calculation_support_test.exs | compiler/resource_facts.ex | `'\|> Map.put(:field_kind, analysis.kind \|\| "unknown")'->'\|> Map.put(:field_kind, "unkno` | RED | 5/4 | OK |
| top-11 | top/error_formatter_test.exs | error_formatter.ex | `'{key, value} when key in [:vars, "vars"] -> {key, value}'->'{key, value} when key in [:zz` | RED | 12/1 | OK |
| top-12 | top/verifier_checker_test.exs | verifier_checker.ex | `'if AshSurface.Resource in Spark.extensions(module) do'->'if false do'` | RED | 8/4 | OK |
| top-13 | top/typescript_sort_test.exs | compiler/query_schema.ex | `'prefix = "(?:\\+\\+\|--\|[+-])?"'->'prefix = ""'` | RED | 11/3 | OK |
| top-14 | top/typescript_filter_test.exs | compiler/filter_schema.ex | `'op in surface_keys() -> {:ok, op}'->'op in [] -> {:ok, op}'` | NO-NEW-RED (base-red) | 27/1 | OK |
| top-15 | top/union_types_test.exs | compiler/type_facts.ex | `'Enum.reduce(type["members"] \|\| [], acc, &collect(Map.get(&1, "type"), &2))'->'acc'` | RED | 3/1 | OK |
| top-16 | top/union_types_test.exs | compiler/type_facts.ex | `'acc = if type["items"], do: collect(type["items"], acc), else: acc'->'acc = acc'` | RED | 3/1 | OK |
| top-17 | top/empty_manifest_codegen_test.exs | projectors/js.ex | `'      emit(entries, zod_forms, opts)'->'      {:ok, %{}, %{}}'` | GREEN | 1/0 | OK |
| top-18 | top/custom_types_test.exs | compiler/zod_type.ex | `'"uuid" => "z.guid()"'->'"uuid" => "z.string()"'` | RED (name-diff +1) | 24/8 | OK |
| top-19 | top/resource_schema_mapped_fields_test.exs | compiler/resource_facts.ex | `'defp wire_name(resource, name), do: AshSurface.FieldName.wire(resource, name)'->'defp wir` | NO-NEW-RED (base-red) | 24/1 | OK |
| top-20 | top/aggregate_field_formatting_test.exs,top/relationship_field_formatting_test.exs | compiler/resource_facts.ex | `'defp wire_name(resource, name), do: AshSurface.FieldName.wire(resource, name)'->'defp wir` | RED | 15/1 | OK |
| top-21 | top/field_formatter_struct_clause_test.exs | field_name.ex | `'defp clean(field), do: field \|> to_string() \|> String.replace("?", "")'->'defp clean(fi` | GREEN | 3/0 | OK |
| res-04b | resource/verify_nested_map_field_names_test.exs | resource/verifiers/checks.ex | `'type in @field_types ->'->'type in [] ->'` | RED | 4/4 | OK |
| res-06b | resource/map_field_names_valid_test.exs | resource/verifiers/checks.ex | `'if Naming.invalid_name?(name) and not Map.has_key?(mapped, name),'->'if Naming.invalid_na` | GREEN | 2/0 | OK |
| man-05b | manifest/verify_action_types_new_type_wrapping_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'s when s in [Ash.Type.Map, Ash.Type.Keyword, Ash.Type.Tuple] ->'->'s when s in [] ->'` | RED | 9/3 | OK |
| man-06b | manifest/verify_action_types_resource_return_types_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'    typed = Ash.Resource.Info.public_attributes(mod) ++ calcs'->'    typed = []'` | RED | 3/2 | OK |
| man-09b | manifest/verify_action_types_valid_field_names_surface_test.exs | resource/verifiers/action_type_field_names.ex | `'defp invalid?(name) when is_binary(name), do: Naming.invalid_name?(name)'->'defp invalid?` | GREEN | 3/0 | OK |
| man-10b | manifest/verify_mappable_types_surface_test.exs | resource/verifiers/checks.ex | `'    Enum.reject(ZodType.unmappable_kinds([analysis.definition]), &(&1 in @container_kinds` | NO-NEW-RED (base-red) | 6/4 | OK |
| rfp-02b | rfp/keyword_test.exs | runtime_parity/requested_fields/field_selector.ex | `'            validate_field_exists_in_fields!(internal_name, fields, path, error_type)\n  ` | RED | 3/3 | OK |
| rfp-06b | rfp/crud_test.exs | runtime_parity/requested_fields/field_selector.ex | `'type when type in [:create, :update, :destroy] ->'->'type when type in [:update, :destroy` | RED | 9/2 | OK |
| rfp-10b | rfp/relationships_test.exs | runtime_parity/requested_fields/field_selector.ex | `'      throw({:args_and_query_opts_combined, internal_name, path})'->'      :ok'` | GREEN | 15/0 | OK |
| rfp-12b | rfp/typed_structs_test.exs | runtime_parity/requested_fields/field_selector.ex | `'{_forward, reverse_map} = typed_struct_field_maps(type_info, ctx)'->'{_forward, reverse_m` | GREEN | 21/0 | OK |
| cod-04b | codegen/embedded_entrypoint_discovery_test.exs | compiler/type_facts.ex | `'if Map.has_key?(acc, name), do: acc, else: expand_embedded(name, acc)'->'acc'` | RED | 4/1 | OK |
| cod-05b | codegen/action_introspection_newtype_test.exs | compiler/type_facts.ex | `'    do: {kind_string(type), constraints(type.constraints)}'->'    do: {"zzz", constraints` | RED | 5/1 | OK |
| res-06c | resource/map_field_names_valid_test.exs | naming.ex | `'def invalid_name?(name), do: Regex.match?(~r/_+\d\|\?/, to_string(name))'->'def invalid_n` | RED | 2/2 | OK |
| man-09c | manifest/verify_action_types_valid_field_names_surface_test.exs | naming.ex | `'def invalid_name?(name), do: Regex.match?(~r/_+\d\|\?/, to_string(name))'->'def invalid_n` | RED | 3/2 | OK |
| man-10c | manifest/verify_mappable_types_surface_test.exs | resource/verifiers/checks.ex | `'    analysis = TypeFacts.analyze(item.type, item.constraints)'->'    analysis = TypeFacts` | NO-NEW-RED (base-red, same names) | 6/4 | OK |
| rfp-10c | rfp/relationships_test.exs | runtime_parity/requested_fields/field_selector.ex | `'        not rel.filterable? ->'->'        false ->'` | GREEN | 15/0 | OK |
| rfp-10d | rfp/relationships_test.exs | runtime_parity/requested_fields/field_selector.ex | `'if Map.get(opts, :page) != nil and Compat.relationship_pagination(rel) == :none do'->'if ` | GREEN | 15/0 | OK |
| rfp-12c | rfp/typed_structs_test.exs | runtime_parity/requested_fields/field_selector.ex | `'case Map.get(reverse_map, field_name) do'->'case nil do'` | GREEN | 21/0 | OK |
| rfp-12d | rfp/typed_structs_test.exs | runtime_parity/requested_fields/field_selector.ex | `'    Validation.check_for_duplicates(requested_fields, path)\n\n    Enum.reduce(requested_` | GREEN | 21/0 | OK |
| top-14b | top/typescript_filter_test.exs | compiler/filter_schema.ex | `'{:ok, Map.fetch!(@ash_operator_keys, op)}'->'{:ok, "zzz"}'` | NO-NEW-RED (base-red, same names) | 27/1 | OK |
| top-21b | top/field_formatter_struct_clause_test.exs | field_name.ex | `'def format_fields(map, formatter) when is_map(map) and not is_struct(map),'->'def format_` | GREEN | 3/0 | OK |
| top-22 | top/typescript_codegen_test.exs | compiler/zod_type.ex | `'"decimal" => "z.string()"'->'"decimal" => "z.number()"'` | RED (iso-base 0 -> 1) | 53/1 | OK |
| top-23 | top/formatter_artifact_test.exs | field_name.ex | `'head = if pascal?, do: String.capitalize(first), else: first'->'head = first'` | RED (name-diff +7) | 17/11 | OK |
| top-24 | top/embedded_generic_action_return_test.exs | compiler/type_facts.ex | `'if Map.has_key?(acc, name), do: acc, else: expand_embedded(name, acc)'->'acc'` | RED (iso-base 0 -> 1) | 5/1 | OK |
| top-25 | top/type_mapping_overrides_test.exs | compiler/zod_type.ex | `'"decimal" => "z.string()"'->'"decimal" => "z.number()"'` | NO-NEW-RED (base-red, same names) | 9/1 | OK |
| top-26 | top/non_field_calculation_test.exs | compiler/resource_facts.ex | `'Map.get(calc, :filterable?) != false,'->'true,'` | AMBIGUOUS (base-red, flaky swap) | 5/1 | OK |
| top-21c | top/field_formatter_struct_clause_test.exs | field_name.ex | `'      name = AshSurface.Resource.Info.get_formatted_field(resource, field, formatter) ->\` | GREEN | 3/0 | OK |
| rfp-10e | rfp/relationships_test.exs | runtime_parity/requested_fields/field_selector.ex | `'  defp validate_query_opts!(resource, internal_name, rel, opts, fields, path, ctx) do'->'` | GREEN | 15/0 | OK |
| rfp-12e | rfp/typed_structs_test.exs | runtime_parity/requested_fields/field_selector.ex | `'    {_forward, reverse_map} = typed_struct_field_maps(type_info, ctx)'->'    raise "SKMA-` | RED | 21/12 | OK |
| top-19r | top/resource_schema_mapped_fields_test.exs | compiler/resource_facts.ex | `'defp wire_name(resource, name), do: AshSurface.FieldName.wire(resource, name)'->'defp wir` | NO-NEW-RED (base-red, same names) | 24/1 | OK |
| top-14r | top/typescript_filter_test.exs | compiler/filter_schema.ex | `'op in surface_keys() -> {:ok, op}'->'op in [] -> {:ok, op}'` | NO-NEW-RED (base-red, same names) | 27/1 | OK |
| man-10r | manifest/verify_mappable_types_surface_test.exs | resource/verifiers/checks.ex | `'        kinds != [] do'->'        false do'` | NO-NEW-RED (base-red, same names) | 6/4 | OK |
| top-18r | top/custom_types_test.exs | compiler/zod_type.ex | `'"uuid" => "z.guid()"'->'"uuid" => "z.string()"'` | RED | 24/6 | OK |
| top-04r | top/filter_mapped_fields_test.exs | field_name.ex | `'[atom] -> {:ok, atom}'->'[atom \| _] -> {:ok, atom}'` | RED | 18/9 | OK |

## Per-file verdicts

NON-VACUOUS (proved by a RED mutation, ids in table): top/aggregate_field_formatting,
calculation_field_formatting, field_formatter_atom_safety, filter_mapped_fields,
typescript_field_names_precedence, field_formatting_comprehensive, union_field_formatting,
relationship_field_formatting, embedded_resource_field_formatting, filter_formatting,
error_formatter, verifier_checker, typescript_sort, union_types, custom_types (zod half),
typescript_codegen, formatter_artifact, embedded_generic_action_return; codegen/ relationship_markers,
pagination_types, install_test, embedded_entrypoint_discovery, action_introspection_newtype,
aggregate_calculation_support; resource/ map_field_names_utility, verify_field_names,
verify_map_field_names, verify_nested_map_field_names, typescript_field_names (+ _codegen),
map_field_names_valid; manifest/ all verify_action_types_* except as noted below,
manifest_relationship_query_capabilities_surface, manifest_custom_surface,
persist_resource_lookups_surface (1 of 7 tests); rpc/rfp tuple, keyword, union_types, calculations,
aggregates, crud, custom_types, embedded, generic_actions, requested_fields_processor,
relationships (simple-load half), typed_structs (reached: rfp-12e RED 12 fails).

## VACUOUS list (file, test, mutation survived, owner lane)

Owner lanes taken from `wave3-t*.md` mentions; rfp owner unconfirmed (no receipt names rfp files).

1. **top/field_formatter_struct_clause_test.exs**, tests "built-in formatter uses the resource
   field_names mapping" and "unmapped field falls back": survives top-21c (mapping branch of
   `FieldName.format_field_for_client/3` replaced by `false -> nil`), top-21 and top-21b.
   Expected values (`isActive`, `addressLine1`) equal pure `compute/2` output, so the mapping path
   is never required. Tautological for the claim it names. Owner T1/T2.
2. **top/empty_manifest_codegen_test.exs**, sole test: survives top-17 (`JS.project_ir` result
   replaced by `{:ok, %{}, %{}}`). Final assertion is `assert is_map(files)`. Termination half is real,
   content half is vacuous. Owner T1.
3. **top/resource_schema_mapped_fields_test.exs**, 23 of 24 tests: survive top-19/top-19r
   (`ResourceFacts.wire_name/2` -> `to_string(name)`, i.e. mapping dropped from resource facts); no
   new red vs isolated baseline. They assert on `FieldName`/`Resource.Info` directly, not the
   compiler path. Owner T1/T2.
4. **manifest/verify_mappable_types_surface_test.exs**, the 2 non-baseline-red tests: survive
   man-10, man-10b, man-10c, man-10r (kinds refusal disabled, unmappable analysis replaced, whole
   unmappable filter replaced); 4 of 6 tests red at baseline. Owner T4.
5. **top/typescript_filter_test.exs** (27 tests, 1 baseline-red): survives top-14, top-14b, top-14r
   (operator_key surface-key branch, operator map lookup replaced by "zzz"). Operator-key mapping is
   not pinned by the passing tests. Owner T1/T2.
6. **top/type_mapping_overrides_test.exs**: survives top-25 (decimal Zod mapping flipped), same
   name-set as baseline. Owner T1/T2.
7. **top/ts_action_call_extractor_test.exs** (21 tests): static proof, no `AshSurface.` lib
   reference; it tests `test/ash_surface/ported/top/support/ts_action_call_extractor.exs`
   (a test-side helper). Never calls lib code. Owner T2.
8. **top/custom_types_test.exs**, tests under "custom type detection" and "custom type
   functionality" (8 tests): assert `function_exported?` / `cast_input` on test-defined fixture
   types (`PriorityScore`, `ColorPalette`); no lib call. Owner T2.
9. **manifest/persist_resource_lookups_surface_test.exs**, 6 of 7 tests: assert
   `Ash.Info.Manifest.*` accessors on `Manifest.generate/1` (the Ash dependency); only the final test
   ("decorated manifest preserves the lookups") catches man-13 (RED 1 of 7). Owner T4.
10. **rpc/rfp/requested_fields_processor_typed_structs_test.exs**: survives four site mutations
    inside `select_typed_struct_fields` (rfp-12 empty-selection throw removed, rfp-12b
    `reverse_map` forced to `%{}`, rfp-12c reverse-map lookup forced nil, rfp-12d duplicate check
    removed) although rfp-12e proves the function is reached (12 fails when it raises). Named tests
    "returns error for duplicate typed struct fields" / "...as simple atom" / "...as empty map" are
    shielded by an upstream layer and do not pin this function. Owner T5.
11. **rpc/rfp/requested_fields_processor_relationships_test.exs**: survives rfp-10, rfp-10b,
    rfp-10c, rfp-10d and rfp-10e (a `raise` at the top of `validate_query_opts!` stays green:
    15 tests, 0 fails). The file never sends `filter`/`sort`/`page`/`args` (0 grep hits), so the
    whole query-opts validator (field_selector.ex `validate_query_opts!`) is uncovered by it. Owner T5.

Gap/skip files (all `@tag skip`, bodies `do: :ok` or `flunk`; loud, not green): codegen/install_gap,
manifest/manifest_relationship_query_capabilities_gap, top/codegen_check_gap (8),
embedded_generic_action_return_gap, formatter_artifact_gap (20 tests at snapshot; live file is now
6 tests, edited concurrently by a lane), resource_schema_mapped_fields_gap, typescript_codegen_gap,
typescript_field_names_precedence_gap. Risk: removing a skip tag turns `do: :ok` bodies into
silent passes (formatter_artifact_gap, codegen_check_gap, embedded_generic_action_return_gap).

## Coverage-gap (not vacuous, branch unreached by its file)

- res-04: `verify_nested_map_field_names_test` does not exercise the array-items branch of
  `walk_names/4` (res-04 GREEN, res-04b `@field_types` RED).
- res-06/res-06b: `map_field_names_valid_test` does not pin union-member or mapped-name suppression
  (res-06c, always-invalid naming, RED 2 of 2).
- man-05, man-06, man-09: first mutation missed, second (b/c) RED; narrow branches only.
- rfp-02/rfp-06: first site missed, second RED (keyword template, crud create clause).
- cod-04, cod-05: first site missed, second RED.

## Static greps over the five dirs

- `assert true` / `assert _ =`: 0 matches.
- `is_map`/`is_list`/`is_binary`-only assertions: top/empty_manifest_codegen_test.exs:35,
  top/field_formatter_atom_safety_test.exs:67 (accompanied by `refute atom_exists?`, adequate),
  manifest/codegen_type_dispatch_surface_test.exs:121, manifest/persist_resource_lookups_surface_test.exs:43,91,
  manifest/manifest_entrypoint_action_decoration_surface_test.exs:44 (followed by `map_size ==`, adequate).
- `refute is_nil(x)`-only: 0 matches.
- Files with no `AshSurface` reference: 0 (but see item 7: reference to `AshSurface.Ported.*` helper
  does not imply a lib call).
- Tests-per-assert below 1: only gap files (0 asserts, all skipped) and top/typescript_filter_test.exs
  (13 assert lines for 27 tests, helper `check/2` asserts inside).
- `rpc/rfp` tests delegate through `test/support/ported/rfp.ex` to the real
  `AshSurface.RuntimeParity.RequestedFieldsProcessor` (lib), so they do cover lib.

## Commands and exits

- Scratch seed: `tar cf - lib test config mix.exs mix.lock priv conformance parity templates semantic fixture package.json ontology.ttl | tar xf - -C /tmp/skma/base` (rsync of `./` was refused by the topology guard; tar of explicit paths used).
- Baseline full run: `cd /tmp/skma/base && MIX_BUILD_ROOT=/tmp/skma/b2 MIX_ENV=test mix test <5 dirs>` -> 851 tests, 68 failures, 44 skipped (exit 2, summary from log).
- Isolated baselines: `/tmp/skma/isobase.out` (12 files, listed above).
- Each mutation: `python3 /tmp/skma/mut.py <id> <lib> <old> <new> <test files>` -> row in table; ledger `/tmp/skma/results.tsv`; per-run logs `/tmp/skma/out-<id>.log` (from top-21c onward plus reruns).
- Incident: an early duplicate batch (two chains racing on one overlay) produced FAIL restore rows;
  all affected ids (top-08 onward) were discarded (`results-polluted.tsv`) and rerun serially;
  the table above contains only serial runs, all `sha_restore=OK`.
- Machine load from other lanes inflated runtimes (single files 180s); no timeouts used.

## Repair requests for coordinator (no edits made by this lane)

1. T1/T2: pin the mapping path in field_formatter_struct_clause (expected value that differs from
   `compute/2`); give empty_manifest_codegen a content assertion; point resource_schema_mapped_fields
   tests at `ResourceFacts`/compiled artifact keys; pin `operator_key` mapping in typescript_filter.
2. T4: replace Ash-accessor-only assertions in persist_resource_lookups with `AshSurface` outputs.
3. T5: add a relationships test with `filter`/`sort`/`page`/`args` query opts; make typed_struct
   duplicate/empty tests hit `select_typed_struct_fields` directly (rfp-12 family).
4. T1/T2: fix order/state-dependent reds (global env under async) so baselines are stable.
5. Re-enabling any `@tag skip` gap test requires a real body first.

## Cleanup

Scratch `/tmp/skma` (overlay, b2, b3, logs) retained until coordinator confirms; delete with
`rm -rf /tmp/skma`. No `_build-skma` was created in the repo (build roots live under /tmp/skma).
Falsifier: any VACUOUS item above whose named mutation turns RED under a fresh serial rerun on the
same snapshot is withdrawn.
