# Wave 3 Lane RN Receipt

Standing: PARTIAL

Defects 1 (calc-argument collision) and 2 (destination resource without actions) of SK-fw
fixed; cross-kind attribute/calculation/aggregate/relationship and identity-key collisions
now checked on every reachable resource.

## Change

- `lib/ash_surface/compiler/emitted_keys.ex`: new `check_resource_graph/1` (BFS over public
  relationships from the action's resource; per resource: `FieldName.wire_inverse` over all
  four field kinds, calc arguments via `check/2`, identity keys via `check/2`). Same kernel
  (`FieldName` + `EmittedKeys`), no new spelling logic.
- `lib/ash_surface/compiler.ex` `check_field_names/1`: calls it after `action_inverse`
  (small Edit; disclosed, outside the named file list). Refusals surface as
  `{:section_failed|...}`-free typed `{:emitted_key_collision, ...}` /
  `{:field_name_collision, ...}`.
- Court: `test/ash_surface/compiler/emitted_key_collision_cross_section_test.exs` (SK-fw
  inputs: `pre_fix`/`preFix` calc args; Kid `foo_bar`/`fooBar` with Top.read). 2 tests pass.

## Commands

- `MIX_BUILD_ROOT=_build-rn mix test test/ash_surface/compiler` rc=0, 316 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-rn mix ash_surface.parity.tests` rc=0, unaccounted=0 broken=0.

## UNVERIFIED

Pre-fix red run of the new courts not re-executed this session (SK-fw receipt is the
witness). Argument-vs-attribute on one action: already one table in `action_inverse`
(inputs), no separate check added. SK-fw items 3-6 not in scope.
