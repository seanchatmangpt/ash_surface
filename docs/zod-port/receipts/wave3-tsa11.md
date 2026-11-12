# wave3-tsa11

Standing: PASS

Lane TSA-T11: adapt the TypeScript-text loud skips of `test/ash_surface/ported/rpc/d/*_gap_test.exs`
to Zod/IR/pipeline behavior assertions. 44 skips converted, 0 TypeScript-syntax-only tests remain,
no `non_goal` proposed or marked. Gap files deleted: rpc_identities, rpc_mapped_identity_fields,
sort_and_filter_types, struct_argument, struct_argument_integration.

## Converted vs remaining

| reference file | tests | disposition | new file |
|---|---|---|---|
| sort_and_filter_types (TS half) | 32 | BEHAVIORAL-COUNTERPART-FOUND | sort_and_filter_types_ir_surface_test.exs |
| rpc_identities | 4 | BEHAVIORAL-COUNTERPART-FOUND | identity_and_struct_shapes_surface_test.exs |
| rpc_mapped_identity_fields | 2 | BEHAVIORAL-COUNTERPART-FOUND | identity_and_struct_shapes_surface_test.exs |
| struct_argument_integration | 3 | BEHAVIORAL-COUNTERPART-FOUND | identity_and_struct_shapes_surface_test.exs |
| struct_argument (gap) | 3 | BEHAVIORAL-COUNTERPART-FOUND | identity_and_struct_shapes_surface_test.exs |

TS-SYNTAX-ONLY remaining: none. Each assertion proves a shape or field-set claim that has an
admission counterpart: sortable/filterable sets (`ResourceFacts`), sort schema and `ir.schema.filter`
under node+zod, per-action `enable_sort?`/`enable_filter?` refusals, identity forms through
`Pipeline.resolve_identity/1`, struct argument shape through `ir.schema.input` and the emitted zod.

## Behavior notes

- Operators asserted per kind with the surface spelling (`eq`, `gt`, `is_nil`), not camelCase TS keys.
- Struct argument zod is `z.record(z.string(), z.unknown())` with IR kind `resource`/`instance_of`
  User, not a per-field User input object (divergence, recorded in the ledger row; no lib change).
- Mapped identity: client names (`userId`, `isActive`) resolve; partial maps and operator-map values
  are refused. Raw Ash names (`user_id`, `is_active?`) also resolve (observed, not asserted).
- F1-fieldwire receipt `wave3-f1fw.md` was absent throughout; the mapped-name tests assert the
  pipeline, not schema keys, so they do not depend on it.

## lib edit (disclosed)

`lib/ash_surface/compiler/resource_facts.ex` aggregate filter entry nullability:
`agg.kind != :count` became `agg.kind not in [:count, :exists, :list]`. Defect proved by the adapted
tests: `:exists` and `:list` aggregates were marked nullable, so `is_nil` was admitted on a value that is
never nil (reference: no isNil for :exists, :list, :count). Regression run over
`ported/top/typescript_filter_test.exs` and `typescript_sort_test.exs`: 0 failures.

## Commands (MIX_BUILD_ROOT=_build-tsa11 MIX_ENV=test, deleted afterwards)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/d test/ash_surface_mock_discipline_test.exs test/ash_surface/no_local_do_bang_court_test.exs` | 0 | 244 tests, 0 failures, 2 skipped (rpc_validate_action_read_action_gap, other lane scope) |
| `mix test` the two new files | 0 | 40 tests, 0 failures |
| `mix test` new sort file + typescript_filter_test + typescript_sort_test | 0 | 67 tests, 0 failures |
| `mix format --check-formatted test/ash_surface/ported/rpc/d/*.exs lib/ash_surface/compiler/resource_facts.ex` | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 (gate, other lanes) | `files=264 ported=9 adapted=183 skipped_gap=39 non_goal=19 unaccounted=0 broken=14 shallow=77`; zero listed rows under my files |

Grep for `Process.sleep`, `Mox`, `mock(` over both new files: zero matches.

## Ledger

`parity/test_ledger.json`: 5 T11 rows edited by targeted replacement (new test file added to
`ash_surface_tests`, stale gap-file sentences removed, counts updated); JSON re-validated.

## Operator decisions

None required: no README-only skip remained, so no PROPOSED non_goal (README.md:29 not invoked).
Open: whether struct-argument resources should get a typed per-field zod object instead of a record.

Falsifiers: not run as shim courts (UNVERIFIED): reverting the `resource_facts.ex` edit should fail
the `:exists`/`:list` is_nil refusal cases in sort_and_filter_types_ir_surface_test.exs.
