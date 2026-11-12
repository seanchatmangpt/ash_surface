# Wave 3 Lane RM: shim-court for RC repairs

Standing: PASS

Subject: dirty tree at HEAD e3b5d7ffe. Scratch `/tmp/rm` (tar of lib, test, mix.exs, mix.lock,
config, package.json; deps copied; node_modules symlinked; `_build/test` copied; build root
`/tmp/rm/_build-rm`, `TMPDIR=/tmp/rm/tmpd`). Shared tree lib never mutated.

## Court results (tests per file: typescript_filter / type_mapping_overrides / custom_types)

| run | filter | overrides | custom_types |
|---|---|---|---|
| baseline | 29t 0f | 12t 0f | 24t 1f (see note) |
| M1 `op in surface_keys()` -> `op in []` | 29t **1f** RED | 0f | 0f |
| M2 `Map.fetch!(@ash_operator_keys, op)` -> `"zzz"` | 29t **1f** RED | 0f | 0f |
| M3 zod_type `"decimal"` -> `z.number()` | 1f RED | 12t **1f** RED | 0f |
| M4 zod_type `"uuid"` `z.guid()` -> `z.string()` | 0f | 12t **1f** RED | 0f |
| restored | 29t 0f | 12t 0f | 24t 0f |

sha256 baseline == restore for filter_schema.ex (ec3c388a...) and zod_type.ex (604215bb...): MATCH
on all four mutations.

## Surviving mutation and repair

M4 survived the first court (all 3 files green: 64 tests, 0 failures). Repair (test only):
`type_mapping_overrides_test.exs` gained describe "built-in uuid mapping": asserts
`T2.zod(Ash.Type.UUID) == "z.guid()"` and node+zod verdicts `[true, true, false, false]` for a
v1 uuid, `ffffffff-...` (non-RFC version), `"not-a-uuid"`, `42`. Re-proof: green 12t 0f; under M4
1f; restored 12t 0f.

## Notes

- Baseline custom_types 1f: `File.LinkError` creating `<tmpdir>/t1_N/node_modules`
  (stale `~/.cache/tmp/t1_*` collisions with `System.unique_integer`; env artifact). Re-run with
  private TMPDIR: 0 failures in baseline-equivalent restored run. Helper `support/t1.exs:100`
  uses `System.tmp_dir!/0` + small unique ints, so shared TMPDIR can collide. custom_types was
  not targeted by any of the four mutations (0f under all, expected).
- Initial scratch failures (yamerl rebar include symlinks) were from symlinked deps; fixed by
  real copy of deps + `_build/test`.
- Not run: `mix ash_surface.parity.tests`.
