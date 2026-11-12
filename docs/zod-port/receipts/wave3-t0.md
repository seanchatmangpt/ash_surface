# Wave 3 Lane T0 Receipt

Standing: PARTIAL

Test-port ledger and inventory gate built and live; the gate exits 1 by design until the
T1..T17 lanes account for the 223 unaccounted files. Reference
`~/ash_typescript` HEAD `5d6e80aec1afcbabaf0831768c210fecd81bd869`.

## Summary counts (real gate output)

`parity-tests: files=264 ported=0 adapted=28 skipped_gap=13 non_goal=0 unaccounted=223
broken=0 shallow=0`

## Commands (MIX_BUILD_ROOT=_build-t0, MIX_ENV=test, build seeded by copying `_build`)

| command | rc | result |
|---|---|---|
| `mix ash_surface.parity.tests --regenerate-inventory` | 0 | wrote 264 files |
| `mix ash_surface.parity.tests --check-inventory` (un-piped) | 0 | identical, 264 files |
| `mix ash_surface.parity.tests --summary` | 1 | counts above |
| `mix test test/ash_surface/parity_tests` | 0 | 22 tests, 0 failures |
| `mix test` no_local_do_test + mock_discipline + parity_tests | 0 | 29 tests, 0 failures |
| `mix format --check-formatted` on all changed files | 0 | clean |

## Per-directory table (seed state)

| directory | files | adapted | skipped_gap | unaccounted |
|---|---|---|---|---|
| test/ash_typescript | 25 | 0 | 0 | 25 |
| test/ash_typescript/codegen | 8 | 0 | 4 | 4 |
| test/ash_typescript/manifest | 7 | 4 | 0 | 3 |
| test/ash_typescript/resource | 7 | 0 | 0 | 7 |
| test/ash_typescript/resource/transformers | 1 | 0 | 0 | 1 |
| test/ash_typescript/rpc | 106 | 0 | 0 | 106 |
| test/ash_typescript/rpc/codegen/helpers | 1 | 0 | 0 | 1 |
| test/ash_typescript/rpc/verify_action_types | 9 | 0 | 9 | 0 |
| test/ash_typescript/typed_channel | 6 | 0 | 0 | 6 |
| test/ash_typescript/typed_controller | 8 | 0 | 0 | 8 |
| test/mix_tasks | 1 | 0 | 0 | 1 |
| test/ts | 12 | 0 | 0 | 12 |
| test/ts/custom | 2 | 0 | 0 | 2 |
| test/ts/shouldFail | 17 | 8 | 0 | 9 |
| test/ts/shouldPass | 42 | 16 | 0 | 26 |
| test/ts/valibot/{shouldFail,shouldPass} | 4 | 0 | 0 | 4 |
| test/ts/zod/{shouldFail,shouldPass} | 8 | 0 | 0 | 8 |

## Design facts

- Inventory = 179 `*_test.exs` (AST walk; 2754 tests, 754 describes, equal to the Q1
  advisory) + 85 `test/ts/**/*.ts` (line scan; 847 titles). `test_helper.exs` is not a test.
- Skip detector is AST based (`@tag`/`@moduletag`/`@describetag` in all forms incl. multi-line
  continuation and keyword lists, bodiless `test`, `ExUnit.start/configure(exclude:)` in the
  file or `test/test_helper.exs`); `.skip(`/`todo`/`{skip: ...}` for `.test.mjs`.
- Seeded rows come only from lane receipts wave3-06/07/08 with evidence paths; no row is
  `ported` (none provable). Adapted TS rows are name-matched per wave3-06 (bodies original,
  not diffed line-by-line: noted in each row).
- Partially covered mixed files stay `unaccounted` with a `note` (a file with a loud skip
  cannot back a ported/adapted row).
- Orphan and duplicate ledger rows count in `broken`; `shallow` is a warning only.

## Non-vacuity

`test/ash_surface/parity_tests/gate_non_vacuity_test.exs`: deleted ledger row, ported row at a
missing file, multi-line `@tag skip` continuation, skipped_gap without tag text / without the
skip / without gap, fake README quote, orphan row, ts-ported and empty-changes, unreadable
ledger/inventory, fake inventory (byte-compare drift against a temp reference tree), sha256
restore, corrupt-restore self-check, and a shim the gate accepts raising `VACUOUS GATE`.

## Files changed (all new)

- lib/mix/tasks/ash_surface.parity.tests.ex
- lib/ash_surface/parity_tests/{inventory,skips,report}.ex
- parity/test_inventory.json (generated), parity/test_ledger.json (seeded)
- test/ash_surface/parity_tests/{gate_non_vacuity,skips}_test.exs
- docs/zod-port/TEST-PORT-PLAN.md, docs/zod-port/receipts/wave3-t0.md

## UNVERIFIED

- Full `mix test` not run; adapted-row semantic equivalence (gate checks structure only).
- Seeded TS adaptations rely on wave3-06's own claim that those cases are covered.

`_build-t0` deleted.
