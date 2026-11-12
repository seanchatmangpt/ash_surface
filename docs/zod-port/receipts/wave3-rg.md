# Wave 3 Repair: manifest/decorator_surface_test (RG)

Standing: PASS

Lane RG. Repairs the three survivors in `wave3-skmutc.md` (repair requests). Owned file:
`test/ash_surface/ported/manifest/decorator_surface_test.exs` (added describe "compiled
action manifest honours the real action config", 2 tests: `ActionManifest.build/3` over real
`Deco` actions via `Pipeline.entry/4`; asserts `enableFilter`/`enableSort` true by default and
false when the entry disables each, and `metadataFields` for show_metadata unset / false / [] /
list). No lib edits; repo lib untouched by mutation.

## Shim-court (scratch `/tmp/rg`, build root `/tmp/rg/_build`, deps copied)

Baseline: 27 tests, 0 failures. sha256 baseline recorded in `/tmp/rg/base.sha`.

| mutation (scratch lib) | result |
|---|---|
| action_manifest.ex `Map.get(entry, :enable_filter?, true)` -> `true` | RED, 27 tests, 1 failure |
| action_manifest.ex `Map.get(entry, :enable_sort?, true)` -> `true` | RED, 27 tests, 1 failure |
| rpc/pipeline.ex `false -> []` -> `false -> declared` | RED, 27 tests, 1 failure |
| restore | sha256 byte-equal to baseline (SHA_EQUAL); 27 tests, 0 failures |

## Ledger

`MIX_BUILD_ROOT=_build-rg mix ash_surface.parity.tests` exit 0 (unaccounted=0 broken=0).
Mutation commands run: `mix test <file>` in `/tmp/rg` (exit codes read from the failure
counts above, not captured separately: UNVERIFIED as raw rc).

## Cleanup

`_build-rg` in the repo to be deleted at finish; `/tmp/rg` scratch retained (not repo).
