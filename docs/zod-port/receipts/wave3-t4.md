# Wave 3 Lane T4 Receipt

Standing: PARTIAL

Lane T4 (`manifest/` 7 files + `rpc/verify_action_types/` 9 files). All 16 rows are `adapted`
with per-test counterparts and zero skips in their runnable files; one reference test
(`relationship_query_capabilities`: non-RPC destination) is a loud skip in a `*_gap_test.exs`
pending an operator decision. Gate exits 1 only because other lanes' rows are still unaccounted.
Reference `~/ash_typescript` HEAD `5d6e80aec1afcbabaf0831768c210fecd81bd869`; subject tree is the
shared canonical checkout (uncommitted, SHA not pinned by this lane).

## Mixed-file split convention (owned by T4, copy this)

A reference file whose tests are partly portable and partly blocked is split by the lane:

1. Runnable tests go in `test/ash_surface/ported/<dir>/<name>_surface_test.exs` (zero skips of
   any form). This file backs the row's `adapted`/`ported` disposition.
2. Each blocked test goes in `test/ash_surface/ported/<dir>/<name>_gap_test.exs` as a bodiless-in-
   spirit test with `@tag skip: "<name>_gap: <reason>"` (loud, never silent; `flunk` body so
   an un-skipped run fails).
3. The ledger row lists ONLY the `_surface_test.exs` in `ash_surface_tests`; the `changes`
   field names the skipped reference test, the gap file, and the skip tag text. (A row
   supports one disposition; the gate rejects a skip inside a listed file.)
4. If NOTHING in the reference file is portable, use a single `skipped_gap` row whose
   `ash_surface_tests` is the gap file and `skip_tag` is a verbatim substring of the skip tag.
5. Every reference test needs a counterpart or an explicit per-test note in `changes`.
   Reference tests that define modules inline are ported by mechanical transformation
   (extension swap, `typescript do` -> `surface do`, domain block removed, call routed through
   a real-validator helper) so test bodies stay diffable against the reference.

## Per-file disposition

| reference file | disposition | ash_surface test file | tests |
|---|---|---|---|
| manifest/codegen_type_dispatch_test | adapted | ported/manifest/codegen_type_dispatch_surface_test.exs (+ seeded manifest_type_dispatch_test.exs) | 49 (36 literal + 13 generated) |
| manifest/custom_test | adapted | ported/manifest/manifest_custom_surface_test.exs | 10 |
| manifest/decorator_test | adapted | ported/manifest/decorator_surface_test.exs | 25 |
| manifest/entrypoint_action_decoration_test | adapted | ported/manifest/manifest_entrypoint_action_decoration_surface_test.exs | 3 |
| manifest/persist_resource_lookups_test | adapted | ported/manifest/persist_resource_lookups_surface_test.exs | 7 |
| manifest/relationship_query_capabilities_test | adapted (6/7; 1 loud skip) | ported/manifest/manifest_relationship_query_capabilities_surface_test.exs, gap: ..._gap_test.exs | 6 + 1 skip |
| manifest/verify_mappable_types_test | adapted | ported/manifest/verify_mappable_types_surface_test.exs | 6 |
| rpc/verify_action_types/ (9 files) | adapted, 42/42 reference tests 1:1 | ported/manifest/verify_action_types_<name>_surface_test.exs | 42 |

Per-file counts of reference vs port for `verify_action_types`: argument_type_field_names 3/3,
composite_type 4/4, custom_ash_type 5/5, new_type_return_types 8/8, new_type_wrapping 9/9,
resource_return_types 3/3, return_type_field_names 5/5, struct_types 2/2, valid_field_names 3/3
(re-derived by `grep -c '^    test "'` on both sides).

## Lib edits (disclosed; all minimal, targeted)

- NEW `lib/ash_surface/resource/verifiers/action_type_field_names.ex`: port of
  `VerifyActionTypes` (capability `verifier.VerifyActionTypes`), code
  `invalid_action_type_field_names`. Implements what the former loud skips declared missing.
