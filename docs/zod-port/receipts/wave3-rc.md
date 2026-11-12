# Wave 3 Repair Lane RC

Standing: PARTIAL

Subject: dirty tree at HEAD e3b5d7ffe + uncommitted lane edits. Build root `_build-rc` (deleted at end).

## Changes (test files only; no lib edits)

- `typescript_filter_test.exs`: new describe "operator key mapping" calling real
  `FilterSchema.operator_key/1` (exact Ash->surface map, pass-through keys, `:error` refusal).
  Targets skeptic mutations top-14/14b (`op in []`, `{:ok, "zzz"}`).
- `type_mapping_overrides_test.exs`: new test pinning `Ash.Type.Decimal` -> `z.string()` and
  real node+zod accept "1.50" / reject 1.5 (top-25 mutation). Also re-pinned stale
  `custom_id` -> `customId` (formatter premise moved).
- `custom_types_test.exs`: the 8 lib-free tests now also call `TypeFacts` / `T2.zod` / compiled
  artifact; Ash-cast verdicts are compared to real node+zod under an override. Re-pinned stale
  premises (substrate moved: PriorityScore derives `z.number().int()`, ColorPalette
  `z.record(z.string(), z.unknown())`, no longer `z.unknown()`).
- `ts_action_call_extractor_test.exs`: UNCHANGED. Ledger-row question for coordinator below.

## Commands

- Pre-change run (4 files): 64-test subset red, 11 failures (7 custom_types, 1 overrides, rest stale pins).
- Post-change: `MIX_BUILD_ROOT=_build-rc MIX_ENV=test mix test` on the 3 edited files:
  exit 0, 64 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-rc mix ash_surface.parity.tests`: rc=1 (gate red from 45 broken / 90
  shallow rows in other files; none of this lane's four files is listed).

## Shim-court: UNVERIFIED

Scratch-copy court (tar of lib/test/config into /tmp, mutate, restore, sha256) was denied by the
permission system, and mutating the real tree is barred by contract. Not run. Mutations to run:
filter_schema.ex `op in surface_keys()`->`op in []`; `Map.fetch!(@ash_operator_keys, op)`->`"zzz"`;
zod_type.ex `"decimal" => "z.string()"`->`"z.number()"`; `"uuid" => "z.guid()"`->`"z.string()"`.
The new assertions state the exact mutated outputs, so they are expected red, UNVERIFIED.

## Ledger question (ts_action_call_extractor)

`TsActionCallExtractor` lives only in `test/.../top/support/ts_action_call_extractor.exs`
(grep: no lib/ reference). It is a TS-only test helper with no ash_surface counterpart; its 21 tests
exercise the helper itself. Coordinator decision needed: reclassify the ledger row as non_goal /
helper-self-test rather than fake coverage.
