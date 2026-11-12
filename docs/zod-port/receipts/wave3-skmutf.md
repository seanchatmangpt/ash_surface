# Wave 3 Skeptic SK-mutF

Standing: PARTIAL

Adversarial mutation skeptic over repair lanes RAE, RAF, RAK. Canonical repo untouched. Scratch
`/tmp/skmf` (explicit-path tar, deps and node_modules symlinked, build root `/tmp/skmf/_b` seeded
by copying `_build/test`). Harness `/tmp/skmf/_h/mut.py`, output `/tmp/skmf/mut.out`. Baseline
69/0 green before mutating. Every row: sha256 baseline == restore (`restore_eq True` x all);
`diff -rq lib` scratch vs live = equal after refreshing `typed_query.ex` (a live lane changed it
after the tar; T-rows re-run on the refreshed file). rc captured un-piped inside the harness
(rc=0 => survives). All mutations are new (none appear in the RAE/RAF/RAK tables).

## Results (tests/failures under mutation; S = survives, K = killed)

| id | file : mutation | test file | res |
|---|---|---|---|
| J1 | action_manifest `see` -> [] | json_manifest_generator_surface | K |
| J2 | action_manifest enable_sort default -> true | same | K |
| J3 | action_manifest namespaces sort dropped | same | S |
| J4 | config zod_import_into_generated default true | manifest_generator_config | S |
| J5 | config zod_import_path default "zodx" | same | S |
| J6 | config show_raised_errors default true | same | S |
| J7 | action_manifest deprecated -> false | json_manifest | K |
| C1 | field_selector tag calculation_requires_args renamed | calculation_field_selection | S |
| C2 | field_selector calc_requires_args branch off | same | S |
| C3 | field_selector no-args-non-complex branch off | same | S |
| C4 | field_selector non-empty-args-on-no-arg-calc off | same | S |
| C5 | field_selector complex_type requires_field_selection -> empty | same | K |
| C6 | field_selector accepts_args && args==nil off | same | S |
| F1 | fold string_default_kinds drops ci_string | fold_argument_constraints | S |
| F2 | fold forbidden return kinds drops union | same | K |
| F3 | fold first_forbidden drops def_map item_type | same | S |
| F4 | fold invalid_argument_type kind literal | same | K |
| F5 | fold invalid_argument_constraints key literal | same | K |
| F6 | fold item constraints not default-folded | same | K |
| T1 | typed_query rpc_entry sort :desc | run_typed_query_surface | S |
| T2 | typed_query action = entry.action | same | K |
| T3 | typed_query action_not_found carries nil | same | S |
| T4 | typed_query fields truncated to 1 | same | S |
| T5 | typed_query client_fields resource arg dropped (nil) | same | S |
| E1 | errors Policy short_message | error_redaction_surface | S |
| E2 | errors exposed short_message "X" | same | S |
| E3 | errors tenant_required type string | same | S |
| E4 | errors Changes.Required short_message | same | S |
| E5 | errors show_raised_errors default true | same | S (likely equivalent: with_config_defaults fills it first) |
| E6 | errors ReadActionRequiresActor short_message | same | S |
| S1 | type_facts resource kind resource? false | struct_argument | K |
| S2 | type_facts embedded resource? false | same | S |
| S3 | type_facts expand_embedded flag true | same | S |
| S4 | type_facts struct/map field_names dropped | same | S |
| S5 | input_formatter field type lookup nil | same | S |
| S6 | type_facts resource kind instance_of literal | same | K |
| Z1 | zod_type min with allow_empty false uses explicit\|\|1 | entry_points + custom_zod | S |
| Z2 | zod_type regex flags dropped | same | S |
| Z3 | zod_type override precedence inverted | same | S |
| Z4 | zod_type term -> z.unknown() | same | S |
| Z5 | zod_type file -> z.unknown() | same | S |
| Z6 | zod_type integer length bound +1 | same | K |
| Z7 | zod_type function -> z.string() | same | S |
| VF1 | value_formatter vector to_list -> [] | value_formatter_branches | K |
| VF2 | value_formatter keyword Enum.reverse | same | S |
| VF3 | value_formatter format_tuple map branch bypass | same | K |
| VF4 | value_formatter format_keyword map branch bypass | same | K |
| V1 | validator duplicate refusals unsorted | validator_refusals | K |
| V2 | validator offline classes drop queue_reconcile | same | K |
| V3 | validator admission sort :desc | same | S |
| V4 | validator offline refusal code renamed | same | K |
| V5 | validator admission detail drops reason | same | K |
| V6 | validator admits :ws transport | same | K |
| P1 | pipeline unexpected_get_by names unformatted | pipeline_scoped_get_by | K |
| P2 | pipeline missing_get_by names unformatted | same | K |
| P3 | pipeline allowed list unformatted | same | K |
| P4 | pipeline no-op line (equivalent, ignore) | same | S |
| I1 | identity_schema tenant min(2) | same | K |
| I2 | identity_schema tenant .nullable() not .optional() | same | K |
| I3 | identity_schema non_scalar_kinds drops keyword | same | S |

