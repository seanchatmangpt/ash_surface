# Wave 3 Skeptic Audit: Mutation Court, Unaudited Files (SK-mutC)

Standing: PARTIAL

Lane SK-mutC, read-only on repo. Scratch `/tmp/skmc/base` (tar of explicit paths), build root
`/tmp/skmc/_build`, harness `/tmp/skmc/mut.py` (isolated baseline, mutate, run, restore, sha256
compare; every run below restore=OK). Red = failing test name absent from the file's isolated
baseline. Unaudited set derived by diffing directory listings against paths named in
`wave3-skmuta.md`: 11 top, 1 codegen, 2 resource, 2 manifest. 7 are `*_gap_test.exs` files that
are all `@tag skip` (no runnable body, not mutable). 8 runnable files audited.

## Results

| file | mutation (lib) | result |
|---|---|---|
| top/field_formatting_comprehensive | field_name.ex pascal `camelize(true)`->`false` | RED (0->4) |
| top/union_field_formatting | same | RED (4->6, base-red) |
| top/calculation_field_formatting | same | RED (1->4, base-red) |
| top/typescript_field_names_precedence | same pascal flip | RED (6->10, base-red) |
| top/typescript_field_names_precedence | field_name.ex override-first `{{:ok,wire},_}`->`emitted(name)`; fallback `emitted`->`to_string` | SURVIVED (6 base fails, 0 new) |
| top/codegen_check | n/a | ALREADY-RED (4/4 isolated) |
| resource/map_field_names_utility | naming.ex `trim_leading` removed | RED (0->2) |
| resource/map_field_names_utility | naming.ex regex drops `\?` | RED (0->1) |
| resource/persist_formatted_fields | info.ex drop `public_field?`; formatter given `%{}` overrides | RED (0->1 each) |
| manifest/decorator_surface | action_manifest.ex `enableFilter`->`true` | SURVIVED-VACUOUS (25/0) |
| manifest/decorator_surface | action_manifest.ex `enableSort`->`true` | SURVIVED-VACUOUS (25/0) |
| manifest/decorator_surface | pipeline.ex `show_metadata false -> declared` | SURVIVED-VACUOUS (25/0) |
| manifest/decorator_surface | manifest/dsl.ex drop `field_names` put | RED (0->2) |

## Repair requests

- manifest/decorator_surface_test.exs: survivors `enable_filter?`->true, `enable_sort?`->true
  (action_manifest.ex), `show_metadata: false` returns declared (pipeline.ex
  `exposed_metadata_fields`). Tests `no_filter`/`no_sort`/`meta_false` projections are declared
  but their decorated outputs are never asserted.
- top/typescript_field_names_precedence_test.exs: override-wins-over-formatter in
  `FieldName.wire/3` and `emitted` fallback survive; the 9 green tests do not pin them (6 are
  already red at baseline, owner repairing).
- top/codegen_check_test.exs: 4/4 red at baseline, not mutation-testable.
