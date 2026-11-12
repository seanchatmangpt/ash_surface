# Wave 3 Lane GU-T2 Receipt

Standing: PARTIAL

Lane GU-T2: implemented the capabilities behind T2's loud skips, converted the tests, kept accurate
loud skips for the rest. 24 skips in six `*_gap_test.exs` files became 7 (17 converted, 0 failing
in the converted files). Reference: `~/ash_typescript` @ 5d6e80ae. Nothing here actuates
(README: never actuates, no `.ts`): every conversion is an executed node + real zod court or an
Elixir assertion on compiler output.

## Converted (17) and still skipped (7)

| gap file (test/ash_surface/ported/top/) | was | converted tests now in | still skipped |
|---|---|---|---|
| typescript_filter_gap_test.exs | 5 | typescript_filter_test.exs: string ordered gt/gte/lt/lte; enum/atom eq/neq/in narrowed to `one_of`; relationship filters (author, comments, `related`); whole-array eq/in | 1: operator-name formatting (notEq/stringStartsWith), operator keys are the surface spelling |
| typescript_sort_gap_test.exs | 2 | typescript_sort_test.exs: formatter on sort names; mapped names (`is_active?` -> `isActive`). Gap file deleted | 0 |
| union_field_formatting_gap_test.exs | 3 | union_field_formatting_test.exs: pascal/camel/snake union member and attribute keys. Gap file deleted | 0 |
| typescript_field_names_precedence_gap_test.exs | 4 | typescript_field_names_precedence_test.exs: formatter on unmapped emitted keys, mapped verbatim (pascal, snake) | 3: valibot (README: Zod only), typed controller result types, Rpc.run_action envelope (README: never actuates) |
| resource_schema_mapped_fields_gap_test.exs | 4 | resource_schema_mapped_fields_test.exs: record schema with mapped keys; embedded resource with mapped keys | 2: `__type`/`__primitiveFields` TS discriminators; per-action input Zod keys (FieldName not wired into the action input compiler, parity debt w3-15) |
| typescript_codegen_gap_test.exs | 6 | typescript_codegen_test.exs: selected fields; primitive-field set; complete Todo record schema; embedded references; complete TodoComment record schema | 1: `untyped_map_type` (TS-only key) |

Skip text of the 7 remaining is the unchanged capability text in the gap files; none was classified
`non_goal` (no README sentence supports it verbatim; operator decision list below).

## lib edits (small targeted Edits after re-reading; files are shared with running lanes)

1. NEW `lib/ash_surface/compiler/record_schema.ex`: `RecordSchema.render/2` per-resource record Zod
   (public attributes required/nullable, argument-less calculations and aggregates optional,
   relationships optional record references, embedded resources through
   `EmbeddedSchema.render_program/2`, `field_names` verbatim). Not wired into IR (`response_zod`
   stays nil), so no IR/vector change from it.
2. `compiler/filter_schema.ex`: string catalog gains gt/gte/lt/lte; array catalog gains whole-array
   `eq`/`in`; enum/atom entries with `values` narrow eq/neq/in to `z.enum([...])`; relationship
   rendering restructured into an adaptive ladder (`render_adaptive/3`, limit 450 KB): destinations
   with nested logical levels, then leaf-only destinations, then related variants only at top level
   plus one logical level. Reason: related entries multiplied filter size so the whole-domain compile
   exceeded the 60 s test timeout (ZodGuard check is superlinear); F1-divclose behavior (related
   destination nested and/or/not, 5x10 fixture) is unchanged below the limit.
3. `compiler/resource_facts.ex`: `field_names` applied to sortable fields and filter entry names;
   relationship entries (public relationships with scalar-kind destination attributes);
   `values` carried for enum/atom entries.
4. `compiler/type_facts.ex`: `expand_embedded` applies the embedded resource's `field_names`
   (marked `"wire" => true`).
5. `compiler/embedded_schema.ex`: `select:` option, `primitive_fields/2`, `"wire"` marker, key
   formatting through `FieldName.emitted/1` for unmapped keys.
6. `compiler/union_schema.ex`: member keys through `FieldName.emitted/1`.
7. `field_name.ex`: `FieldName.emitted/1` (explicit `:ash_surface, :output_field_formatter` only).

