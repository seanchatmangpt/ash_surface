# Wave 3 Lane RAN: mapped name vs computed spelling

Standing: PASS

Subject: RAK surviving mutation in the typed_query cross-domain read path (mapped-name handling
masked because fixture mapped spelling equals computed camelCase).

## Change

- New `test/ash_surface/ported/rpc/ran/mapped_name_vs_computed_test.exs`: inline resource with
  `field_names(is_ready?: "ready", line_1: "lineOne")` (computed: `isReady`, `line1`), real
  manifest + `Pipeline` + `TypedQuery`; exact output-key assertions, formatter scopes
  (snake/pascal/camel), computed spelling refused as a selector.
- Real defect exposed (disclosed lib edit): `lib/ash_surface/runtime_parity/rpc/typed_query.ex`
  built the client field request with plain camelCase, ignoring `field_names`, so a typed query
  over a mapped field was refused `unknown_field`. Top-level names now resolve via
  `FieldName.wire(resource, name, formatter: :camel_case)`; nested levels remain camelCase
  (UNVERIFIED for mapped nested resources).

## Commands

- `mix test test/ash_surface/ported/rpc/ran` -> 5 tests, 0 failures.
- `mix ash_surface.parity.tests` -> rc=0 (unaccounted=0 broken=0).

## Shim-court (`/tmp/ran/court.exs`, in-memory recompile, files untouched on disk)

Baseline sha256 equals post-run sha256 (disk never written): field_name.ex 6c40bfe9...,
typed_query.ex 3222fb46..., rpc/field_formatter.ex 7a4f6dca...

| mut | file | result |
|---|---|---|
| 0 none | - | 0 failures / 5 |
| 1 typed_query wire -> compute | typed_query.ex | RED 1 failure |
| 2 mapped branch -> compute | rpc/field_formatter.ex | RED 3 failures |
| 3 wire override -> emitted | field_name.ex | RED 2 failures |
| 4 format_field_for_client -> compute | field_name.ex | SURVIVES (path not used by pipeline) |

Falsifier: any of mutations 1-3 passing the file. Mutation 4 is unreached, not claimed killed.
