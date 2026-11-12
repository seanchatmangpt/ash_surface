# Wave 3 F1-repin receipt

Standing: PARTIAL

Before/after: `mix ash_surface.parity --json` broken 35 -> 0 (pass 218 -> 296 incl. other lanes'
concurrent landings; missing 71 -> 28; non_goal 79). Exit still 1 only on KD-03/KD-04 errors.

## Fixes (court_map.json via targeted edits; no gate or lib/ash_surface/parity change)

- 5 VACUOUS helper-only rows (typed_query_fields_test: argument_names, field_names, type_name,
  namespace, VerifyFieldNames; g3_verifiers_test VerifyMetadataFieldNames): tests rewritten to
  assert directly in the body (`assert out =~ "Spark.Error.DslError"` / code).
- 16 `error.impl.*` any_of single-alternative rows: second alternative errors_s1b_test.exs added;
  `Changes.Required`/`Query.Required` hit the GENERIC cap, re-pointed to exact tests (new test
  "Query.Required classifies as required ..." in errors_test.exs).
- 4 shared-test rows (AuthenticationFailed/InvalidToken impl + type): split into two tests in
  error_type_parity_test.exs, each row points to its own.
- tstype.create/on/unsubscribe: token re-pointed to test titles ("tstype create:" etc.).
- type.constraint.fields/match: exact entries to zod_type_wave2_test.exs real tests.
- type.aggregate.list (GENERIC `:list`): exact entry to schema_courts_test.exs :list test.
- verifier.VerifyActionTypes: re-pointed to T4's ported verify_action_types_*_surface_test.exs
  (4 tests: map return, map argument, valid names, resource return).
- config.key.{import_into_generated,manifest,policies}: already re-pointed by another lane
  (parity_key_courts_test.exs) before my edit landed; my duplicate tests were removed.

## Skipped (running lane)

KD-02 (f1rw receipt absent), KD-03/KD-04 (f1kd receipt absent): receipts do not exist yet.
`KD-01 duplicate register row` error: did not appear in this run; untouched.

## Commands

- `MIX_BUILD_ROOT=_build-f1rp mix ash_surface.parity --json` rc=1 (before: broken 35; after: broken 0,
  errors = KD-03, KD-04 receipt-missing only)
- `mix test` typed_query_fields, g3_verifiers, error_type_parity, errors_test: 73 tests, 1 failure
  (error_type_parity "constraint instance_of ..." expects `z.unknown()`, ZodType now emits
  `z.any()`; not touched by this lane, pre-existing/other-lane drift in ZodType).
- `rm -rf _build-f1rp` done.

## ExUnit-exclude hole (note only)

Not closed here: the parity indexer does not see ExUnit `@tag :skip`/exclude config from
test_helper; a court under a globally excluded tag would still read as passing. Report only.