- `lib/ash_surface/resource/verifiers/checks.ex`: `refusals/1` now appends
  `ActionTypeFieldNames.refusals/1` (one edit; another lane concurrently added `alias Naming`,
  which is currently an unused alias warning, not mine).
- `lib/ash_surface/compiler/resource_facts.ex`: relationship `pagination` now derives from the
  relationship's `read_action` override (was destination primary read only) and is `"none"`
  for to-one; new public `relationship_read_action/1` and `relationship_pagination/1`. No new
  key in the relationship fact map (no IR/golden change).
- `lib/ash_surface/compiler/zod_type.ex`: `module_override/2` falls back to
  `typescript_type_name/0` (string/number/boolean -> Zod primitive, other names -> `z.unknown()`),
  so such custom types are mappable without an override (reference test).
- `test/ash_surface/resource/validator_action_types_test.exs` (w3-07 evidence file): removed the
  stale "no ash_surface counterpart (loud skips)" describe (9 skips now false) and updated its
  moduledoc to point at the ported files.
- NEW `test/support/ported/verify_action_types_helper.ex` (real-validator harness, no doubles).

## Commands (MIX_ENV=test, MIX_BUILD_ROOT=_build-t4 seeded by copying `_build`; deleted after)

| command | rc / result |
|---|---|
| `mix test test/ash_surface/ported/manifest` | 148 tests, 0 failures, 1 skipped (the gap test) |
| `mix test` ported/manifest + mock_discipline + no_local_do + parity_tests + resource + verifiers | 246 tests, 0 failures, 1 skipped |
| `mix test test/ash_surface/compiler` | 290 tests, 1 failure: `schema_section_test.exs:311` (map fragment `z.record(.., z.unknown())` vs expo `z.any()`); not in a path this lane edits (kind `map` has no `typescript_type_name`), attributed to another lane's in-flight change, UNVERIFIED by baseline (no stash allowed) |
| `mix format` on all T4 files | applied |
| `mix ash_surface.parity.tests --summary` | rc=1 (by design until all lanes land) |

Gate output (re-read from `/tmp/t4_gate.txt` at write time):

`parity-tests: files=264 ported=0 adapted=76 skipped_gap=26 non_goal=10 unaccounted=152 broken=0 shallow=29`

T4 rows: manifest 7 adapted, verify_action_types 9 adapted (0 skipped_gap, 0 unaccounted, 0 broken).
`mix ash_surface.parity.tests` marks T4 rows SHALLOW (warning only): the heuristic wants a
node/zod/renderer reference in the file and these are validator/facts tests. Not gamed; left as is.

## Operator-decision list

1. `many-relationships to non-RPC destinations are not stamped`: ash_surface marks every public
   relationship `exposed: true` (manifest-first, plain Ash destinations are valid). Parity would
   require deriving "not exposed" from something (e.g. destination lacks `AshSurface.Resource`),
   which would hide relationships in existing plain-manifest flows. Loud skip tag
   `relationship_query_capabilities_gap`. Decide: keep as divergence (needs a better-witnessed KD
   row) or define the allow-list.
2. `parity/court_map.json` `verifier.VerifyActionTypes` still points at a weak court
   (`validator_action_types_test.exs`, "private read, create, ..."); repoint to
   `test/ash_surface/ported/manifest/verify_action_types_*_surface_test.exs` (coordinator-owned file).
3. `Checks` unused `alias AshSurface.Naming` (added by another editor) will warn until used.

## Falsifiers

- A reference `verify_action_types` test whose invalid-name case does not produce
  `invalid_action_type_field_names` would fail the port (42 do; mapped/valid cases return `:ok`).
- Non-vacuity not shim-court-proven: invalid cases assert `{:error, ...}` containing the exact
  names, which cannot pass without the verifier (it did not exist before this lane), but no
  restore-based court was run.

## See Also

`TEST-PORT-CONTRACT.md` · `TEST-PORT-PLAN.md` · `receipts/wave3-t0.md`
