# wave3-gu8

Standing: PARTIAL

Lane GU-T8: convert the 185 loud-skip placeholders in `test/ash_surface/ported/rpc/a/*_gap_test.exs`
into real tests through the non-actuating pipeline (`Ported.Rpc.parse/run/error` over
`RuntimeParity.Rpc.*`), plus the `custom_type_schema` divergence. Caller-built results and errors
(real Ash structs, non-executing `Ash.Changeset.for_create` / `Ash.ActionInput.for_action` /
`Ash.Query.for_read` constructors, `Ash.Error.Query.NotFound` as the data layer raises it); no data
layer, no mocks, no `Process.sleep`, no `Ash.read/create/update/destroy`.

## Counts

Converted 177 of 185; still skipped 8 (loud, accurate). 12 of 13 gap files deleted.

| reference file | converted | still skipped | surface file (`rpc/a/`) |
|---|---|---|---|
| calculations | 10 | 0 | calculations_surface_test.exs (11) |
| comprehensive_integration | 22 | 0 | comprehensive_integration_surface_test.exs (22) |
| embedded_argument_rpc | 7 | 0 | embedded_argument_rpc_surface_test.exs (8) |
| entrypoint_resolution | 2 | 0 | entrypoint_resolution_surface_test.exs (2) |
| first_aggregate_complex_types | 3 | 0 | first_aggregate_complex_types_surface_test.exs (4) |
| input_parsing_stress | 28 | 0 | input_parsing_stress_surface_test.exs (28) |
| input_field_formatting | 3 | 0 | input_field_formatting_surface_test.exs (3) |
| enable_filter | 15 | 0 | enable_filter_surface_test.exs (14 total) |
| enable_sort | 18 | 0 | enable_sort_surface_test.exs (17 total) |
| error_handling | 33 | 0 | error_handling_surface_test.exs (34) |
| error_protocol | 24 | 8 | error_protocol_surface_test.exs (24) + error_protocol_gap_test.exs (8 skips) |
| error_redaction | 5 | 0 | error_redaction_surface_test.exs (6) |
| error_scenarios | 10 | 0 | error_scenarios_surface_test.exs (10) |

The 8 remaining skips are the "AshAuthentication error impls" tests: they need real
`AshAuthentication.Errors.{AuthenticationFailed,InvalidToken}` structs and `ash_authentication` is not
a dependency (module unavailable under `mix test`); lookalike structs would be a mock.
enable_filter/enable_sort TypeScript-text tests became assertions on the compiled action manifest
(`enableFilter`/`enableSort`/`pagination`), `Rpc.parse` refusals and `QuerySchema.render_query_params`.

Pinned values that come from the data layer (calculation values, aggregates, row order, generated ids,
page disjointness) are carried as loaded values on caller-built structs: those assertions pin pipeline
shaping and field selection, not computation.

## custom_type_schema (T8 divergence)

Parity implemented: a hand-rolled `use Ash.Type` module with no override derives its Zod schema from
`Ash.Type.storage_type/1` (integer, float, string/ci_string/atom, map/jsonb, boolean, uuid, date/time
family, decimal, binary, `{:array, t}`), `lib/ash_surface/compiler/zod_type.ex` `storage_expression/1`;
a declared `typescript_type_name` no longer masks it. Executed under node+zod. Storage with no
unambiguous JSON wire form stays REFUSED as an unmappable kind (reference: `z.any()`): KD-06 in
`docs/KNOWN_DIVERGENCES.md`, court `custom_type_schema_test.exs`, receipt `wave3-gu8-kd06.md`
(Standing PASS, scoped to that court).

## Lib edits

- `lib/ash_surface/compiler/zod_type.ex`: `type_name_expression/2`, `storage_expression/1`,
  `storage_schema/1` (above).
- `lib/ash_surface/errors.ex` (sub-lane gu8c, minimal): `unwrap_errors/1` clause delegating
  `Reactor.Error.Invalid.RunStepError` to its inner error (reference parity; failed before, passes after).
- No edit to `lib/ash_surface/runtime_parity/rpc/*`. No actuation added.

## embedded_argument_test premise move (coordinator request)

F1-errcamel reported 4 failures in `embedded_argument_test.exs`. Cause: the compiled IR now emits
camelCase Zod keys (`metadataItems`, `priorityScore`, `customId`), the reference spelling
(`output_field_formatter` default `:camel_case`); the tests asserted snake_case. A standalone run
earlier in the session passed (8 tests, rc 0) before the formatter landed; after it, 4 failures across
`embedded_argument_test` (2) and `custom_type_schema_test` (2). Re-pinned to camelCase (evidence:
the failure output showed `metadataItems: z.array(z.object({ advancedSettings: ...`); both files pass.

## Commands (MIX_ENV=test MIX_BUILD_ROOT=_build-gu8, per file; root deleted)

| command | rc | result |
|---|---|---|
| each of the 13 `*_surface_test.exs` / gap files above | 0 | all 0 failures; error_protocol_gap 8 skipped |
| `custom_type_schema_test.exs` + `embedded_argument_test.exs` (after re-pin) | 0 | 22 tests, 0 failures |
| `codegen_determinism`, `calculation_field_selection`, `channel_lifecycle_hooks_config`, `forbidden_field_redaction` | 0 | passed in the 54-test run (only the 4 camelCase pins failed) |
| `test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `test/ash_surface/errors_test.exs` | 0 | 27 tests, 0 failures |
| `test/ash_surface/{projectors,compiler}` + custom_type_schema (after lib edit) | 0 | 398 tests, 0 failures, 2 skipped |
| `mix format --check-formatted` (zod_type.ex, errors.ex, rpc/a/*.exs) | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 0 | `files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=94` |

A single combined `mix test` over the whole `rpc/a` directory did not complete in this session (VM
exited without summary, as TEST-PORT-CONTRACT warns); per-file runs above are the evidence.

## Operator decisions

1. KD-06 (refuse vs reference `z.any()` for opaque storage): confirm refusal is the preferred behavior.
2. Add `ash_authentication` as a test-only dependency to un-skip the 8 error-impl tests.

## See Also

`TEST-PORT-CONTRACT.md` · `wave3-t8.md` · `wave3-gu8-kd06.md`
