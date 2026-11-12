# wave3-ry

Standing: PASS

Lane RY. Mutations ran on a scratch tar copy (`/tmp/ry`, build root `/tmp/ry/_b`, node_modules and
deps symlinked); `inference.ex` sha256 baseline `4e66ec524ea99edd...` == after-restore (harness
`/tmp/ry/mut.py`, raw `/tmp/ry/out/*.txt`). Live-tree runs used `_build-ry` (deleted at end).
Subject lib: `lib/ash_surface/projectors/js/inference.ex`; no lib edit.

## The 9 `@ts-expect-error` (test/ash_surface/inference_deep_test.exs), each individually red

| line | negative | mutation | red test, TS2578 count |
|---|---|---|---|
| 104 | views not selected | no-metadata elem type `& { [k: string]: any }` | plain read (+emitted-shape text), 1 |
| 129 | null with not_found_error? true | get result `any` | get, 1 |
| 166 | someNumber not requested | `Pick<Meta, MetadataFields[number]>` -> `Partial<Meta>` | metadata Pick, 1 |
| 184 | array not a record | create/update result `| any[]` | mutation kinds, 1 |
| 202 | paged result not array | offset page result `| Array<elem>` | optional offset, 1 |
| 204 | unpaged not page object | `ConditionalPaginatedResult` undefined branch `RecordType | PaginatedType` | optional offset, 1 |
| 240 | offset page lacks keyset fields | keyset fields optional AND `type: string` | optional mixed, 1 |
| 302 | unknown sort field | Config sort `any` | Config test, 1 |
| 318 | keyset keys on offset rel | NestedPageInput offset `after?: string` | nested selection, 1 |

Finding: negative 240 is double-guarded; keyset-fields-optional alone and discriminant-loosened
alone both SURVIVE (green); only the compound mutation flips it.

## Survivors of any-loosening, and the new negatives

Before: filter(Config) `any`, sort(relationship envelope) `any`, filter(envelope) `any` survived
inference_deep_test; filter(Config) and metadata `any`/key-loosening survived inference_tsc_test.
Added in inference_deep_test.exs test "filter, sort and metadata types are not loosened to any"
(7 `@ts-expect-error`: filter leaf type, filter key, sort element, sort field, metadata value,
unknown metadata key) and `test/ts/inference/shouldFail/looseTypes.ts` (3 `@error TS2322`:
envelope filter, sort element, sort string). Red under: filter(Config)->any (2 TS2578), metadata
`any` (S3, 1 TS2578), metadata keys `string` (S5, 1 TS2578), sort(Config)->any (N7, 3 TS2578);
envelope sort/filter `any` red in inference_tsc_test shouldFail (S2/S4).

## shouldFail rule

`inference_tsc_test.exs` now requires tsc-reported error LINES == `// @error` marker lines
(optional `// @error TSnnnn` pins the code, used in looseTypes.ts). Shim court: marker line made
clean + unrelated unmarked error added -> RED ("tsc error lines [7] != marker lines [6]"; the old
count rule passed); fixture restored sha256-identical, green again.

## Commands (live tree, MIX_BUILD_ROOT=_build-ry)

- `mix test test/ash_surface/ts/inference_tsc_test.exs test/ash_surface/inference_deep_test.exs`
  rc=0, 25 tests, 0 failures, 4 skipped (skips = pre-existing no-analog ports).
- `mix test test/ash_surface/ts/inference_tsc_test.exs` rc=0, 3 tests, 0 failures.
- `mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0).

UNVERIFIED: the tsc test (fixture surface) was not mutated for N1-N8 (deep-test surface only).