Tally (excluding P4 and E5 equivalents): 58 mutations, 22 killed, 34 survive. RAK-lane files
(value_formatter, validator, pipeline) are strong; RAE/RAF files carry the surviving breadth.

## RAK survivor (recorded, re-confirmed)

field_formatter `mapped when is_binary(mapped) -> mapped` replaced by
`FieldName.compute(field, formatter)`: `mix test rpc/rak rpc/e` = 301 tests, 0 failures (survives).
Cause: fixture computed spelling == mapped spelling. Related T5 (typed_query drops the
resource arg to `client_fields/2`) also survives `run_typed_query_surface_test.exs`.

## runtime_source_of_truth_ast_guard_test.exs probes (executed via the test's own `violations/2`)

| form | result |
|---|---|
| `import AshSurface.Info` then local `entries(r)` | MISSED |
| `import Ash` then local `read!(q)` | MISSED |
| `apply(AshSurface.Info, :f, [..])`, `Kernel.apply/3`, `apply(Ash, :read!, [..])` | MISSED |
| `@m AshSurface.Info` then `@m.entries()` | MISSED |
| `a \|> Map.get(:show_metadata)` (pipe, 2 args) | MISSED (pattern needs key at arg 2) |
| `Map.fetch/2`, `a[:key]`, `alias Map, as: M; M.get`, `a.denied_loads` | MISSED |
| `Ash.stream!`, `Ash.run_action`, `Ash.load!` | MISSED (not in @actuating) |
| `Module.concat([..]).x()` | MISSED |
| `alias __MODULE__.Info` | CRASH FunctionClauseError (loud, not a silent miss) |
| `__MODULE__.x()` inside the forbidden module | MISSED (inapplicable to guarded files) |
| multi-alias with `as:`, aliased Ash (`alias Ash, as: A`), capture `&Mod.f/1`, nested pipe `Ash.create!` | caught |
| same-last-segment alias in separate scopes | over-flags (alias map is file-global) |

Live tree currently contains none of the missed forms (grep over runtime_parity: no import,
apply, Ash.stream/run_action/load/calculate/bulk call).

## Repair requests

1. `test/ash_surface/ported/rpc/b/manifest_generator_config_test.exs`: survivors J4 (zod_import_into_generated default), J5 (zod_import_path default), J6 (show_raised_errors default). Assert defaults.
2. `test/ash_surface/ported/rpc/b/json_manifest_generator_surface_test.exs`: survivor J3 (namespaces unsorted; needs >=2 out-of-order namespaces).
3. `test/ash_surface/ported/rpc/a/calculation_field_selection_test.exs`: survivors C1, C2, C3, C4, C6 (calculation arg-validation branches; assert each tag per branch).
4. `test/ash_surface/ported/typed_controller/fold_argument_constraints_test.exs`: survivors F1 (ci_string default fold), F3 (item_type return nesting).
5. `test/ash_surface/ported/rpc/d/run_typed_query_surface_test.exs`: survivors T1 (multi-entry ordering), T3 (action_not_found payload), T4 (multi-field request), T5 plus RAK field_formatter mapped-name (fixture needs a field whose `field_names` mapping differs from camelCase).
6. `test/ash_surface/ported/rpc/a/error_redaction_surface_test.exs`: survivors E1, E2, E3, E4, E6 (short_message/type table text unpinned); E5 equivalent-by-construction, drop.
7. `test/ash_surface/ported/rpc/d/struct_argument_test.exs`: survivors S2 (embedded resource? true), S3 (expand_embedded flag), S4 (struct field_names), S5 (input field type lookup).
8. `test/ash_surface/ported/ts/root/entry_points_test.exs` and `custom_zod_overrides_test.exs`: survivors Z1, Z2, Z3 (override precedence), Z4, Z5, Z7.
9. `test/ash_surface/ported/rpc/rak/value_formatter_branches_test.exs`: survivor VF2 (keyword duplicate-key order).
10. `test/ash_surface/ported/rpc/rak/validator_refusals_test.exs`: survivor V3 (admission refusal order, needs >=2 unknown actions).
11. `test/ash_surface/ported/rpc/rak/pipeline_scoped_get_by_test.exs`: survivor I3 (`keyword` in non_scalar_kinds).
12. `test/ash_surface/ported/rpc/d/runtime_source_of_truth_ast_guard_test.exs`: handle `import` of forbidden modules, `apply/3`+`Kernel.apply/3` with literal module atoms, piped `Map.get/2` (match key at last arg), `Map.fetch`/`Access` on retired keys, extend @actuating with `stream`, `run_action`, `load`, `calculate`; resolve `__MODULE__` alias parts without crashing; add non-vacuity self-tests for each.

Cleanup: scratch `/tmp/skmf` retained (created by this lane); no directory in the repo created.
