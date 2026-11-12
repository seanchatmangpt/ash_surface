# Wave 3 Lane RR Receipt

Standing: PASS

RR proved non-vacuity of lane RN's `EmittedKeys.check_resource_graph/1` courts by mutation
on a scratch copy (/tmp/rr, build root `/tmp/rr/_build-rr`, sha256 baseline == restore for
`compiler.ex`, `emitted_keys.ex`). Two mutations survived the original 2-test file; three
courts were added to
`test/ash_surface/compiler/emitted_key_collision_cross_section_test.exs` (5 tests now).

## Mutations (file under test: 5 tests, `mix test <file>`)

| mutation | original 2 tests | final 5 tests |
|---|---|---|
| m0 revert `check_resource_graph` call in compiler.ex | 2/2 red (exactly SK-fw inputs) | 4 failures |
| m1 skip calculation arguments | red | 1 red |
| m2 skip aggregates | SURVIVED | 1 red (destination aggregate court) |
| m3 skip identity keys | SURVIVED | 1 red (private attrs, identity court) |
| m4 skip resources without the surface extension (destination-only) | red | 2 red |
| m5 depth 1 (root only, no relationship walk) | red | 2 red |
| m6 depth 2 (walk stops after first hop) | SURVIVED (not in original list) | 1 red (Top->Mid->Kid court) |

Survivor cause: root-resource aggregates are already covered by `FieldName.action_inverse`,
so the aggregate court places the collision on a destination resource; identity keys over
public attributes collide in the field table first, so the identity court uses private
attributes.

## Commands

- Baseline and restored: file `mix test` rc=0 (un-piped), 5 tests, 0 failures.
- Canonical tree, scratch build root: `mix test <file>` rc=0, 5 tests, 0 failures.
- Canonical tree: `MIX_ENV=test mix ash_surface.parity.tests` rc=0, unaccounted=0 broken=0.

## UNVERIFIED

Identity court emits an Ash `pre_check_with` DSL warning (not an error); m0-m6 run on the
scratch tree only, not on canonical `_build`. m4 proxies "no compiled actions" as "no
AshSurface.Resource extension".
