# Wave 3 F1-divclose Receipt

Standing: PASS

Scope: courts below executed green; two unrelated failures in other lanes' files are listed.

## Register rows closed

| Row | Option | Court |
|---|---|---|
| Filters: `not` single vs array | b (KD-01) | test/ash_surface/divergence_close/filter_divergence_test.exs |
| Filters: related destination nested and/or/not (S1-C regression) | restored | same file, second test |
| Aggregates: name enum in selection | a (aggregate names also valid in `fields`) | test/ash_surface/divergence_close/aggregate_selection_test.exs |

Note: ~/ash_typescript/lib in this checkout contains no filter module, so the `not` array shape
is taken from the register text; the reference could not be re-read.

## Rows left open

- `require_tenant_parameters` default: F1-errcfg.
- `max_depth` cap 0..3, `functions` metadata-only, pagination `max_limit` fallback 500:
  not a divergence from a reference behavior I could witness; left open, unowned.
- Others (relationships discovery producer, embedded, errors, config): G-lanes / F1-embedref.

## Sizes (5 relationships x 10 destination fields + 10 scalars)

Before: 69302 bytes. After: 475076 bytes (cap 1_000_000; size test passes).
Cause: related destinations at logical depth 1 and `not` union duplicating its inner union.

## Court-map mapping for coordinator

filters -> {"status":"divergence","kd":"KD-01"}; aggregates -> court
test/ash_surface/divergence_close/aggregate_selection_test.exs (option a, no KD).

## Commands (MIX_BUILD_ROOT=_build-f1dc)

- mix test divergence_close + test/ash_surface/compiler + no_local_do + mock_discipline:
  300 tests, 2 failures, both outside my files: schema_constraint_test float bounds
  (`min(0)` vs `min(0.0)`, F1-floatfmt) and union_schema_test `__proto__` error tag.
- mix format --check-formatted on changed files: exit 0.
- Updated pinned tests: filter_schema_test.exs (and count 4 -> 5), filter_schema_executed_test.exs
  (array `not` moved from invalid to valid).

## Vectors needing regeneration

Any conformance vector kind rendering filter or selection schemas (filter/selection digests).

## Files changed

lib/ash_surface/compiler/filter_schema.ex, selection_schema.ex, docs/KNOWN_DIVERGENCES.md,
docs/jira/v26.11.11/PARITY-REGISTER.md, test/ash_surface/divergence_close/*, the two tests above.
