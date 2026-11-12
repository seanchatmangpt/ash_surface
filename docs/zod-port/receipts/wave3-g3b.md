# Wave 3 Lane G3b Receipt

Standing: PASS

All six ids are dispositioned (5 pass, 1 non_goal); no id remains MISSING. Two unrelated
verifier rows turned broken during the run (see Commands).

## Per-id disposition

| id | disposition | evidence |
|---|---|---|
| transformer.BuildManifest | pass | `manifest_transformers_test.exs` (decorated == generated + only `custom.ash_surface`) + G4b `manifest_dsl_test.exs` round trip |
| transformer.DecorateManifest | pass | `manifest_transformers_test.exs` (id, profile, show_metadata, dsl, typed queries, naming) + `manifest_dsl_test.exs` digest court |
| transformer.FoldArgumentConstraints | pass (implemented) | new `AshSurface.Compiler.RouteSchema.Fold`, wired in `RouteSchema.build_one`; `fold_argument_constraints_test.exs` (5 tests incl. node/zod) |
| transformer.GenerateController | non_goal | README verbatim: "it never actuates" (generated controller runs handlers) |
| verifier.VerifyTypedChannel | pass | `ChannelDiscovery` (events exist, unique, object payload, warnings); channel_discovery_test courts |
| verifier.VerifyTypedController | pass | RouteSchema admission (duplicate names/args/path params), Fold arg-type refusal, hostile name courts; handlers = `run` non_goal |

No Spark transformer modules added: ash_surface ingests the manifest Ash produces
(`from_manifest` + `Manifest.Dsl`), so the mapping is to existing functions + new courts.

## Implemented

- Fold: unknown argument kind -> `{:invalid_argument_type,..}`; ill-typed/inapplicable
  constraints -> `{:invalid_argument_constraints,..}`; Ash string default `allow_empty?: false`
  folded explicit (renders `.min(1)`, executed under zod); `returns` resource/embedded/union
  (also array items) -> `{:unsupported_return,..}`.
- Previously these silently rendered `z.unknown()` or ignored the constraint.

## Operator decisions

- Behavior change: route string args without `allow_empty?` now reject "" (reference
  semantics via fold). No existing court pinned the old behavior.
- GenerateController non_goal wording relies on the existing README sentence; add an explicit
  "no generated Phoenix controller" sentence if preferred.

## Commands

- `MIX_BUILD_ROOT=_build-g3b mix test test/ash_surface/transformers` -> 7 tests, 0 failures.
- Regression (transformers, route_schema, introspector, adversarial, channel_discovery, s1h,
  runtime_parity, verifiers, verifier court, canary, no_local_do, mock_discipline):
  211 tests, 2 failures, both outside my files: FieldSelectionTest atomizer (runtime_parity)
  and ExpoWave3S1hCourtTest "hostile keys" (route_schema.ex now returns
  `{:denied_argument_name,..}` from a concurrent lane's edit at line 185; the test needs
  that lane's update). UNVERIFIED whether pre-existing.
- `mix ash_surface.parity`: transformer 4/0/1/0/0, verifier 13/0/0/2/0 (the 2 broken are
  VerifyFieldNames and VerifyMetadataFieldNames, vacuous-test lint from other lanes);
  global pass=218 non_goal=79 broken=35 missing=71.
- `mix format --check-formatted` on changed files rc 0. `_build-g3b` deleted.
- Mid-run compile blocked by another lane's `test/support/ported/resources/todo.ex`
  (AshPostgres.Ltree); resolved by that lane, not touched by me.

## Files changed

lib/ash_surface/compiler/route_schema/fold.ex (new), lib/ash_surface/compiler/route_schema.ex
(alias + 2 `with` steps), test/ash_surface/transformers/{manifest_transformers,
fold_argument_constraints}_test.exs (new), parity/court_map.json (6 ids + 1 title fix on
DecorateManifest's G4b court), this receipt.