Test-side: `support/t2.exs` gained `record_zod/2`, `node_probe/2`; its tmp dirs now carry the OS pid
(the old `unique_integer` name collided with stale dirs from earlier VMs: `File.LinkError`).
Pins updated for substrate changes: `typescript_codegen_test.exs` default open record is
`z.unknown()` (another lane changed `z.any()`), embedded keys in `resource_schema_mapped_fields_test.exs`,
`array eq` pin in `typescript_filter_test.exs`, `filter_schema_size_test.exs` oversize case 120 -> 600
relationships (the ladder now keeps 120 under the cap; the cap itself still fires).
Three test files that set `:output_field_formatter` are `async: false`.

## Commands (MIX_ENV=test MIX_BUILD_ROOT=_build-gu2) and exit codes

| command | rc | result |
|---|---|---|
| mix test the 6 converted surface files + 4 gap files + filter_schema_size/filter_schema + divergence_close + mock_discipline + no_local_do | 2 then fixed | final pass before the last two edits: 185 tests, 1 failure (my relationship test, fixed) |
| mix test typescript_filter_test.exs (after fix) | 0 | 27 tests, 0 failures |
| mix test the 4 gap files | 0 | 7 tests, 0 failures, 7 skipped |
| mix test test/conformance | 2 | 28 tests, 2 failures (vector drift, see below) |
| mix ash_surface.parity.tests --summary | 0 | `files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=94` |
| mix format --check-formatted on every touched lib and test file | 0 | clean |
| grep Process.sleep / Mock / mockall / monkeypatch over the six surface test files + t2.exs | 1 | zero matches |

The last full-dir run (`ported/top compiler divergence_close projectors`) did not finish inside its
timeout on a load average of ~100; other-lane failures seen there and not introduced here:
`filter_mapped_fields_test` / `non_field_calculation_test` (T1/F1-fieldwire, were being edited
concurrently; their 60 s timeouts came from the pre-ladder filter sizes, `t1_3` stale tmp dir
`File.LinkError` in T1's helper), `schema_section_test:311`, float bounds, union `__proto__` tags
(prior receipts). Not re-run to green after the ladder: UNVERIFIED for those files.

## Conformance vectors (report, not regenerated; FINAL-REGEN owns)

`test/conformance` fails 2: `filter_operators.json`, 10 vectors drift (string ordered ops, array
eq/in, relationship entries in the Zod text and verdicts, e.g. `fo/string-eq`). Any kind rendering
filter schemas, field_names-mapped sort/filter names, or embedded keys is affected.

## Divergence-law ledger

- No KD row added. Nothing here is a witnessed better-than-reference behavior.
- Divergences that remain (parity debt, not claimed better): emitted Zod keys use the Ash name
  unless `:output_field_formatter` is set explicitly (reference default is camelCase; ash_surface
  `Config.output_field_formatter/0` still defaults to `:camel_case` for client-name resolution
  only); related filter destinations are scalar kinds only and degrade under the size ladder;
  relationships in the record schema are open record references.

## Operator decisions

- Whether emitted keys should follow `Config.output_field_formatter/0` by default (reference parity,
  moves every key and every vector) or stay opt-in as implemented.
- The 7 remaining skips: valibot/typed controller/Rpc envelope could be README non-goals if a
  verbatim sentence is added; `untyped_map_type` and `__type`/`__primitiveFields` are TS-only.

## Concurrency and cleanup

Compile and ledger edits were targeted; a ledger text-replace per T2 row (`changes` only, JSON
re-validated). `typescript_filter_gap_test.exs` vanished mid-lane (not by this lane's action) and
was re-created with its one remaining skip. `_build-gu2` deleted at completion; no git state
commands run.

## Falsifiers

- A converted case that passes without exercising the lib edit: each was written to fail before the
  edit (the gap tests asserted the capability missing); the string-ordered, enum, relationship and
  array cases fail if `FilterSchema`/`ResourceFacts` edits are reverted.
- The ladder under-degrades: whole-domain IR compile (130 IRs) took 20-40 s on a loaded host
  against a 60 s default test timeout.
