# Wave 3 CX: emitted-key collision refusal

Standing: PARTIAL

PASS evidence: test/ash_surface/compiler/emitted_key_collision_test.exs and
test/ash_surface/adversarial/container_renderers_adversarial_test.exs, 59 tests, 0 failures
(`MIX_BUILD_ROOT=_build-cx mix test <both files>`, rc=0).

## Change

- New `lib/ash_surface/compiler/emitted_keys.ex`: `check/2` returns
  `{:error, {:emitted_key_collision, container, key, [names]}}` for distinct names that
  emit one key; exact duplicates are not collisions.
- Wired (small edits): `embedded_schema.ex` (`render_fields` precheck), `union_schema.ex`
  (`do_members` precheck, `render_each` split out).
- CV's dedup in the union adversarial case replaced by an assertion of the refusal.

## Findings

- Resource-level fields (record, filter, sort, calculation, route inputs derive from
  resource facts) are already refused by KD-09 `field_name_collision`.
- Open container defs (embedded/typed-map fields, union members) silently dropped one key:
  now refused.
- Reference ash_typescript also refuses colliding names (manifest verifiers, e.g.
  verify_unique_input_field_names), so this is parity, no KD row added.

## Commands

- `mix test test/ash_surface/compiler test/ash_surface/adversarial`: rc=2, 437 tests,
  2 failures, both pre-existing/unrelated (embedded_schema_test "default?" key stripped by
  the formatter; struct_argument_zod_court_test allow_nil), neither mentions collision.
- `mix ash_surface.parity`: rc=1, total=403 pass=302 divergence=12 non_goal=79 broken=0
  missing=10 (missing unchanged by this lane: UNVERIFIED against baseline).
- Calculation/route/filter/sort/channel renderers not separately probed with raw
  colliding defs: UNVERIFIED.
