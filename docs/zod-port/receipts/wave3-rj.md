# Wave 3 Lane RJ: manifest_generator_surface_test repair

Standing: PASS

Subject: `test/ash_surface/ported/rpc/b/manifest_generator_surface_test.exs` (skeptic
SK-mutB item 3, NEVER RED incl. `x_present`). Covers
`AshSurface.Manifest.ActionManifest` (`lib/ash_surface/manifest/action_manifest.ex`);
reference test `rpc/manifest_generator_test`. Cause of vacuity: every fixture entry had an
empty description, so `present/1` was unobservable, and the file asserted only
`is_binary`/key presence.

## Change

Test file only: 9 -> 18 tests (new describe "real manifest output": section keys, exact
action key set, action ids/functionName, description fallback + empty override,
enableFilter/enableSort per entry flag, get/pagination/input/hasFields, deprecated forms,
metadataFields, exact Todo relationship capabilities, canonical deterministic bytes +
trailing newline). No lib or ledger edit.

## Commands (scratch /tmp/rj, MIX_BUILD_ROOT=_build-rj; sha256 baseline == restore)

- `mix test <file>`: 18 tests, 0 failures. Siblings json_manifest_generator_surface + gap:
  71 tests, 0 failures, 44 skipped.
- Shim court on action_manifest.ex (RED = this file fails): present_nil, @version,
  enableFilter, enableSort, drop sort, actionType, get_by, pagination offset, input required,
  deprecated true, metadata sort, no trailing newline, destroy hasFields, rel filterable,
  rel sortable, description order: all RED. Restored sha256 b01529d6...068ab == baseline.
- SURVIVORS (disclosed): relationship pagination default `:none` -> `:mixed` and the
  `resource_entry` nil-handle fallback: unreachable with this fixture (equivalent mutants
  here).
- dsl.ex (namespace / field_names puts removed): GREEN by design; ActionManifest output does
  not read `Manifest.Dsl`, so no claim is made for it from this file.
- `mix ash_surface.parity.tests` (scratch): exit nonzero, broken=45 shallow=90, 0 lines
  naming this file; broken rows are pre-existing unindexable-dynamic-test skips elsewhere.
  UNVERIFIED that counts equal the shared-tree baseline.
- Scratch dir NOT deleted (coordinator correction: the lane's `rm -rf` was permission-denied);
  `/tmp/rj`, `/tmp/rj_build`, `/tmp/rj_A.orig`, `/tmp/rj_D.orig` remain until removed.
