# Wave3 RB repair receipt

Standing: PARTIAL_ALIVE

Lane RB, build root `_build-rb` (deleted after). Repairs of SK-mutA vacuous items 4 and 9.

## Commands and results
- Pre-state: `mix test` on both files: 13 tests, 0 failures (exit 0); mutants A-E below
  already killed except C, so item 4 was partly stale.
- verify_mappable_types_surface_test: added "container kinds are not unmappable" (union, typed
  map, embedded resource attributes admitted). Shim-court on `resource/verifiers/checks.ex`
  (sha256 baseline == restore 5af97623...): `kinds != []`->`false` RED 4/7; unmappable
  filter->`[]` RED 4/7; drop `@container_kinds` reject RED 1/7 (was GREEN 0/6 before the
  add); analyze(:string) RED 4/7; `kinds = []` RED 4/7; restored 7 tests 0 failures.
- persist_resource_lookups_surface_test: 6 Ash-accessor tests replaced by 6 tests on
  ash_surface output (action_ids, per-action custom id/profile, decorated lookups, root
  custom.ash_surface, profile placement, digest). Shim-court on `lib/ash_surface.ex`
  (sha256 baseline == restore 640abed8...): decorate_manifest bypass RED 3/6; action custom
  drop RED 2/6; action profile RED 1/6; root custom drop RED 2/6; root profile RED 1/6.
  Surviving: `Enum.sort()` removal on action_ids (GREEN; Ash already yields sorted
  entrypoints here, likely equivalent mutant; UNVERIFIED).
- Both files: 13 tests, 0 failures. `mix ash_surface.parity.tests`: exit 0, unaccounted=0 broken=0.
- No lib edits; no ledger edits.
