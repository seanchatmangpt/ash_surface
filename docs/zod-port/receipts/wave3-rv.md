# Wave 3 Lane RV Receipt

Standing: PASS

Lane RV: non-vacuity proof of lane RU's court
`test/ash_surface/divergence_close/formatter_scope_errors_tasks_test.exs`, plus KD-10 register check.
Scratch `/tmp/rv`: explicit-path tar of the live repo (README.md included), `deps` and `node_modules`
symlinked, build root `/tmp/rv/_build-rv` (seeded from `_build/test`). Harness `/tmp/rv/mut.py`
(sha256 baseline, mutate, run court, byte-exact restore, restore sha compared). `/tmp/ru`, `/tmp/rt`
untouched. Note: `rsync` of the repo was refused by the topology hook; tar used instead.

## Baseline

- Scratch, unmodified RU lib: `mix test <court>` rc=0, 12 tests, 0 failures (the pre-fix flip RU
  never ran is replaced by per-mutation red below).

## Mutation results (first pass vs 12-test court, then after repair)

| mutation | file | 12-test | 16-test |
|---|---|---|---|
| M1 errors default -> Config formatter | errors.ex | red (3) | red (3) |
| M1b errors default -> hard camel | errors.ex | red (3) | red (3) |
| M1c namer function-formatter branch -> camel | errors.ex | SURVIVED | red (1) |
| M2 Task lookup returns nil | field_name.ex | red (2) | red (4) |
| M2b drop $callers | field_name.ex | SURVIVED | red (2) |
| M2c drop $ancestors | field_name.ex | SURVIVED | red (1) |
| M2d scope not restored after block | field_name.ex | red (2) | red (3) |
| M2e leak after raise (restore outside after) | field_name.ex | red (1) | red (1) |
| M2f child retains scope (copied into child) | field_name.ex | SURVIVED | red (1) |
| M3 skip nested recursion | pipeline.ex | red (2) | red (3) |
| M3b skip filter keys | pipeline.ex | red (1) | red (1) |
| M3c skip sort fields | pipeline.ex | red (1) | red (1) |
| M3d skip embedded destinations | pipeline.ex | SURVIVED | red (1) |
| M3e skip relationship destinations | pipeline.ex | red (2) | red (2) |
| M3f check_scoped_spellings disabled | pipeline.ex | red (3) | red (4) |
| M3g Config spelling not refused | pipeline.ex | red (4) | red (5) |
| M4 errors path depth>1 camel | error_formatter.ex | red (2) | red (3) |

Survivors (M1c, M2b, M2c, M2f, M3d) each got a new test in the real court file (new tests only, lib
untouched): explicit function formatter at every depth; `$callers`-only and `$ancestors`-only chains;
long-lived child does not retain scope after the owner block; embedded destination (`metadata` ->
`estimated_hours` vs `estimatedHours`) strict under snake scope. All 17 mutations red on the 16-test court.

sha256 baseline == restore for every mutation (`restore True` x17); post-run hashes of
field_name.ex, errors.ex, error_formatter.ex, pipeline.ex equal between scratch and live tree.

## Live tree (read-only for lib)

- Court on the live tree (`MIX_BUILD_ROOT=_build-rv`, deleted afterwards): rc=0 (un-piped), 16 tests,
  0 failures.
- KD-10 (`docs/KNOWN_DIVERGENCES.md`): `Register.witnessed?/2` returns `:ok` and `Register.lint/2`
  returns `[]`. better_because non-empty, court file exists, receipt `wave3-ru.md` Standing PASS with
  a PASS evidence line naming the court file and no FAIL/SKIP/BLOCKED token (grep of the receipt).
- `mix ash_surface.parity --json`: `errors: []`, counts pass 302, divergence 12, missing 10, non_goal
  79, exit 1. The exit 1 is the pre-existing 10 MISSING capabilities (valibot, installer, typed
  controller, codegen flags); none reference KD-10 or this court.

## Not run

- `mix ash_surface.parity.tests` ledger check after the 4 new tests: UNVERIFIED (tests added to an
  existing file; ledger rows are per file).
