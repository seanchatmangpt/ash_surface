# wave3-rbe

Standing: PARTIAL

Lane RBE: mapped names under non-default output formatters (RAI observations, mutations E, L).

## Reference behavior (~/ash_typescript 5d6e80a, source read)

- `lib/ash_typescript/rpc/codegen/helpers/action_introspection.ex:176-177`: a mapped argument
  name (`is_binary(mapped)`) is returned verbatim; the formatter applies only to unmapped names.
- `lib/ash_typescript/field_formatter.ex:98-105`: a `field_names` mapping returns "the exact
  string to use - no additional formatting".
- `lib/ash_typescript/rpc/input_formatter.ex:60-100`: input keys resolve via the
  `client_name => internal` map built from `format_input_name/5`.
Mapped names win over every formatter (camel, snake, pascal, `{m,f}`).

## Defect (fixed)

(a) CONFIRMED. `lib/ash_surface/runtime_parity/rpc/pipeline.ex` `check_scoped_name/3`:
`override?` also required `fmt(mapped, ctx.config) != name`, so a mapped name equal to its
Config (camel) spelling (`addressLine1`) fell through and was refused as `unknown_field` under a
snake/pascal scope. Fix: `override? = is_atom(mapped) and not is_nil(mapped)` (single emission,
`reverse_field_name_mappings` holds only declared mappings).
(b) NOT REPRODUCED: `isActive` under `:pascal_case` parses to `%{is_active?: true}` before and
after the fix; RAI's drop was the unmapped `id` field spelled `"id"` under pascal (needs `"Id"`).

## Tests (new): test/ash_surface/ported/rpc/rbe/mapped_names_under_formatters_test.exs

18 tests: User fixture (mapped field + argument) and inline `DocResource` (pure mapped argument
`is_open?` -> `q`, reaches `mapped_argument_name`) through real parse under camel/snake/pascal
scopes, `{m,f}` via `format_input_name`, and ErrorFormatter mapped-vs-unmapped.
Red-first: 2 failures (snake, pascal field) before the fix; 18/0 after.

## Shim-court (scratch /tmp/rbe/s, sha256 baseline == restore each row, baseline 18/0)

| id | mutation | result |
|---|---|---|
| E | `mapped_argument_name` disabled (support.ex) | RED 4 |
| L | ErrorFormatter `format_name` always snake (== `to_string/1`) | RED 2 |
| M3 | revert pipeline fix | RED 2 |
| M4 | `format_input_name` formats mapped arg | RED 2 |

## Verification (live, rc un-piped)

- `mix ash_surface.parity.tests` rc=0, `unaccounted=0 broken=0`.
- `mix test test/ash_surface/ported/rpc` rc=2: 2069 tests, 7 failures, 213 skipped; all 7 in
  `rbf/exposed_and_type_facts_test.exs` (another lane's in-flight file), none in rbe.
- `typed_query` untouched.

## Cleanup

UNVERIFIED: `_build-rbe` and scratch `/tmp/rbe` still exist; `rm -rf` was denied by the
permission layer. Coordinator must delete both.
