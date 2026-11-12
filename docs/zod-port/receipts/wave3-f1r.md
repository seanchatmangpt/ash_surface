# Wave 3 F1-embedref receipt

Standing: PASS

## Commands
- mix test compiler/*_test (excl. number_literal_test.exs) + projectors/ + error_schema_deep +
  no_local_do + mock_discipline: 109 tests, 0 failures, 2 skipped (exit 0).
- schema_section_test.exs: 2 failures (enum fabrication / `status: z.enum` vs `z.unknown()` at :214, :310) in
  enum/section code paths this lane did not touch (other lanes' in-flight work); not embedded-related.
- s1g courts alone: 18 tests, 0 failures.
- mix format --check-formatted on all changed files: exit 0.

## Changes
- EmbeddedSchema: resource references (kind resource / instance_of) inlined from
  opts[:resources] with cycle (cyclic_schema / cycle_depth) and max_bytes
  ({:schema_too_large,..}) handling; unknown resource -> record fallback. No bare identifiers,
  so ZodGuard.admit/1 admits all output (court under node+zod). :schema_suffix accepted, unused.
  Reason for divergence from ash_typescript (named schema references): ZodGuard admits no
  identifiers; inlining is executed-proven under zod.
- ValidationErrorSchema.map_error_type/2 now returns {:ok, expr} | {:error, typed}; no raise.
- js_schema_wiring_test re-pinned to regex literal (asserts s.sort verbatim in artifact, no
  `new RegExp(`); node execution test retained.
- error_schema_deep_test formatted; map_error_type call sites use a helper.
- Re-pins (reason: debt 1): embedded_schema_test reference tests, s1g courts suffix test.
- New courts in s1g_schema_courts_test: inline+guard+node validation, cycle/depth/cap,
  map_error_type typed error.

## S2-01 (coordinator addendum)
- EmbeddedSchema and ValidationErrorSchema refuse a `__proto__` field with typed
  `{:error, {:denied_field_name, "__proto__"}}`; court in s1g_schema_courts_test (node+zod: `proto`
  admitted and validated). The DEFECT-tagged court in adversarial/container_renderers_adversarial_test.exs
  was not present on disk (no skip/DEFECT/proto text); not edited. UnionSchema member keys not covered
  (not owned).

## Requests
- test/ash_surface/compiler/number_literal_test.exs fails to compile (missing `import Bitwise`),
  not owned by this lane; excluded from run.
- schema.ex callers get inlined output only when they pass `resources:` (they do).

`_build-f1r` deleted.
