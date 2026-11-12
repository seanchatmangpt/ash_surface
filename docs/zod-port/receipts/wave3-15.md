# Wave 3 Lane 15: Declaration Order + Mapped Fields Projector Tests

Standing: PARTIAL_ALIVE

## Files

- test/ash_surface/projectors/js_declaration_order_test.exs (new, 8 tests + 1 skip)
- test/ash_surface/projectors/js_mapped_fields_test.exs (new, 6 tests + 1 skip)

## Commands

`MIX_BUILD_ROOT=_build-w315 mix test test/ash_surface/projectors/js_declaration_order_test.exs
test/ash_surface/projectors/js_mapped_fields_test.exs` -> 15 tests, 0 failures, 2 skipped.
`mix format --check-formatted` on both files -> exit 0.

## Coverage

- Diamond A->B->D->E, A->C->D->E: EmbeddedSchema output embedded as response schema in the
  generated .mjs; real node + real zod import it and parse valid/invalid payloads (no
  ReferenceError/TDZ). Leaf-first inline expansion, array-wrapped dep, missing dep.
- Determinism and resource-map-order independence; cycle -> {:error,{:cyclic_schema,path}};
  cycle_depth terminal z.record, artifact still executes.
- Mapped names as keys, non-identifier keys quoted, nullable/optional, sorted map-form fields,
  node parse of mapped/quoted keys.

## Loud skips (unsatisfiable by design / pending)

- shared-const Kahn topological declaration order: ash_surface inlines embedded resources.
- per-action accept/argument zod consts with mapped names (generate_zod_schema/3 analogue):
  FieldName not wired into compiler (per wave3-02).

## UNVERIFIED

- wave3-05.md absent at fill (IN-FLIGHT-AT-FILL): tests use hand-built definitions, not
  fixtures typed_containers.ex / mapped_names.ex. Real-resource-driven cases not run.
- Reused test/js/generated_schema_wiring_runner.mjs (owned by w3-02), read-only.

## Requests

- No lib/ bugs found. Once w3-05 lands, a follow-up can drive the diamond from NodeA fixtures.
