# wave3-gu9

Standing: PARTIAL

Lane GU-T9: convert the loud-skip gap tests of T9 (rpc/b) to real tests. 144 loud skips at start became real tests where a non-actuating or native counterpart
exists; 80 loud skips remain, each with a stated reason. All 5 T9 ledger rows account with broken=0.

## Converted vs still skipped

| reference file | before | now | converted by | still skipped |
|---|---|---|---|---|
| load_restrictions_test | skipped_gap, 21 skips | adapted, 0 skips | load_restrictions_surface_test (21 tests: caller-built list/page results through `Rpc.run/2`, `Ash.Page.Offset`/`Keyset` for pagination) | 0 |
| map_field_name_rpc_test | skipped_gap, 9 skips | adapted, 0 skips | map_field_name_rpc_surface_test (9 tests) | 0 |
| keyword_field_formatting_test | skipped_gap, 2 skips | adapted, 0 skips | keyword_field_formatting_surface_test (2 tests) | 0 |
| json_manifest_generator_test | skipped_gap, 59 skips | skipped_gap, 36 skips | json_manifest_generator_surface_test (27 tests, KD-07 native manifest; 23 map to reference tests) | 12 files-section, 6 TS type names, 4 variant names, 14 typed-controller routes (TS artifacts / separate route surface) |
| manifest_generator_test | skipped_gap, 53 skips | skipped_gap, 44 skips | manifest_generator_surface_test (9 tests, structural facts on the native manifest) | 44: markdown rendering + RpcConfigCollector (operator decision D24: no README sentence makes markdown a non-goal) |

Skip total 144 -> 80 (the 3 gap files for run_action rows deleted; json/manifest gap files
regenerated with reasons prefixed `GU-T9 gap`).

## Native manifest (KD-07)

`lib/ash_surface/manifest/action_manifest.ex` (new): `build/2` over the prepared
`Ash.Info.Manifest` handle + entry table, `to_json/1` via `AshSurface.CanonicalJSON`
(deterministic, key-sorted, trailing newline), `function_name/1`. Reads facts only; no
`Ash.read/create/update/destroy` (grep over the file: no match). KD-07 row in
`docs/KNOWN_DIVERGENCES.md` cites witness `wave3-gu9-kd07.md` (Standing PASS, non-vacuity shim
flips 27 -> 2 failures and restores byte-exact). `parity/court_map.json`
JsonManifestGenerator entry changed from `pass` to `{"status":"divergence","kd":"KD-07"}`.

## Commands (MIX_BUILD_ROOT=_build-gu9 MIX_ENV=test)

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/b test/ash_surface/no_local_do_test.exs test/ash_surface_mock_discipline_test.exs test/ash_surface/config` | 0 | 336 tests, 0 failures, 80 skipped (all loud GU-T9/T9 tags) |
| per-file load_restrictions_surface / map_field_name_rpc_surface / keyword_field_formatting_surface / manifest_generator_surface / json_manifest_generator_surface | 0 | 21 / 9 / 2 / 9 / 27 tests, 0 failures, 0 skips |
| `mix format --check-formatted` (lib file + rpc/b tests) | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 | `files=264 ported=9 adapted=168 skipped_gap=44 non_goal=19 unaccounted=17 broken=7 shallow=72` whole repo; the 7 broken rows are other lanes (nested_query_opts, output_field_formatting, rpc_field_argument_mapping gap files absent; run_action ltree/sort_filter/untyped_maps/user skip tags); T9 rows broken=0 (`SHALLOW` warning on the 3 converted rows: no node/zod reference, by design non-actuating) |
| `mix ash_surface.parity` | 1 | `parity: total=403 pass=302 divergence=12 non_goal=79 broken=0 missing=10`; JsonManifestGenerator no longer MISSING; the 10 missing are other lanes' capabilities |

## lib / contract edits (disclosed)

- New: `lib/ash_surface/manifest/action_manifest.ex`. No edits to
  `lib/ash_surface/runtime_parity/rpc/*` (no pipeline defects found; all 32 converted tests
  passed on first run).
- Appended: KD-07 (docs/KNOWN_DIVERGENCES.md), D24 (docs/jira/v26.11.11/OPERATOR-DECISIONS.md),
  `parity/court_map.json` JsonManifestGenerator entry, 5 T9 rows in `parity/test_ledger.json`
  (targeted Edits/replace on those rows only; file re-read before each).
- Deleted: load_restrictions_gap_test, map_field_name_rpc_gap_test,
  keyword_field_formatting_gap_test.

## Operator decisions

- D24 (new): markdown manifest renderer vs non-goal wording (44 skips).
- Typed-controller routes in the KD-07 manifest: follow-up (14 skips), no decision needed.

## Standing detail

PARTIAL: 80 loud skips remain by design (TS artifacts, markdown render, routes). Converted
tests assert caller-built results, not data-layer behavior (README: it never actuates).
`_build-gu9` removed at lane end.
