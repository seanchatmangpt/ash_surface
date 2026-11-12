# Wave 3 Lane RAO: nested mapped names in typed_query

Standing: PARTIAL

Subject: typed_query nested levels (RAN follow-up) plus skmutf typed_query survivors T1-T5.

## Change

- `lib/ash_surface/runtime_parity/rpc/typed_query.ex`: each nested level resolves names through
  its destination (relationship destination, embedded/struct calculation type, array item,
  NewType subtype, union member resource); union member tags stay camelCase. One format per
  name, in `client_field/2` only.
- New `test/ash_surface/ported/rpc/rao/nested_mapped_names_test.exs` (7 tests): real
  Item/Owner/Badge/TextBlock graph, all mapped spellings differ from computed. Red before the
  lib change (`unknown_field ownerName1`).

## Survivor 4 (format_field_for_client -> compute)

Reachable, not dead: atom-resource clause of `FieldFormatter.format_field_for_client/3` and
`FieldName.format_field_for_client/3` are called by pipeline/support/field_formatter and tested
in `ported/top/filter_mapped_fields_test.exs`. Pipeline uses the Manifest.Resource clause, which
is why RAN's file missed it. Test added; no deletion candidate.

## Mutations (disk, sha256 restored byte-exact; rao dir 7 tests)

M1 dest nil: 5 red. M2 union member nil: 4 red. M3 relationship skipped: 5 red.
M4 T5 resource arg dropped: 4 red. M5 T1 sort desc: 1 red. M6 T3 action nil: 1 red.
M7 FieldName.format_field_for_client -> compute: 1 red.
M8 (drop union-level format clause): equivalent mutant (falls to camel_case), survives by design.

## Gates

- `mix test test/ash_surface/ported/rpc` rc=2: 1973 tests, 1 failure, pre-existing/other lane:
  `rpc/d/runtime_source_of_truth_ast_guard_test.exs:327` flags `field_selector.ex` dot access
  (`:enable_filter?`/`:enable_sort?`); file not touched by RAO.
- `mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0).
- `_build-rao` never created; scratch /tmp/rao only.
