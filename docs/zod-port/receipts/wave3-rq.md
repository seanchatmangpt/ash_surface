# Wave 3 RQ: typed_structs unknown-name test (atom vs string)

Standing: PASS

Lane RQ. Build root `_build-rq` (deleted at finish).

## Finding

Lib did not change. `resolve_field_name` -> `FieldName.parse_input/2` uses
`String.to_existing_atom`, falling back to the string; the reference
(`~/ash_typescript` `FieldFormatter.parse_input_field`) does the same. The test's `"bogus"`
resolves to `:bogus` whenever any other loaded module/test created that atom (atom table is
VM-global), so the assertion was order-dependent. The test was wrong; no lib edit, no divergence.

## Edit

`test/ash_surface/ported/rpc/rfp/requested_fields_processor_typed_structs_test.exs`: the unknown
name is now runtime-built (`"no_such_field_<unique_integer>"`), never an atom.

## Mutations (RD set, field_selector.ex sha256 e3b3a6aa...5c3b7, restored byte-exact)

Deviation: the repo-copy scratch was refused by the topology hook, so mutations ran in place
with sha256-verified restore (not a scratch copy). Both rfp files, 49 tests:
requires_field_selection throw removed RED (1); reverse_map forced %{} RED (1);
typed-struct check_for_duplicates removed RED (1). Restored: 49 tests, 0 failures.

## Gates

- rfp dir + no_local_do: rc=0, 250 tests, 0 failures.
- `mix test test/ash_surface/ported/rpc test/ash_surface/no_local_do_test.exs`: first run rc=2
  (2 failures, `action_not_found`, other lanes' in-flight edits, not this file); rerun rc=0,
  1786 tests, 0 failures, 213 skipped.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.
