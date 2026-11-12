# Wave 3 Lane 01: IR wiring (normalize_action + Fragments.enrich)

Standing: PARTIAL

PARTIAL because 9 failures remain in the run set, none in owned files (listed
under Commands); owned tests pass.

## Files

- lib/ash_surface/compiler/resource_facts.ex (NEW; resource facts, one call per action)
- lib/ash_surface/compiler.ex (normalize_action merges ResourceFacts; pagination_facts
  adds default_limit/max_page_size)
- lib/ash_surface/compiler/ir.ex (Fragments.enrich rewritten over the Phase-A renderers)
- lib/ash_surface/ir.ex (IR.Schema +9 fields), lib/ash_surface/ir/codec.ex (@schema_fields),
  lib/ash_surface/projector/ir_entry.ex (accessors)
- test/ash_surface/compiler/ir_wiring_test.exs (NEW, 17 tests, real fixture domains)
- test/ash_surface/ir_test.exs, test/ash_surface/ir_codec_golden_test.exs (re-pinned)

## Carried facts (both manifest and raw-Ash paths; resource read via Ash.Resource.Info)

- sortable_fields: public fields passing `Ash.Resource.Info.sortable?` (keyset-aware), NOT
  input names; nil for get / non-read / enable_sort? false (typed reason each).
- filter entries: filterable public attributes + calculations + aggregates (aggregate kind
  from `Ash.Query.Aggregate.aggregate_type`); data-layer function names as `functions`
  metadata (never operators; `FilterSchema.operator_key` excludes operator-claimed names).
- pagination incl default_limit, max_page_size (manifest and raw); `max_limit`/`default_limit?`
  feed `QuerySchema.render_query_params`.
- get_by (+ key kinds), not_found_error?, enable_sort?/enable_filter?, read_action,
  allowed_loads/denied_loads (dotted paths), identities (projection-filtered), primary_key,
  multitenancy (strategy/global?/attribute) from the `:surface` projection
  (`Projections.for_action`) with defaults; no projection => nil + reason `no_surface_projection`.
- relationships (belongs_to/has_one one; has_many/many_to_many many; pagination from the
  destination primary read, filterable/sortable/exposed, primitive_fields).
- calculations (args: allow_nil?/has_default?/constraints; return_kind/return_ref) and
  aggregates (name, kind, field, field_kind, allow_nil?, field_definition, union_facts).

New IR.Schema fields: get, tenant, load, selection, calculations, aggregates,
validation_error, facts, nil_reasons; `error` gained `carry` and `field_errors`.
Renderers used directly: QuerySchema, IdentitySchema, RelationshipSchema, SelectionSchema,
CalculationSchema, FilterSchema, ErrorSchema.carry/field_errors, ValidationErrorSchema.
Honest-nil: every nil fragment has `nil_reasons[field]` (string, or
`%{"reason","detail"}` for renderer refusals) - the `Fragments.ok/1` swallow is gone.

## Commands and output

Owned set + compiler courts (MIX_BUILD_ROOT=_build-w301, deleted):
`mix test test/ash_surface/compiler/ir_wiring_test.exs test/ash_surface/ir_test.exs
test/ash_surface/ir_codec_golden_test.exs test/ash_surface/ir_codec_test.exs
test/ash_surface/ir_struct_test.exs test/ash_surface/ir_codec_coverage_test.exs
test/ash_surface/digest_test.exs test/ash_surface/compiler test/ash_surface/compiler_test.exs
test/ash_surface/compiler_coverage_test.exs test/ash_surface/compiler_discovery_test.exs
test/ash_surface/compiler_sections_coverage_test.exs test/ash_surface/no_local_do_test.exs
test/ash_surface_mock_discipline_test.exs` -> `431 tests, 9 failures` (exit 2). The 9, none
in owned files:

- 7x (digest_test x6, ir_codec_golden "reuse pin"): `X is not a Spark DSL module` at
  lib/ash_surface.ex:232 `dsl_metadata_options/1` (`Spark.extensions(resource)` on a plain
  test module) - another lane's in-flight lib/ash_surface.ex edit.
- compiler/schema_constraint_test float bounds: ZodType renders `min(0)` not `min(0.0)`.
- s1g_schema_courts: `File.ln_s!` race on shared tmp node_modules symlink (concurrency).

Downstream: `mix test test/ash_surface/projectors test/ash_surface/projector
test/ash_surface/projector_ir_determinism_test.exs test/ash_surface_verifier_court_test.exs
test/ash_a2a_verifier_court_test.exs` -> `190 tests, 1 failure, 2 skipped`; the 1 is
projector/expo_origin_test (node `ERR_MODULE_NOT_FOUND` in a shared tmp dir; not mine).
no_local_do and mock_discipline: 0 failures. Goldens re-pinned: full IR digest
85e3b3ca... -> 52edac14... (schema-section shape only).

## Stale for w3-04 (conformance lane)

- conformance/vectors/ir_codec.json (schema section now has 9 more keys; digests change);
  conformance/MANIFEST.json hash for it; scripts/conformance_regen.exs regeneration;
  conformance/elixir/runner.exs and conformance/js/* only if they pin the schema key list.
- digest_test goldens are blocked by the lib/ash_surface.ex failure above, so they could not
  be re-derived; they hash fixtures not compiled IR and should not move from this change.

## UNVERIFIED

- Per-field filter operators use the FilterSchema catalog default by kind; no data-layer
  operator restriction was computed (data-layer functions are metadata only).
- get result schema (`QuerySchema.render_get_result_schema`) and `response_zod` stay nil
  (`nil_reasons.response_zod = no_record_schema`): no record schema is carried.
- Nested relationship loads beyond RelationshipSchema's default depth; relationship
  `exposed` is always true (no Ash source for it).
- Tenant required-ness follows `Config.require_tenant_parameters` (identity lane's default
  false), so the tenant fragment is `.optional()` unless config/fact says otherwise.
- Manifest path tested with hand-built `%Manifest.Action{}` (inputs empty); a generator-built
  manifest was not run.

## Requests

- lib/ash_surface.ex owner: guard `Spark.extensions/1` for non-Spark resources.
- w3-04: regen ir_codec.json after the above clears.
- js.ex/w3-03: may now consume `facts`, `get`, `tenant`, `load`, `selection`,
  `calculations`, `aggregates` via IREntry (`load_zod`, `selection_zod`,
  `validation_error_zod`).
