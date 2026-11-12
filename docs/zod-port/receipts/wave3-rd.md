# Wave 3 Repair RD: requested-fields typed_structs and relationships

Standing: PASS

Lane RD. Subject: tree at HEAD e3b5d7ffe plus uncommitted edits. Build root `_build-rd`
(deleted at finish). Source: skeptic receipt `wave3-skmuta.md` items 10 and 11.

## Edits (tests only, no lib change)

- `test/ash_surface/ported/rpc/rfp/requested_fields_processor_typed_structs_test.exs`: new describe
  calling public `FieldSelector.select_typed_struct_fields/4` directly on the real resolved
  `TodoStatistics` type (4 tests: duplicate, empty selection, wire-name reverse map, unknown
  string name).
- `test/ash_surface/ported/rpc/rfp/requested_fields_processor_relationships_test.exs`: new describe
  sending filter/sort/page/limit/offset/args through `RFP.process` (real manifest, non-actuating:
  inspects the built `Ash.Query`; no Ash.read/create/update/destroy). Covers to-one, non-rel,
  page+limit, empty fields, disabled flags, and unfilterable/unsortable/unpaginated fixtures.

## Shim court (field_selector.ex backup /tmp/rd/base.ex, sha256 e3b3a6aa...5c3b7)

Mutation then restore, per mutation, `mix test` of both files (49 tests after final edit):

| mutation | result |
|---|---|
| rfp-12 empty-selection throw removed | RED 1 failure |
| rfp-12b reverse_map forced %{} | RED 1 |
| rfp-12c reverse lookup forced nil | RED 1 |
| rfp-12d duplicate check removed | RED 1 |
| rfp-10 to-one throw removed | RED 1 |
| rfp-10b args throw removed | RED 1 |
| rfp-10c filterable gate false | RED 1 (after adding fixture test) |
| rfp-10d pagination gate disabled | RED 1 (after adding fixture test) |
| sortable gate false | RED 1 |
| rfp-10e raise at top of validate_query_opts! | RED 8 |

Restore sha256 equals baseline (checked). Restored run: 49 tests, 0 failures.

## Gates

- `mix test` both files (`MIX_BUILD_ROOT=_build-rd`): 49 tests, 0 failures.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.
- `test/ash_surface/no_local_do_test.exs`: 5 tests, 0 failures.
- Not run: full suite.
