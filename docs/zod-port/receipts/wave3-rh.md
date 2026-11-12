# Wave 3 Repair: typescript_field_names_precedence (Lane RH)

Standing: PASS

Subject: `test/ash_surface/ported/top/typescript_field_names_precedence_test.exs`, repair of
the two survivors in `wave3-skmutc.md` (FieldName.wire/3 override-vs-formatter; emitted/1
falling back to `to_string`). Only the test file was edited; no lib change.

## Added tests (3 describe blocks, 4 tests; existing tests untouched)

- wire/3: override (TaskStats, CustomMetadata callbacks) beats explicit `formatter:` for
  camel/snake/pascal and beats the configured formatter; unmapped fields follow the formatter.
- emitted/1: default `camel_case`; `with_formatter` snake and pascal honoured; never bare
  `to_string`.

## Shim-court (scratch `/tmp/rh`, build root `/tmp/rh/_build-rh`, tar copy of the tree)

- Baseline sha256 of lib/ash_surface/field_name.ex == restore sha256
  (d201eb4ee481aec9817820ed1635dfec65a8741bc151810db2ec4688603861cc).
- Baseline 19 tests, 0 failures (exit 0). M1 formatter beats override: 19 tests, 1 failure (RED).
  M2 `emitted` = `to_string`: 19 tests, 3 failures (RED). Restored: 19 tests, 0 failures.

## Baseline-failure finding (for lane RE)

The 6 baseline failures reproduce only when `node_modules/zod` is absent from the scratch tree
(`REQUIRED PACKAGE MISSING: zod ... Run npm install`, from `zod_fixtures.ex:148`). With zod
linked, the file is 19/0 on the scratch copy and 19/0 on the shared tree. Cause is the scratch
harness environment, not a stale test premise. Not touched.

## Gates (shared tree, MIX_BUILD_ROOT=_build-rh)

- `mix test <file>`: 19 tests, 0 failures.
- `mix ash_surface.parity.tests`: exit 0, unaccounted=0 broken=0.
