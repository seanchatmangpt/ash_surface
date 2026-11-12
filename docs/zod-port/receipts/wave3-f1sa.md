# wave3-f1sa

Standing: PASS

Lane F1-structarg: a struct argument with `instance_of: Resource` now renders a per-field strict Zod
input object instead of `z.record(z.string(), z.unknown())`. No KD row added: the behavior matches
the reference rule (no better-than-reference deviation).

## Reference rule (ash_typescript codegen/schema_core.ex generate_schema_impl)

A resource used as a struct argument is rendered from ALL its public attributes (kind `:attribute`),
each with its type, `nullable = allow_nil?`, `omittable = allow_nil? or has_default?`. A `fields`
constraint struct (no instance_of) already rendered per-field through the existing container path.

## Change (one targeted lib edit)

`lib/ash_surface/compiler/type_facts.ex`: `collect/2` now also expands IR kind `resource` (with
`instance_of`) via `expand_embedded(name, acc, false)` (all public attributes; the embedded path keeps
the writable-only filter). Rendering reuses `EmbeddedSchema.render_program/2` unchanged: members,
strictness, nullability, and cyclic `instance_of` through named consts (KD-02) come from that machinery.

## Tests

- New `test/ash_surface/compiler/struct_argument_zod_court_test.exs` plus fixture
  `test/support/zod_fixtures/struct_arg.ex` (self-referential Node, Holder.take with instance_of,
  nullable instance_of, and fields-constraint arguments). Executed node+zod: valid accepted; unknown
  key, wrong member type, null/missing required member, member bound violation refused; allow_nil
  argument accepts null/omission; cyclic instance_of validated at depth 3 (named const, ZodGuard
  admitted); fields-constraint struct per-field with bounds and nullable member.
- Tightened `ported/rpc/d/identity_and_struct_shapes_surface_test.exs`: assignee object is strict,
  refuses `{}` (name/email required), unknown/`__type` keys, wrong member types; no record fallback.
- `parity/test_ledger.json`: both T11 struct_argument rows' `changes` updated (targeted Edits, JSON valid).

## Commands (MIX_BUILD_ROOT=_build-f1sa MIX_ENV=test, directory deleted afterwards)

| command | rc | result |
|---|---|---|
| mix test struct_argument_zod_court_test + identity_and_struct_shapes_surface_test | 0 | 17 tests, 0 failures |
| mix test test/ash_surface/compiler ported/rpc/d projectors mock_discipline no_local_do_bang_court | 2 | 634 tests, 2 failures, 4 skipped; both in FilterSchemaSizeTest (another lane's untracked filter_schema.ex), none in my files |
| mix format on touched files | 0 | clean |

Grep Process.sleep, Mox, mock( over the three new/edited test files: 0 matches.

## Pending (not run, per instruction)

IR digest and conformance vectors move for any surface with a resource-typed struct argument:
report only, regeneration deferred to FINAL-REGEN.
