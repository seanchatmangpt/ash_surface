# Wave 3 Lane T12 Receipt

Standing: PARTIAL

Scope: `rpc/` struct_field_filtering .. zod_mapped_fields (17 reference files, 240 tests).
Reference `~/ash_typescript` Ash lock 3.37.1; this checkout locks Ash 3.33.11. 9 rows
`adapted` (137 real tests), 8 rows `skipped_gap` (loud per-test skips only). Targets under
`test/ash_surface/ported/rpc/e/`; private helpers in `ported/rpc/e/support/{e,fixtures}.exs`.

## Per-file disposition

| reference file (tests) | ash_surface file(s) | disposition |
|---|---|---|
| struct_field_filtering (6) | struct_field_filtering_gap_test.exs | skipped_gap (Rpc.ResultProcessor not a gated capability) |
| top_level_strictness (9) | top_level_strictness_gap_test.exs | skipped_gap (Rpc.Pipeline.parse_request) |
| ts_runtime_validation (1) | ts_runtime_validation_gap_test.exs | skipped_gap (TS shouldPass through run_action) |
| tuple_newtype_input (13) | tuple_newtype_input_test.exs (12) + _gap_test.exs (1 skip, not on row) | adapted |
| typed_map_embedded_rows (3) | typed_map_embedded_rows_gap_test.exs | skipped_gap |
| typed_query_codegen (6) | typed_query_codegen_gap_test.exs | skipped_gap (TS typed-query const text) |
| typed_query_field_mapping_cross_domain (5) | typed_query_field_mapping_cross_domain_gap_test.exs | skipped_gap |
| valibot_constraints (50) | valibot_constraints_gap_test.exs | skipped_gap (operator decision D-T12-1) |
| verify_identities (12) | verify_identities_test.exs | adapted (lib edit) |
| verify_metadata_field_names (13) | verify_metadata_field_names_test.exs | adapted (lib edit) |
| verify_rpc_options (7) | verify_rpc_options_test.exs | adapted (lib edit) |
| verify_rpc_public_actions (8) | verify_rpc_public_actions_test.exs | adapted (lib edit) |
| verify_typed_query_fields (8) | verify_typed_query_fields_test.exs | adapted |
| working_comprehensive (12) | working_comprehensive_gap_test.exs | skipped_gap (run_action runtime) |
| zod_constraints (48) | zod_constraints_test.exs | adapted (lib edit: Money) |
| zod_declaration_order (9) | zod_declaration_order_test.exs | adapted |
| zod_mapped_fields (30) | zod_mapped_fields_test.exs (20) + _gap_test.exs (10 skips, not on row) | adapted |

Per-test notes are in each ledger row `changes`/`gap`. The zod_* files assert both the generated
Zod text of the real projected artifact and accept/reject behavior under real node + real zod
(one node process per module). verify_* files run real Ash resources through
`AshSurface.VerifierChecker`; fixtures compiled per test via `Code.compile_string`.

## lib / test edits (disclosed; each driven by a reference test, divergence law)

1. `lib/ash_surface/resource/validator.ex` (shared; targeted edits, `mix format`ed):
   - identity law: `:_primary_key` admitted when a primary key exists, refused without one;
     unknown identity refusal carries "Identity not found on resource" + available list.
   - `metadata_wire_refusals`: invalid / colliding shown-metadata wire names (mapped or not).
   - `load_path_refusals` (`invalid_load_paths`): allowed_loads/denied_loads path existence.
   - `relationship_destination_refusals`: non-public primary read of a surface destination.
   - messages: admission refusal says "not `public?`" for private actions (still lists the exact
     public action set), read_action and typed_query-unknown-action likewise; show_metadata
     refusal says "show_metadata contains unknown metadata fields" and names the projection.
2. `lib/ash_surface/compiler/zod_type.ex`: built-in `third_party_types/0`
   (`AshMoney.Types.Money` -> `z.object({ amount: z.string(), currency: z.string() })`; user
   `zod_mapping_overrides` win). No new kind, so the pinned `ZodType.kinds()` courts are intact.
