# Wave 2 lane qs: query schema (sort, pagination, results)

Standing: PASS

## Files

- lib/ash_surface/compiler/query_schema.ex (edited; no sigils added)
- test/ash_surface/query_schema_wave2_test.exs (new, 8 tests incl. node+real zod)

## Delivered

1. Sort prefix `(?:\+\+|--|[+-])?`; node-executed on "++a,--b,-c,+d,e" (accept), "+++a" (refuse).
2. `render_sort_schema/2` with `array?: true` -> `z.union([str, z.array(str)])`.
3. Pagination `default_limit?` (required + default -> limit optional), caller `max_limit`.
   Fallback 500 retained only when no max_limit supplied (documented, not an Ash fact).
4. `render_query_params/1` -> `{:ok, %{sort, page}}`; nil/nil for get or non-read.
5. `render_offset_result_schema/2`, `render_keyset_result_schema/2`,
   `render_page_result_schema/2` (mixed union; non-required `union([array, page])`).
6. `render_typed_query_input_schema/2` (input/page/filter/sort, optional unless `required:`).
7. `QuerySchema.render_get_input_schema/1` is canonical (moduledoc); IdentitySchema not
   edited (not owned) and not diffed against it.

## Commands

`MIX_BUILD_ROOT=_build-qs mix test test/ash_surface/query_schema_test.exs
test/ash_surface/query_schema_wave2_test.exs` -> `13 tests, 0 failures` (exit 0).
Earlier attempts hit other lanes' compile errors (zod_guard.ex sigil, channel_fixtures.ex);
retried until they cleared. `_build-qs` deleted.

## Findings

- Zod 4 `.regex("string")` THROWS at parse (`Cannot create property 'lastIndex' on string`).
  The guard-admitted string spelling must be converted to `new RegExp(...)` at the embed
  site; the test harness does this. Whoever embeds sort schemas (js.ex) must do the same
  or the emitted sort schema is broken at runtime. UNVERIFIED whether js.ex converts.

## UNVERIFIED

- IdentitySchema vs QuerySchema get-input output equivalence.
- Result-shape field nullability vs live ash_typescript output (not diffed).

## Requests

- IR must pass sortable resource fields, not input names, as `sortable_fields`.
- compiler.ex pagination_facts must carry `default_limit` and `max_page_size`.
- Error lane: add `sort_not_supported` / `pagination_not_supported` error types.
- js.ex embed: convert `.regex("...")` to `.regex(new RegExp("..."))`.
