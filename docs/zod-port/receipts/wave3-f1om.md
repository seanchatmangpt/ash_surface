# Wave 3 F1-objmode receipt

Standing: PASS

Scope: task 1 (L8 custom formatter test) and task 2 (ObjectMode wiring into renderers).

## Design note

Unset `zod_object_mode` is `:strip` (suffix ""), but every wired site's current output is
`.strict()`, which is the contract. So wired sites take an explicit per-call `:object_mode`
opt via new `ObjectMode.explicit_suffix/1` (nil -> `.strict()`, byte-identical; otherwise
`suffix/1`). `Config.zod_object_mode/0` is deliberately NOT consulted at those sites (it would
change default output); same pattern as IdentitySchema/ErrorSchema from F1-errcfg.

## Task 1

`AshSurface.FieldNameTest.shout/1` lives in field_name_test.exs (load-order dependent). The
test file now defines its own real module `AshSurface.S1IShoutFormatter` and uses it.

## Sites

| site | decision |
|---|---|
| embedded_schema.ex container (empty struct, ~167; fields object, ~243) | wired, opt `:object_mode` |
| relationship_schema.ex load_object, envelope objs, many_arms base/guards, offset/keyset/legacy page objects | wired, opt `:object_mode` via `render_load_schema/2`, `render_load_object/2` |
| calculation_schema.ex args obj, per-calc obj, outer obj | wired, `render_calculation_schema/2` opt `:object_mode` |
| identity_schema.ex | already wired (F1-errcfg) |
| error_schema.ex | already wired (opt `:object_mode`); defaults passthrough/strict are wire contract |
| selection_schema.ex (80, 201, @empty), query_schema.ex (341/342, pagination), route_schema.ex 202 | kept `.strict()`: request-envelope contract, not caller-configurable; unknown keys must refuse |
| union_schema.ex (123-148, 317) | kept `.strict()`: discriminated-member exclusivity depends on it |
| validation_error_schema.ex (107, 165) | kept `.strict()`: error contract keys |
| schema.ex:162 `.passthrough()` | kept: fixed generated-schema form (not altered) |

No default-output change; no conformance vectors change (not regenerated).

## Commands (MIX_BUILD_ROOT=_build-f1om)

- `mix test test/ash_surface/object_mode`: 5 tests, 0 failures (node+zod, all three modes at
  embedded, relationship top/envelope, calculation outer/per-calc/args; ZodGuard.admit on each).
- Regression set (embedded, calculation*, relationship*, object_mode, s1i fieldname,
  no_local_do, mock_discipline): 76 tests, 0 failures, exit 0.
- `mix format --check-formatted` on changed files: exit 0.

## Wait-gate / collisions

wave3-f1r.md existed (embedded edited after). wave3-f1dc.md absent after ~3 min polling;
relationship/calculation edits are small additive threading edits (collision disclosed). I also
ran `mix format` over lib/ash_surface/compiler/*.ex once, which may have touched whitespace in
other lanes' files.

## Files

lib/ash_surface/compiler/{object_mode,embedded_schema,relationship_schema,calculation_schema}.ex;
test/ash_surface/s1i_identity_selection_fieldname_test.exs; test/ash_surface/object_mode/object_mode_wiring_test.exs.
