# Wave 3 F1-divmap Receipt

Standing: PASS

Scope: court-map mapping for F1-divclose rows, four open filter/config items triaged against
`~/ash_typescript`, one parity implementation (filter `functions`), one stale pin re-pinned.

## Task 1: court-map mapping

`parity/capabilities.json` has no `filters` or `aggregates` cell (sections: codegen, config, dsl,
error, installer, runtime, task, transformer, tstype, type, verifier). The F1-divclose rows are
register rows only, so `parity/court_map.json` needed no new entry and was not edited:
- Filters: the only filter cell is `codegen.module.Codegen.FilterTypes`, already `non_goal` with a
  README quote (TS declaration emission). KD-01 stays a valid register row: non-empty
  `better_because`, court `test/ash_surface/divergence_close/filter_divergence_test.exs` exists
  and passes, receipt `wave3-f1dc.md` is `Standing: PASS`.
- Aggregates: `type.aggregate.*` and `type.aggregate.integer` already `pass`; the aggregate court
  `test/ash_surface/divergence_close/aggregate_selection_test.exs` passes.

## Task 2: open items vs reference (grep of ~/ash_typescript lib, test, docs, README, CHANGELOG,
usage-rules.md)

| Item | Reference finding | Disposition |
|---|---|---|
| filter `max_depth` cap | zero hits; reference filter types are recursive TS types, no depth option | not a reference behavior; ash_surface bound is its own (zod needs finite expansion); size court `filter_schema_size_test.exs` pins it. No divergence row (nothing to diverge from) |
| `functions` metadata | `codegen/filter_types.ex` `@function_atom_to_key` emits `contains`, `string_starts_with`, `string_ends_with`, `has` as filter operations | IMPLEMENTED: `FilterSchema.split_capabilities/1` maps these to surface operators `contains`, `starts_with`, `ends_with`, `has`; other functions stay metadata |
| `max_limit` fallback 500 | zero hits for `max_limit` anywhere in reference | not a reference behavior; ash_surface fallback documented in `query_schema.ex`; unfindable |
| `require_tenant_parameters` default | `rpc.ex:301` default `false`; `usage-rules.md:415` `false` | already at parity (F1-errcfg, `wave3-f1e.md`: `Config.require_tenant_parameters/0` false); `config.key.require_tenant_parameters` is `pass` |

## Changes

- `lib/ash_surface/compiler/filter_schema.ex`: `@function_keys` map; `split_capabilities/1` adds
  whitelisted function operators; moduledoc updated.
- New court `test/ash_surface/divergence_close/filter_functions_test.exs` (real node + real zod:
  function-derived `contains`/`starts_with` accepted, unlisted `ends_with` rejected).
- Re-pinned `test/ash_surface/compiler/filter_schema_facts_test.exs` "functions are metadata"
  test: it pinned the old rule (`contains` function never an operator), contradicted by the
  reference; caused by this lane's filter_schema.ex change (the 1 failure reported), field kind
  changed integer -> string so `contains` is a lawful operator.

## Commands (MIX_BUILD_ROOT=_build-f1dm)

- `mix test` divergence_close + filter_schema_test + filter_schema_executed_test +
  filter_schema_facts_test: 31 tests, 1 failure (the facts pin) before re-pin; after re-pin
  `mix test` facts + divergence_close: 17 tests, 0 failures, exit 0.
- `mix format --check-formatted` on the three changed files: exit 0.
- `mix ash_surface.parity --json`: exit 1 (other lanes' slices). counts: pass 218, divergence 0,
  non_goal 79, broken 35, missing 71 of 403. Filter-section cells: no `filter` section exists;
  filter-related ids (`codegen.module.Codegen.FilterTypes`) non_goal, none missing or broken.
  No missing/broken id mentions filter, aggregate, or tenant (one `TenantRequired` error id is
  an `any_of` shape defect in another lane's slice).

## Vectors needing regeneration

Conformance vectors rendering filter schemas with explicit `operators` plus `functions`.

## Falsifier

A reference filter function outside the four whitelisted names appearing as an operator in
`filter_types.ex`, or a `functions` entry mapped here but absent from `@function_atom_to_key`.
