# Wave 3 Lane F1-fieldwire Receipt

Standing: PASS

Scope PASS: every site below is wired through `AshSurface.FieldName`; the converted tests and
re-pinned suites are green in the cited runs. Out-of-scope reds observed (not session-introduced,
listed under Commands) remain. IR digest and conformance vectors move: NOT regenerated
(FINAL-REGEN owns). Build root `_build-f1fw` deleted at close.

## Decision: emitted keys are DEFAULT-ON (reference parity)

`FieldName.emitted/1` = `FieldName.output_formatter/0` = process-scoped formatter, else
`Config.output_field_formatter/0` (default `:camel_case`). Same source as the RPC pipeline
(`Rpc.Support` now reads Config) and error fields (F1-errcamel). `field_names` /
`argument_names` / `typescript_field_names` stay verbatim and win. The GU-T2 opt-in
(`:output_field_formatter` set explicitly) is retired; no KD row for it. New API:
`FieldName.with_formatter/2` (process-scoped, async-safe) and `Compiler.compile/2` option
`:output_field_formatter`.

## Sites wired (all through `AshSurface.FieldName`)

New in `lib/ash_surface/field_name.ex`: `output_formatter/0`, `with_formatter/2`, `emitted/1`
(default-on), `wire/3` (type callback, resource `field_names`, else formatter), `wire_argument/4`
(`argument_names[action]` first), `wire_inverse/3`, `action_inverse/3` (client -> server tables,
typed `{:field_name_collision, resource, wire, [internal]}`).

- `compiler/resource_facts.ex`: filter entries (attributes, calculations, aggregates, relationship
  entries), sortable fields, `public_attributes` (selection), relationship names and
  `primitive_fields`, calculation names and argument names, aggregate names, identity / get_by
  keys, `primary_key`, `allowed_loads`/`denied_loads` paths (walked per relationship owner).
- `compiler/section/schema.ex`: action input keys via `wire_argument/4`.
- `compiler/ir.ex` (Fragments): validation-error field names, error carry/field_errors names, and
  `facts["field_names"] = {"fields", "arguments"}` inverse tables.
- `compiler.ex`: `check_field_names/1` refuses a collision before any section builds
  (`{:section_failed, id, {:field_name_collision, ...}}`); `:output_field_formatter` option.
- `runtime_parity/rpc/support.ex`: output/input formatters read `AshSurface.Config`.
- Embedded keys, union member keys, `RecordSchema`: concurrent lane (GU-T2) via `emitted/1`; now
  default-on through the same function.

## Tests converted / re-pinned

- T1: 14 formatter-gap tests -> `ported/top/formatter_artifact_test.exs` (17 tests: real compile
  per formatter incl. custom `{m,f}` and `{m,f,args}`, real node+zod). Gap file keeps embedded-filter
  (3), config-option (2), reference-skipped (1). `typescript_filter_gap_test.exs` deleted.
- GU-T7: 2 `user` pascal/snake tests real; gap file deleted; ledger row adapted.
- GU-T12: 10 `zod_mapped_fields` gap tests real in `ported/rpc/e/zod_mapped_fields_test.exs` (30/30);
  gap file deleted; ledger `changes` updated.
- Courts `divergence_close/field_naming_divergence_test.exs`: custom-formatter inverse + collision
  refusal (KD-09), operator literals (KD-08), unset == explicit `:camel_case`.
- Re-pins (premise rot: default flipped to camel, mapped names reach the compiler): shared compile
  helpers `T1.irs`, `T2.irs/read_facts/zod_full/record_zod`, `E.irs`, `zod_fixtures`, `HarnessExt`,
  `tsa10` run under `AshSurface.Ported.AshNames.with_verbatim/1` (new `test/support/ported/
  ash_names.ex`, process-scoped identity formatter; an explicit env formatter still wins); direct
  `ResourceFacts.build` / `EmbeddedSchema.render` / `RouteSchema.build` / `Compiler.compile` callers
  in 9 test files use `AshNames`; `filter_mapped_fields_test` (`archived?` -> `isArchived`, string
  gt/lt accepted); `embedded_argument_test` expects camel (`T1.ir_under(nil, ...)`).

## Pinned T1 divergences decided

- String filter operators gt/gte/lt/lte: parity (catalogued by a concurrent lane).
- Custom `{module, function}` formatter inverse: witnessed better, KD-09.
- Operator literals under a formatter: KD-08.

## Input-side enforcement (coordinator relay from GU-T12)

Reference read, not changed: `~/ash_typescript/lib/ash_typescript/rpc/input_formatter.ex`
`format_map` passes a key absent from `build_expected_keys_map` through verbatim (`nil -> {key,
value}`); `rpc/field_processing/atomizer.ex` `process_field` keeps an unmapped string
(`_ -> field_name`) which `FieldFormatter.parse_input_field` resolves to the existing atom. The
reference accepts the internal spelling of a mapped field as well as the client name; ash_surface
matches. No enforcement added (parity).

## Commands and exits (MIX_BUILD_ROOT=_build-f1fw MIX_ENV=test; rc read from the ExUnit summary)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/top` | 0 | 379 tests, 0 failures, 16 skipped |
| `mix test test/ash_surface/ported/rpc` | 0 | 1752 tests, 0 failures, 213 skipped |
| `mix test` ported/{ts,codegen,manifest,resource,typed_controller,typed_channel} | 2 | 597 tests, 1 failure: `CodegenTypeDispatchSurfaceTest` `z.any()` vs `z.unknown()` (KD-05, other lane) |
| `mix test` compiler/, projectors/, divergence_close/, ir/, parity_deepen/, field_name*, compiler*_test | 2 | 594 tests, 2 failures: `CompilerTest`, `CompilerCoverageTest` (`required:` key on IR.Ash inputs, ash section, other lane) |
| `mix test` conformance replay + digest + idempotence + divergence_close + field_name + errcamel + no_local_do + mock discipline | 2 | 82 tests, 2 failures: `ConformanceReplayTest` `filter_operators.json` (string gt/lt now accepted; vector regen) |
| `mix test` ir_codec_golden, digest_parity_fixture, parity/ | 0 | 106 tests, 0 failures |
| `mix test` parity/gate_test.exs + embedded_argument_test | 0 | 19 tests, 0 failures (register lint clean incl. KD-08/09) |
| `mix ash_surface.parity.tests --summary` | 0 | `files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=94` |
| `mix format --check-formatted` on every lane-touched lib/test file | 0 | clean |
| grep `Process.sleep` / mocks over lane test files | 1 | zero matches |

A full-tree `mix test` was attempted twice and died mid-run (runner EXIT, unrelated composition
courts failing at load); the grouped runs above are the verification.

## Vectors / digest needing regeneration

IR `schema.facts` gains `field_names`; every emitted key (filter/sort, selection, load,
calculations, aggregates, validation shape, input, embedded, union members) is camelCase by default
or mapped; `IR.digest` and conformance vectors that render named-key zod move. Not regenerated.

## Falsifiers

An emitted object key spelled with the Ash name while a mapping or the formatter applies; a
collision that compiles instead of refusing; `Rpc.Support` formatters diverging from `Config`.

## See Also

`wave3-t1.md` · `wave3-gu2.md` · `wave3-gu7.md` · `wave3-gu12.md` · `wave3-f1ec.md` ·
`docs/KNOWN_DIVERGENCES.md`
