# Wave 2 b1a: schema section carries the full declared type facts

Standing: PARTIAL

Lane b1a-successor (replaced the stopped b1a lane). Census D-03 root cause
(`Compiler.Section.Schema.argument_entry/1` dropping constraints, subtype facts,
items, values, members, fields, instance_of, has_default) is fixed on the
manifest path and the raw-Ash path. PARTIAL because of the open items below
(UNVERIFIED and downstream-owned failures), not because of this lane's files.

## Stopped-lane partial edits: kept / repaired / discarded

Baseline: `MIX_BUILD_ROOT=_build-b1b mix compile` exit 0 (no compile errors in
any of the stopped lane's files). Baseline test run over the owned test set
before my edits: 262 tests, 21 failures; 8 of those were other lanes' files
(embedded_schema, filter_schema x2, s1g courts x2, constraint_validator,
filter_schema_size) and several cleared as those lanes landed.

- `compiler/type_facts.ex` (new): KEPT; repaired `type_name/1` (it had added an
  `{:array, _} -> "array"` clause that changed the v29 `ash` section type name
  from `inspect({:array, t})`; removed, AshTruth stays byte-compatible).
- `compiler.ex`: KEPT; repaired `input_entry/3` so an unresolvable type keeps
  `type: nil` (was `"unknown"`), preserving the "UNKNOWN, never guessed" law.
- `ash_truth.ex`: KEPT; added `admitted_keys().constraint` (the shared
  constraint vocabulary) so the vocabulary test can cover nested keys.
- `compiler/section/schema.ex`: KEPT as written (forwards `type_facts`, adds
  `optional` for defaulted or nil-able inputs).
- `compiler/schema.ex` (zod_fragment routing: EmbeddedSchema.container? ->
  EmbeddedSchema.render, scalars -> ZodType.fragment, typed errors propagate):
  KEPT as found on disk (not in my OWNED list; present from a prior lane).
- `projector/expo.ex`: UNTOUCHED by me. Its on-disk diff contains twin edits
  (`omittable_input`, `object_key`) and unrelated runtime-client edits that
  belong to other lanes (w3-03 owns codegen).
- `test/support/zod_fixtures/constraints.ex`: KEPT, complete (compiles, used by
  the new court).
- Re-pinned: `schema_section_test` (Expo byte-compat test now adds `optional`
  for nil-able args exactly as Section.Schema does), `schema_constraint_test`
  (as left), `ash_section_truth_test`, `ash_section_test`, `compiler_test`,
  `compiler_coverage_test` (see Files).

## Files changed (this lane)

- lib/ash_surface/compiler/type_facts.ex (repair), compiler.ex (repair),
  compiler/ash_truth.ex (add constraint vocabulary export).
- test/ash_surface/compiler/section_schema_constraints_test.exs (NEW, 6 tests:
  emitted-text chains, ZodGuard admit, byte-identical two runs, IR slice facts,
  node+real zod valid / invalid / omitted payloads).
- test/ash_surface/ash_section_truth_test.exs, compiler/ash_section_test.exs,
  compiler_test.exs, compiler_coverage_test.exs, compiler/schema_section_test.exs
  (re-pins).

## Commands and exit output

- `MIX_BUILD_ROOT=_build-b1b mix compile` -> exit 0.
- Owned set + no_local_do + mock_discipline + census files:
  `mix test test/ash_surface/compiler test/ash_surface/ash_section_truth_test.exs
  test/ash_surface/compiler_test.exs test/ash_surface/compiler_coverage_test.exs
  test/ash_surface/compiler_discovery_test.exs test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs test/ash_surface/ts/zod_codegen_test.exs
  test/ash_surface/ts/zod_runtime_test.exs
  test/ash_surface/projector/generated_artifacts_exec_test.exs`
  -> `327 tests, 8 failures` (exit 2). The 8 failures: 1 in
  `filter_schema_size_test` (FilterSchema, not owned) and 7 in
  `generated_artifacts_exec_test` (see below). no_local_do and mock_discipline:
  0 failures. `section_schema_constraints_test.exs` alone: `6 tests, 0 failures`.
- `ts/zod_codegen_test.exs` and `ts/zod_runtime_test.exs`: pass in that run.

## Census-failing tests: exact state

`projector/generated_artifacts_exec_test.exs` (7 red, owner: Expo projector /
IR lane + w3-03, not the schema section):

- Schema cases (real fixture, mutation `uuid weakened`): the Expo-emitted
  `VolunteerMilestone_{read,record}_inputSchema` has no `id` field at all
  (probed: fields are cost_physical, member_id, milestone_id, reward_spiritual,
  status), so `id: "not-a-uuid"` is accepted. Source is `Projector.IR`/
  `ir_entry.ex` field derivation, not `Section.Schema`. Needs: IR lane to carry
  the resource's public attribute facts (or the test to drop the `id` case).
- Tanstack "Missing expected rejection" (`INPUT_VALIDATION_FAILED`) is the same
  missing-field cause.
- `unknown_resource "unresolved" "Missing"` (hand-built degrade test) is a
  typed refusal from the Expo projector; the test predates it. Owner: Expo/w3-03.
- `file already exists` on `rm_rf!(_build/test/generated_artifacts_exec)` and
  `mut_events.json ENOENT`: shared `_build/test/generated_artifacts_exec`
  directory raced by concurrent lanes (test uses a fixed tmp dir). Re-run in
  isolation when the fleet is quiet. Runtime-shim copy (needs
  ash_surface_runtime.mjs + http/channel transport beside the artifacts) was
  NOT the failure observed here; zod_codegen/zod_runtime pass.

## Digest and golden churn (for lanes w3-01 / w3-04)

- Every `ash` section input now carries `constraints`, `subtype_of`,
  `subtype_constraints` (struct fields from the IR lane); every Ash string
  argument carries `constraints: %{allow_empty?: false}` (Ash's default, now
  admitted). Any digest/golden over a compiled IR with string inputs is stale:
  `conformance/vectors/ir_codec.json` and `ir_codec_golden_test` vectors built
  from compiled IR, and AshTruth golden sections.
- `schema.input` entries now carry `constraints`, `type.module`, `type.items`,
  `type.values`, `type.members`, `type.fields`, `type.instance_of`,
  `type.resource?`, and `optional` (defaulted or nil-able). `schema.zod` for
  constrained / enum / array / union / struct arguments changes from bare kinds
  to constraint chains. Schema-section goldens and conformance vectors that
  embed `schema.zod` or `schema.input` are stale.
- The normalized compiler entry gained `constraints`, `subtype_of`,
  `subtype_constraints`, `type_facts`, `embedded_resources`, `get?`,
  `pagination` (not part of the IR; digests unaffected beyond the above).
- Unchanged by design: AshTruth type name for `{:array, t}` stays
  `inspect({:array, t})`.

## UNVERIFIED

- Regex normalization of Spark `{Spark.Regex, :cache, ..}` tuples is covered by
  the real `~r/^\d{3}$/` fixtures only; a bare Spark tuple input was not
  separately exercised.
- Manifest-path union/embedded-resource arguments: the court covers typed struct
  and union; an embedded resource argument is not in the new fixture
  (EmbeddedSchema's own tests cover rendering).
- Non-vacuity of the new court was not shim-court proven (no mutation run).

## Requests to the IR lane

Carry sortable_fields, get_by, identities, multitenancy, not_found_error?,
enable_*, loads, relationship, and calculation/aggregate facts through
`normalize_action` and `Fragments.enrich`. `normalize_action` now also emits
`get?` and `pagination` (verbatim manifest facts) and `embedded_resources`.
Also: the Expo field derivation drops the resource `id` (above).

## Cleanup

`_build-b1b` deleted.
