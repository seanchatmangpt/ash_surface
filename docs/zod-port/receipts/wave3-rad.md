# Wave 3 Repair RAD (survivors of SK-mutE2)

Standing: PARTIAL

Lane RAD, repo /Users/sac/ash_surface. Test-only edits; no lib change, no real defect found.
Scratch /tmp/rad (explicit-path tar incl. README.md, node_modules/deps symlinked, build root
/tmp/rad/_b). Shim script /tmp/rad/court.sh, /tmp/rad/c2.sh.

## Tests added

- rpc/d/rpc_validate_action_surface_test.exs: describe "pagination refusals" (page on
  create_todo -> pagination_not_supported/unsupported; unknown page key -> invalid_pagination).
- rpc/d/run_typed_query_surface_test.exs: TypedQuery.lookup miss carries requested name.
- rpc/a/forbidden_field_redaction_test.exs: extract_value(ForbiddenField) == nil, not :skip.
- rpc/a/error_protocol_surface_test.exs: per-struct exact type/short_message/fields/path (10
  structs) plus vars from the field slot.

## Shim-court (baseline sha256 == restore sha256, EQ for all)

Scratch baseline had 1 failure (another lane's in-flight test in run_typed_query_surface_test).

| mutation | file | added failures |
|---|---|---|
| M06 top-level page -> :ok | pipeline.ex | 1 (pagination refusals) |
| M07 unknown page keys admitted | pipeline.ex | 1 |
| M16 not_found carries :x | typed_query.ex | 2 |
| M12 ForbiddenField -> :skip | result_processor.ex | 1 |
| E1-E7 type/short strings (not_found, required, forbidden, invalid_attribute, invalid_argument, invalid_query, Query.Required) | errors.ex | 1-3 each, error_protocol file alone |

## Live gates

- parity: `mix ash_surface.parity.tests` rc=0 (unaccounted 0, broken 0).
- `mix test test/ash_surface/ported/rpc test/ash_surface/no_local_do_test.exs` rc=2 (un-piped, in
  background): run 1 1851 tests 5 failures, run 2 1955 tests 2 failures. Failing tests are in
  other lanes' concurrently edited files (RuntimeSourceOfTruthAstGuard, ValueFormatterBranches,
  PrivateArgumentsIrSurface, ManifestGeneratorSurface, TsRuntimeValidationSurface); none in the
  four RAD files (48 tests, all green except the other lane's in-flight test). Full-suite exit 0
  is UNVERIFIED.
