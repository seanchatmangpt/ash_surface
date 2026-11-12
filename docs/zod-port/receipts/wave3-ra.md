# Wave 3 RA: Repair of Vacuous Ported Tests

Standing: PASS

Lane RA (build root `_build-ra`, deleted at finish). Repairs for SK-mutA findings (top-17, top-19, top-21).
Re-run on current tree before edits: 30 tests, 0 failures (tests were green, i.e. vacuous under mutation).

## Edits (test files only; no lib change)

- field_formatter_struct_clause_test.exs: +1 test, `?` stripped under snake/camel/pascal and via resource path.
- empty_manifest_codegen_test.exs: asserts one `.mjs` artifact with non-empty code, `action_count == 0`,
  `namespace_count == 0` (was `is_map`).
- resource_schema_mapped_fields_test.exs: +1 test, `ResourceFacts` `public_attributes` contains
  `isArchived`, not `archived?`.

## Shim-court (scratch copy `/tmp/ra`, sha256 baseline == restore: yes for all three)

| mutation | before | mutated | restored |
|---|---|---|---|
| field_name.ex `clean/1` drops `?` strip | rc=0, 4 tests 0 fail | rc=2, 1 failure | rc=0, 0 fail |
| projectors/js.ex `emit(...)` -> `{:ok, %{}, %{}}` | rc=0 | rc=2 | rc=0 |
| resource_facts.ex `wire_name` -> `emitted(name)` | rc=0, 25 tests 0 fail | rc=2, 1 failure | rc=0, 0 fail |

## Gates

- `mix test` on the three files: exit 0, 30 tests, 0 failures (before the shim-court runs).
- `mix ash_surface.parity.tests`: exit 0, unaccounted=0 broken=0.
- Not run: the other 22 mapped-field tests were not individually mutation-checked (UNVERIFIED);
  the repair adds one fact-level court that carries the mutation.
