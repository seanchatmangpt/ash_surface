# Wave 3 Lane G3 Receipt

Standing: PARTIAL

## Commands
- `MIX_BUILD_ROOT=_build-g3 mix test test/ash_surface/verifiers` -> 10 tests, 0 failures, rc 0.
- Regression set (verifiers, resource/*, verifier court, no_local_do, mock_discipline,
  typed_query_fields, field_name_mapping, parity/*): 165 tests, 7 failures, 9 skipped, rc 2.
  All 7 failures are in `test/ash_surface/parity/gate*_test.exs` (register parser / fixture
  gate, owned by the parity-gate lane, untracked `lib/ash_surface/parity/`); none touch
  verifier code. UNVERIFIED whether pre-existing or concurrent-lane.
- `mix ash_surface.parity` rc 1: verifier 15 total 6/0/0/0/9 -> 13/0/0/0/2;
  transformer 5 total 0/0/0/0/5 -> 1/0/0/0/4 (pass/div/non_goal/broken/missing).
  Overall 253 pass / 65 missing / 7 broken (broken ids are outside my sections).
- `mix format --check-formatted` on changed files rc 0. `_build-g3` deleted.

## Dispositions
| id | disposition |
|---|---|
| verifier.VerifierChecker | pass: new `AshSurface.VerifierChecker` |
| verifier.VerifyMapFieldNames | pass: typed-map key collisions (Checks) |
| verifier.VerifyMappableTypes | pass: Checks wires `ZodType.unmappable_kinds/2` |
| verifier.VerifyMetadataFieldNames | pass: explicit court; stale moduledoc fixed |
| verifier.VerifyRpcWarnings | pass: Domain verifier stderr warning, `warn_on_missing_rpc_config` |
| verifier.VerifyUniqueInputFieldNames | pass: Checks, resolved via `argument_names` |
| verifier.VerifyUniqueTypeNames | pass: `AshSurface.Domain.Verify` |
| verifier.VerifyTypedChannel | MISSING (see decisions) |
| verifier.VerifyTypedController | MISSING (see decisions) |
| transformer.PersistFormattedFields | pass: Persist persists `:ash_surface_formatted_fields` |
| transformer.BuildManifest / DecorateManifest | MISSING |
| transformer.FoldArgumentConstraints / GenerateController | MISSING |

## Operator decisions
- VerifyTypedChannel, VerifyTypedController, FoldArgumentConstraints, GenerateController:
  ash_surface has no typed_channel/typed_controller DSL. Candidate non-goals need README
  verbatim quotes; README not editable by this lane. Left MISSING.
- BuildManifest / DecorateManifest: ash_surface compiles IR from `Ash.Info.Manifest` in
  `Compiler`, no Spark transformer; either non_goal wording in README or a mapped court.
- No new `aex:Verifier` rows added to ontology.ttl (checks run inside the existing
  Validator delegate; no regen); say if ontology rows + specimens are required.
- VerifyRpcWarnings is an analogue (surface resource without projection), not an RPC check.

## Files changed
- lib/ash_surface/resource/verifiers/checks.ex (new), lib/ash_surface/resource/validator.ex,
  lib/ash_surface/domain.ex, lib/ash_surface/persist.ex, lib/ash_surface/verifier_checker.ex (new)
- test/ash_surface/verifiers/g3_verifiers_test.exs (new),
  test/ash_surface/resource/validator_action_types_test.exs (moduledoc only)
- parity/court_map.json (verifier/transformer ids), this receipt
