# wave3-cah

Standing: PASS

Lane CAH: TEST-PORT gate (`mix ash_surface.parity.tests`) skip detector reuses the
capability-gate kernel instead of its own exclude reader.

## Change

- `lib/ash_surface/parity_tests/skips.ex`: `scan_exs` now uses `TestIndex.analyze` (tags,
  nested-module scoping, `@tag`-before-describe, pending, for/macro tests) and
  `ExcludeSpec` (exclude/include/only, mix.exs alias flags, `UNRESOLVABLE-EXCLUDE`).
  A ported/adapted test under an excluded/only-filtered/skip tag reads as a skip (broken).
  `UNRESOLVABLE-EXCLUDE` is a skip on every file. Own AST exclude reader deleted.
- `lib/ash_surface/parity/exclude_spec.ex`: added `read_file/1`, `from_names/1`, `merge/2`.
- `lib/ash_surface/parity/test_index.ex`: tests carry `pending`; dynamic entries carry
  `tag_values`/`skipped` (for/macro tests are runnable: skip only when a tag/filter applies;
  an interim version flagged them as skips and broke the gate, broken=45).
- `lib/ash_surface/parity_tests/report.ex`: passes `ExcludeSpec.read(root)`.
- New `test/ash_surface/parity_tests/skips_adversarial_test.exs` (real temp roots: get_env,
  sigil/keyword/variable, comment, include-over-exclude, nested module leak, `@tag` before
  describe, for/macro tests with and without tags, mix.exs `--exclude`/`--only`, legacy list).

## Commands (MIX_BUILD_ROOT=_build-cah, rc un-piped)

- `mix test test/ash_surface/parity test/ash_surface/parity_tests`: rc=0, 101 tests, 0 failures
- `mix ash_surface.parity.tests`: rc=0
  `parity-tests: files=264 ported=9 adapted=203 skipped_gap=33 non_goal=19 unaccounted=0 broken=0 shallow=94`
- Pre-fix regression state (coordinator report, not re-run): exit 1, adapted=158, broken=45.

## Not run

`mix ash_surface.parity` (capability gate) after the TestIndex field additions: UNVERIFIED
(additive fields only; parity test dir passes).
