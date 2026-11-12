# Wave 3 Lane G4b: Manifest.Dsl and TypedChannel.Interception

Standing: PARTIAL

## Commands

- `mix test test/ash_surface/runtime_parity test/ash_surface/no_local_do_test.exs
  test/ash_surface_mock_discipline_test.exs` -> rc=0, `19 tests, 0 failures` (final run). An
  earlier combined run showed one failure in G4's `field_selection_test` ("atomizing never mints
  atoms", atom-count delta 275 vs bound 50) while my async compile of fixture modules ran
  concurrently; the file alone is `9 tests, 0 failures`. Atom-count bound is load-sensitive
  (pre-existing, not changed here).
- `mix test from_manifest_test manifest_serializer_test fuzz_from_manifest_test
  ir_codec_golden_test typed_query_fields_test` -> `3 properties, 83 tests, 0 failures`.
- `mix format --check-formatted` on the three changed lib/test files -> rc=0.
- `mix ash_surface.parity` -> runtime row `41  32/0/5/3/1`; `MISSING
  runtime.module.TypedChannel.Interception` is the only runtime MISSING; `Manifest.Dsl` is gone
  from the MISSING list. Other lanes' ERRORs (SHARED-TEST closes 5 rows for Resource.Info/Rpc.Info/
  Rpc; tstype.* titles) appear in the same output and are not from this lane.

## Disposition

- `runtime.module.Manifest.Dsl` -> PASS. Reference (`manifest/dsl.ex:1-23`) is a Spark extension
  whose transformers BuildManifest/DecorateManifest serialize DSL declarations into the manifest.
  Counterpart `AshSurface.Manifest.Dsl` (`serialize/1`, `serialize_all/1`, `read/1`) serializes
  `type_name`, `namespace`, `field_names`, `argument_names`, `show_raised_errors?` and
  `typed_query` entities (name, action, description, result_type_name, fields_const_name, field
  tree) for each manifest resource. Written to `manifest.custom[:ash_surface]["dsl"]` and to
  `contract["surface"]["dsl"]` (finding: `Ash.Info.Manifest.JsonSerializer` does not emit
  `custom`, so the envelope is the carrier that reaches JSON and the digest). Absent when nothing
  is declared, so existing digests/goldens are unchanged (83 related tests green). Per-action
  `show_metadata`/`metadata_field_names` were already in action custom (F1-meta). Courts:
  `runtime_parity/manifest_dsl_test.exs` (round trip DSL -> manifest -> JSON -> read-back
  equality; re-ingest digest equality; stale custom ignored; digest covers `dsl`).
  Verifier counterparts exist in `resource/verifier` (F1 lanes).
- `runtime.module.TypedChannel.Interception` -> MISSING, no invention. Evidence
  (`~/ash_typescript/lib/ash_typescript/typed_channel/interception.ex`): `inject/0` (line 34)
  sets `@phoenix_intercepts` and defines `handle_out/3` clauses (lines 70-77) calling
  `PayloadFormatter.push_formatted`; non-channel modules only get `IO.warn` (lines 80-86). It
  is compile-time server runtime wiring; the payload shape is defined by PayloadFormatter and the
  channel DSL publications, which ash_surface already projects (parity ids TypedChannel,
  .Dsl, .Info, .PayloadFormatter pass). Interception adds no shape input.

## Operator decisions

1. Add README non-goal: "AshSurface does not intercept or rewrite server-side Phoenix channel
   traffic (no `handle_out`/`intercept` injection); channel payload schemas are projected only."
   Then `runtime.module.TypedChannel.Interception` can be registered `non_goal` citing it.
2. `mix test` on the atom-count assertion in G4's atomizer court may flake under load; consider a
   relative bound.

## Files changed

- NEW `lib/ash_surface/manifest/dsl.ex` (F1-sparkguard added a `Spark.Dsl.is?` guard; kept)
- `lib/ash_surface.ex` (surface_envelope and decorate_manifest: `dsl` key)
- NEW `test/ash_surface/runtime_parity/manifest_dsl_test.exs`
- `parity/court_map.json` (`runtime.module.Manifest.Dsl` entry)
- NEW this receipt. `_build-g4b` removed.