3. `test/ash_surface/resource/validator_action_types_test.exs` (other lane's test, re-pinned):
   "empty loads lists do not count as declared" asserted `[] == codes(...)` with load `:a` on a
   resource with no loadable fields; with the load-path law `:a` is an invalid path, so the test
   now asserts the property it names (no `allowed_and_denied_loads_conflict`).

## Commands (MIX_BUILD_ROOT=_build-t12 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/e test/ash_surface_mock_discipline_test.exs test/ash_surface/resource` | 0 | 301 tests, 0 failures, 103 skipped (all 103 = loud tagged skips in `*_gap_test.exs`) |
| `mix format --check-formatted` over rpc/e, support, validator.ex, zod_type.ex, edited test | 0 | clean |
| `mix run /tmp/t12_rep.exs` (`ParityTests.Report.evaluate/0`) | n/a | my 17 rows: 0 broken, 0 unaccounted |
| `mix ash_surface.parity.tests --summary` (global, other lanes pending) | 1 | `files=264 ported=9 adapted=182 skipped_gap=40 non_goal=19 unaccounted=0 broken=14 shallow=82`; the 14 broken rows belong to T8 (13: `rpc/a/*_gap_test.exs` missing or tag mismatch) and T11 (`run_typed_query` gap file missing), none to T12 |

My 17 rows: adapted=9, skipped_gap=8, unaccounted=0, broken=0. Counts of real tests:
tuple 12, verify_identities 12, verify_metadata 13, verify_rpc_options 7, verify_rpc_public_actions
8, verify_typed_query_fields 8, zod_constraints 48, zod_declaration_order 9, zod_mapped_fields 20.
Skips: 103 (6+9+1+3+6+5+12+50 + 10 zod_mapped + 1 tuple). Mock/sleep grep: the mock-discipline
court passed over the new files; no `Process.sleep` in any new file.

## Observations outside T12 (not caused by this lane; UNVERIFIED root cause)

- `test/ash_surface/verifiers/g3_verifiers_test.exs` "an attribute whose type has no Zod kind is
  refused" failed in a mixed run: a custom `Ash.Type` with `storage_type :string` no longer
  yields `unmappable_type` (another lane's storage-derived custom-type mapping landed); the test
  premise rotted. `ported/rpc/a/custom_type_schema_test.exs` failed once mid-run and passed on
  the re-run.
- Ash version skew (reference 3.37.1, lock 3.33.11): `Ash.Type.Tuple` map-to-tuple casting is
  absent here; the tuple test asserts the disjunctive law (tuple or typed "is invalid").

## Operator-decision list

- D-T12-1 valibot_constraints (50 tests): README.md has no sentence declaring Valibot out of
  scope (line 128 names Zod as the executable boundary schema library only), so non_goal is not
  supportable. Add a README Valibot non-goal sentence (then re-class), or build a Valibot
  projector.
- D-T12-2 Rpc runtime gaps (struct_field_filtering, top_level_strictness, ts_runtime_validation,
  typed_map_embedded_rows, working_comprehensive, tuple InputFormatter test): remain loud skips
  until the GAP-UPGRADE lane (queue item 0000, after T6b `RPC-PIPELINE-CORE.md`); an in-flight
  `lib/ash_surface/runtime_parity/rpc/` port exists but needs `Support.install/2` and is not gated.
- D-T12-3 typed-query constant text (typed_query_codegen, typed_query_field_mapping_cross_domain,
  11 tests): no JS typed-query constant projection exists; decide implement vs README non-goal.
- D-T12-4 w3-15 (FieldName wiring): resource-level `field_names`/`argument_names` are not applied
  to action-input Zod keys (`"archived?"`, `"is_task_completed_now?"`), and keys are not
  formatter-cased; 10 zod_mapped_fields tests are skipped on this, and zod_constraints keys are
  Ash names verbatim.

## Standing / falsifiers

PARTIAL: every reference file is accounted and every counterpart that is feasible without the
Rpc runtime or w3-15 is a real executed test. Falsifier: a `skipped_gap` row whose capability
lands (Pipeline/ResultProcessor, FieldName wiring, typed-query constants) must flip to real tests;
the loud skips make that visible. `_build-t12` deleted at hand-off.
