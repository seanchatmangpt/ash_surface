# Wave 3 F1-kinds receipt

Standing: PASS

Subject: 30 `type.kind.*` and 13 `error.type.*` parity ids mapped to real per-id executed courts.

## Per-id table

Type kinds: `test/ash_surface/parity_kinds/type_kinds_test.exs`, one test per kind titled
`type.kind.<kind> renders` (lines 30-onward, in alphabetical-ish order of the table). Assertion:
`ZodType.fragment/1` equals a HAND-WRITTEN expected text (table `@expected`, from
~/ash_typescript zod_schema_generator.ex) AND accept/reject payloads agree under real zod
(node, `test/ts/kinds_runner.mjs`). Kinds: any atom binary boolean ci_string date datetime
decimal duration duration_name file float function integer keyword map module naive_datetime
string struct term time time_usec tuple url_encoded_binary utc_datetime utc_datetime_usec uuid
uuid_v7 vector.

Error types: `test/ash_surface/parity_kinds/error_types_test.exs`, one test per type titled
`error.type.<type> wire output`. Assertion: real Ash struct through `Errors.to_errors/2`
yields type, shortMessage, fields, path, vars, details (`%{}` for table errors; unknown_error is
the generic UUID-tagged redaction with `details.errorId`); `ErrorSchema.variant/1` parses the
wire output under real zod and rejects a wrong `type` literal. Types: forbidden forbidden_field
invalid_argument invalid_attribute invalid_changes invalid_keyset invalid_page
invalid_primary_key invalid_query not_found required tenant_required unknown_error. Extra test:
forbidden is redacted to message "forbidden".

court_map.json: `type.kind.*` and `error.type.*` rewritten to `test` rows with `{leaf}` titles
(`type.kind.{leaf} renders`, `error.type.{leaf} wire output`); explicit ids unchanged.

## Divergence candidates

- time / time_usec: ash_surface `z.iso.time()` vs reference `z.string().time()` (z.iso.time is
  the zod 4 form; probable better).
- map/keyword/tuple/struct: `z.record(z.string(), z.unknown())` vs reference `z.any()` value.
- naive_datetime `z.iso.datetime({local: true})` and uuid `z.guid()` already documented as
  better than reference in zod_type.ex comments.
- invalid_argument wire message contains trailing "\n\nnil\n" (Ash message quirk, not asserted).

## Commands

- `mix test test/ash_surface/parity_kinds test/ash_surface/no_local_do_test.exs`: exit 0, 49 tests, 0 failures.
- `mix format --check-formatted test/ash_surface/parity_kinds/*.exs`: exit 0.
- `mix ash_surface.parity` (exit 1 from other lanes): type section 0 -> 39 pass (missing 30 -> 13,
  remaining are type.aggregate.* and type.kind.count/sum); error section 13 missing -> 0 missing
  (13 pass; 21 broken belong to other rows: any_of-needs-2 and shared-test cap, incl. authentication_failed,
  invalid_token owned elsewhere).

## Files changed

test/ash_surface/parity_kinds/type_kinds_test.exs, test/ash_surface/parity_kinds/error_types_test.exs,
test/ts/kinds_runner.mjs, parity/court_map.json (two rows), this receipt.
