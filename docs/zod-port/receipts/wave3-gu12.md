# Wave 3 Lane GU-T12 Receipt

Standing: PARTIAL

Scope: convert loud-skip gap tests of the T12 partition (`test/ash_surface/ported/rpc/e/`) now that
the non-actuating RPC pipeline and typed-query runner exist. 40 of the 103 skips are converted
to real tests; 63 remain loud skips with accurate reasons. No `lib/` edits. No README edit; no row
marked `non_goal`. `no_local_do` allowlist untouched; no `Ash.read/create/update/destroy` added.

## Converted vs remaining

| reference file | converted (test file) | remaining skips and reason |
|---|---|---|
| struct_field_filtering (6) | 6/6 struct_field_filtering_surface_test.exs | 0 |
| top_level_strictness (9) | 9/9 top_level_strictness_surface_test.exs | 0 |
| ts_runtime_validation (1) | 1 (+10 shape cases) ts_runtime_validation_surface_test.exs | 0 (adapted: no .ts, no run_action) |
| typed_map_embedded_rows (3) | 3/3 typed_map_embedded_rows_surface_test.exs | 0 |
| working_comprehensive (12) | 12/12 working_comprehensive_surface_test.exs | 0 |
| tuple_newtype_input 13th | 1 (in tuple_newtype_input_test.exs, now 13/13) | 0; gap file deleted |
| typed_query_codegen (6) | 4 typed_query_codegen_surface_test.exs (001-004, behavioral on TqTodo typed query) | 2: 005 section header text, 006 `satisfies` on every constant line (TS text only; D-T12-3) |
| typed_query_field_mapping_cross_domain (5) | 4 (001,002,003,005) ..._surface_test.exs | 1: 004 schema type emitted once (TS text only) |
| zod_mapped_fields (10 gap tests) | 0 | 10: DEPENDENT on F1-fieldwire |
| valibot_constraints (50) | 0 | 50: unchanged, operator decision D1 / D-T12-1 |

Totals: 103 skips before; 40 converted (6+9+1+3+12+1+4+4); 63 remain (2+1+10+50).

zod_mapped_fields: polled for `receipts/wave3-f1fw.md` with a date deadline. The file appeared
at 23:57 but is an "In flight" stub (Standing: PARTIAL, no commands) and was still a stub at the
00:03 deadline (20 min from 23:43). The 10 tests (and their skip tag citing resource-level
`field_names`/`argument_names` in action input Zod keys) are untouched; re-run them after
F1-fieldwire lands.

## Adaptation notes (recorded in ledger `changes`)

- Execution is not ported. Create/update input is asserted as the parsed request
  (`request.input/identity/pagination`); results are caller-built real Ash structs
  (`Todo/User/TodoComment/TodoMetadata`, `Ash.Page.Offset`); not-found and required errors feed real
  `Ash.Error.Query.NotFound` / `Ash.Error.Changes.Required`. A destroy result is the destroyed record
  (reference `return_records?: true`), with no field selection the data is `%{}`.
- Observed (not asserted as a defect): the request parser accepts the internal spelling of an
  existing field (`address_line_1`, `is_active?`) as well as the mapped client name; mapping is
  enforced on output. Cross-domain typed-query test has no second-domain typed-query fixture, so it
  runs through the single ported manifest (stated in the row).
- ts_runtime_validation covers 10 representative request shapes, not all 24 shouldPass files.

## Ledger rows (small targeted row edits, JSON re-validated, `parity/` is untracked)

adapted: struct_field_filtering, top_level_strictness, ts_runtime_validation,
typed_map_embedded_rows, working_comprehensive; tuple_newtype_input `changes` updated (13/13).
skipped_gap kept (remaining parts): typed_query_codegen (005, 006), typed_query_field_mapping_cross_domain (004),
zod_mapped_fields (row is `adapted`; its 10-test gap file is unchanged, not on the row), valibot_constraints.

## Commands and exits (MIX_BUILD_ROOT=_build-gu12 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/e test/ash_surface_mock_discipline_test.exs` | 0 | 252 tests, 0 failures, 63 skipped (all 63 loud tagged skips in the gap files above) |
| `mix format` on the new/edited test files | 0 | clean |
| grep `Process.sleep\|Mox\|mock(\|:meck` over new surface tests + tuple test | 1 | zero matches |

`mix ash_surface.parity.tests --summary` not re-run by this lane (other lanes pending; shared gate
exit 1 per earlier receipts). `_build-gu12` deleted at hand-off.

## Operator decisions still open

D-T12-1 / D1 valibot_constraints (50); D-T12-3 / D15 typed-query TS text (typed_query_codegen
005/006, cross-domain 004); D-T12-4 zod_mapped_fields (10) pending F1-fieldwire.
