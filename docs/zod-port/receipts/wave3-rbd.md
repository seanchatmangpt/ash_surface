# Wave 3 RBD: Namespace Strictness Decision and RAZ Mutation Proof

Standing: PASS

Lane RBD. Subject: working tree of /Users/sac/ash_surface (no git state commands run).

## Decision: align to reference (no KD-12)

- KD register and parity court_map: no row covered the stricter refusal (court_map only maps
  `type_name / namespace identifiers`, typed_query_fields_test.exs).
- Harm search: resource/domain `namespace` is consumed only by
  `ActionManifest.namespace/1` (grouping string, emitted verbatim; RAZ proves "", "a b", "1x"
  survive) and `Info.effective_namespace/1`. `enable_namespace_files`/`namespace_output_dir`
  have no consumer in lib/; `RouteSchema.namespace_plan` reads route-level namespaces, which
  were never refused. No invalid identifier, path, or key collision was witnessed. No harm, so
  the divergence is not "better": refusal removed.

## Edits (all disclosed)

- lib/ash_surface/resource/validator.ex: removed `namespace_refusals/1` and its call.
- lib/ash_surface/domain.ex: removed `verify_namespace/1` and `error/2`.
- test/ash_surface/ported/rpc/ray/namespace_edges_test.exs: resource/domain tests now assert
  acceptance (no invalid_namespace, no DslError).
- test/ash_surface/typed_query_fields_test.exs: namespace "a b" now `refute invalid_namespace`.
- test/ash_surface/ported/rpc/raz/entry_namespace_parity_test.exs: moduledoc updated.

## Commands

- `mix test ray raz typed_query_fields_test.exs` (MIX_BUILD_ROOT=_build-rbd): rc=0, 46 tests, 0 failures.
- RAZ mutation (in memory via Code.compile_string, /tmp/rbd/mut.exs): ActionManifest namespace
  normalized (trim/downcase/space to underscore); RAZ test: 5 tests, 3 red ("a b", " pad ",
  "Mixed-Case.x"); "" and "1x" unaffected by this mutation. Shared file sha256 before == after
  (903bb517...2ef); restored run is green (above).
- `mix ash_surface.parity.tests --summary`, rc=0 un-piped:
  files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=90.

## Falsifier

A witnessed emitted-artifact harm from a resource/domain namespace refutes this decision.
