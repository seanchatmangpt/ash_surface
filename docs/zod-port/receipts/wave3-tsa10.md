# wave3-tsa10

Standing: PARTIAL

Lane TSA-T10: adapt the loud-skip gap tests of the T10 partition that assert generated
TypeScript text onto Zod / compiled-IR / pipeline / manifest assertions. Of the 100 TypeScript-text
skips left by `wave3-gu10.md`, 75 are converted to tests with zero skips; 25 remain loud skips
tagged TS-SYNTAX-ONLY. Two small `lib/` edits (disclosed below). No README edit; no row marked
`non_goal`.

## Converted vs remaining

| group (reference file) | converted | remaining | tag | reason |
|---|---|---|---|---|
| namespace_test (gap half) | 19/40 (namespace_manifest_surface_test.exs) | 21 (012-017, 021, 031, 035, 036, 038-048) | TS-SYNTAX-ONLY | 006/010/011/037 namespace + metadata facts, 018-020/022-025/034 description precedence, 026-028 deprecated, 029-030 see, 032-033 typed query description: BEHAVIORAL-COUNTERPART-FOUND (action manifest, Manifest.Dsl). Default JSDoc prose (012), validation marker (013), internals toggle and source location (014-017, 021), validation JSDoc (031), JSDoc comment placement (035-036), multi-file re-exports, headers, custom-code markers (038-048): comment text / file layout, no emitter exists |
| rpc_function_generation_mapped_fields | 20/22 (rpc_function_generation_mapped_fields_surface_test.exs) | 2 (013, 019) | TS-SYNTAX-ONLY | input/result/validation/payload claims have Zod + pipeline + RpcValidate counterparts (BEHAVIORAL-COUNTERPART-FOUND); 013 and 019 assert channel client function signature text |
| restricted_schema_codegen | 15/15 (restricted_schema_surface_test.exs) | 0 | n/a | BEHAVIORAL-COUNTERPART-FOUND: top-level allow/deny as SelectionSchema Zod under node + real zod; nested, scalar, mapped-name, nullable-embedded and paginated cases via the pipeline entries |
| rpc_get_actions | 7/7 (rpc_get_actions_ir_surface_test.exs) | 0 | n/a | BEHAVIORAL-COUNTERPART-FOUND: IR get fragment under zod, pipeline refusal of filter/sort/page and missing getBy keys, `\| null` claim via IR `not_found_error?` + tsc --strict over `Inference.action_types` |
| nested_map_field_formatting | 4/4 (nested_map_field_formatting_surface_test.exs) | 0 | n/a | BEHAVIORAL-COUNTERPART-FOUND: camelCase wire keys and per-item nested selection through `Rpc.run` |
| optional_tenant_for_all_actions | 6/7 (optional_tenant_ir_surface_test.exs) | 1 (007) | TS-SYNTAX-ONLY | tenant accepted by read/get/create/update/destroy, present on the request only when supplied; 007 asserts channel function text |
| rpc_composite_primary_key | 4/5 (rpc_composite_primary_key_ir_surface_test.exs) | 1 (005) | TS-SYNTAX-ONLY | composite identity as IR get-identity zod (all parts required, uuid typed), request carries the map, validation accepts a non-UUID tenantId; 005 asserts channel function text |

Totals (re-derived from the files): converted 19 + 20 + 15 + 7 + 4 + 6 + 4 = 75; remaining
21 + 2 + 0 + 0 + 0 + 1 + 1 = 25; 75 + 25 = 100. Remaining skips: namespace 21, channel function
text 4.

## Deltas that change what a converted test asserts

- Zod nested relationship loads: `ResourceFacts` relationships are one level, so nested allow/deny
  paths (restricted 007, 009, 011, 012) are asserted on the pipeline entries, not on Zod.
- The pipeline accepts snake_case selection names for nested typed-map keys and still emits
  camelCase (nested_map 003 asserts the observed behavior, not refusal).
- The get-by Zod for an `:atom` key with `one_of` constraints accepts any string (observed while
  writing get_actions 031; not asserted; constraint is not carried into the get-by key fragment).
