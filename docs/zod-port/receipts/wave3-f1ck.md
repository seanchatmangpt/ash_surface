# Wave 3 Lane F1-cfgkeys: Literal-Titled Config Key Courts

Standing: PARTIAL

All config.key.* rows are now PASS under the hardened gate (config MISSING 54 -> 0, config
ERROR 3 -> 0). PARTIAL because most keys remain accessor-plus-Verifier only (no renderer
consumer), listed below as an operator decision.

## Before / after (`mix ash_surface.parity --json`, config.* ids)

| | config MISSING | config ERROR | global counts |
|---|---|---|---|
| before | 54 | 3 (import_into_generated, manifest, policies) | broken 35, missing 71, pass 218 |
| after | 0 | 0 | broken 1, missing 28, pass 295 (other lanes moved concurrently) |

Global exit stays 1 for non-config rows (not owned here).

## Changes

- New `test/ash_surface/config/parity_key_courts_test.exs`: 57 literal-titled tests
  `config.key.<id> default, override, Verifier validation` (generated once from the
  `parity_keys_test.exs` case table, written out literally). Each asserts accessor default,
  override value, `Verifier.verify() == :ok`, invalid override -> `{:error, errs}` with a
  `<key> ` prefixed error, and `Verifier.verify!/0` raises.
- `parity/court_map.json`: 57 `config.key.<id>` entries point at those titles
  (one script read-modify-write; json valid; file is untracked so no git diff).
- Real defect found and fixed: `lib/ash_surface/config/verifier.ex` `identifier_errors/0`
  crashed (Protocol.UndefinedError) when `:zod_mapping_overrides` was not a list of pairs or
  map; it now yields no names there and `override_errors/0` reports the shape error.
- No edits to `lib/ash_surface/parity/*`.

## Commands

- `MIX_BUILD_ROOT=_build-f1ck mix test test/ash_surface/config/parity_key_courts_test.exs`
  first run 57 tests 1 failure (zod_mapping_overrides crash above).
- after fix: `mix test test/ash_surface/config` -> 118 tests, 0 failures, exit 0.
- `mix ash_surface.parity --json` -> config.* missing [] / errors [] (script exit 0; gate
  exit 1 from unrelated rows). `_build-f1ck` deleted.

## Operator decision (task 2, no consumer implemented)

Keys with no `lib/` renderer consumer (accessor + Verifier only), per wave3-f1d.md: the
valibot_* keys, generate_valibot_schemas, typed_controller_* keys, typed_channels*,
rpc_action_*/rpc_validation_* hook and context_type keys, run/validate_endpoint,
namespace/manifest file keys, add_ash_internals_*, router, policies, warn_on_non_* and
others. Choosing consumer vs divergence vs non-goal (README quote required) needs an
operator call; none was classified here so no unverified claim is made.

## Falsifier

A config key whose accessor default, override or Verifier refusal regresses fails its
literal-titled test; deleting any test title makes the gate report MISSING for that id.