- `ActionManifest` reports `enableFilter`/`enableSort` true for get entries although the pipeline
  refuses `filter`/`sort` on get actions (observed; get_actions 032 asserts the pipeline refusal).
- Namespace tests use the action manifest, which resolves entry > resource namespace; the
  domain-level namespace is covered by `namespace_resolution_test.exs` (earlier lane).

## lib edits (targeted, re-read first; both files are untracked in the shared tree)

1. `lib/ash_surface/compiler/resource_facts.ex`: `identities/2` appends a primary-key identity
   when a projection declares `identities: [:_primary_key]` (new `primary_key_identity/2`). Ash does
   not list the primary key among identities, so the identity fragment was nil for composite keys.
   Exposed by composite_primary_key 001/003. `mix format` ran over the whole file.
2. `lib/ash_surface/manifest/action_manifest.ex`: description precedence ignores empty strings
   (entry "" no longer shadows the action description; new `present/1`), and `see: nil` no longer
   raises (`(Map.get(entry, :see) || [])`). Exposed by namespace 025 and 030. `mix format` ran
   over the whole file.

## Commands and exits

Build root `_build-tsa10` (deleted at the end), `MIX_ENV=test`. Support file added:
`test/support/ported/tsa10.ex` (IR compile + node/zod evaluator).

| command | rc | result |
|---|---|---|
| `mix test test/ash_surface/ported/rpc/c` | 0 | 271 tests, 0 failures, 41 skipped (25 mine + 16 data-layer rows owned by GU10: pagination 15, pipeline 014 1) |
| `mix test` over mock_discipline, no_local_do_bang court, rpc/a, rpc/b, compiler | 2 | 757 tests, 2 failures, 88 skipped; both failures in `test/ash_surface/compiler/filter_schema_size_test.exs` (filter schema size cap, a file and area this lane did not touch); mock_discipline and no_local_do courts are in that run and reported no failure of their own |
| `mix format --check-formatted` over the new/edited test files and tsa10.ex | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 0 | `files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=94` |

Grep over my new files for `Process.sleep`, `Mock`, `mock(`: zero matches. The mixed run printed
unrelated warnings (SAT solver absent for one compiler fixture, Inspect protocol consolidation).
SHALLOW warnings (no node/zod/renderer reference) remain for `namespace_test.exs` and
`nested_map_field_formatting_test.exs`; the other rows of this lane are not flagged.

## Ledger rows (small targeted Edits)

namespace_test (adapted, note 21 skips), nested_map_field_formatting (skipped_gap -> adapted),
restricted_schema_codegen (skipped_gap -> adapted), rpc_get_actions (skipped_gap -> adapted),
optional_tenant_for_all_actions / rpc_composite_primary_key /
rpc_function_generation_mapped_fields (still skipped_gap, gap text narrowed). Deleted gap files:
nested_map_field_formatting, restricted_schema_codegen, rpc_get_actions.

## Operator decisions (D15 / D23, OPERATOR-DECISIONS.md)

Proposed `non_goal` for the 25 TS-SYNTAX-ONLY remainders (not marked). README sentence candidate:
`README.md:29` "no generated .ts, no .d.ts, no tsc build step".

- namespace 012-017, 021, 031, 035, 036, 038-048 (21): JSDoc comment text, internals toggle
  (`add_ash_internals_to_jsdoc` is declared in Config but no emitter reads it), multi-file `.ts`
  re-export layout and custom-code markers.
- Channel client function signature text (4): optional_tenant 007, composite 005,
  function_generation 013 and 019.

## Falsifiers

- A converted get/identity test passes while the IR fragment is nil: each asserts the Zod string
  is binary and node rejects a missing key part.
- restricted 005-012: pipeline entries are the same table as `rpc.ex`; if an entry's restriction
  were dropped the refused? assertions fail (they assert refusal, not just success).
- The two `filter_schema_size_test.exs` failures are UNVERIFIED as pre-existing: not re-run on a
  clean tree (no git state commands in this lane).

## See Also

`wave3-gu10.md` · `wave3-t10.md` · `../TEST-PORT-CONTRACT.md`
