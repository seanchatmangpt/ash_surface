# Wave 3 Lane G2b: Route Presentation Options

Standing: PARTIAL

5 of 8 remaining G2 ids closed (pass); 3 remain MISSING pending operator decision.

## Ids closed (pass)

dsl.typed_controller.dsl.entity.route.option.{description, deprecated, see, namespace,
zod_schema_name}.

## Implemented

- `lib/ash_surface/compiler/route_schema.ex`: `build_one` merges `presentation/1`. Descriptors
  carry `description`, `deprecated`, `see`, `namespace`, `zod_schema_name`; `description` is
  applied to the `response` fragment as `.describe(...)`; `jsdoc` renders `@deprecated`/`@see`
  (`*/` neutralised); `schema_declaration` is `export const <name> = <response>;`. Absent
  options add no keys.
- `test/ash_surface/dsl/route_presentation_parity_test.exs`: 5 courts; description and
  zod_schema_name execute under node + zod (real `safeParse`, `.description`).
- `parity/court_map.json`: 5 entries added (targeted insert).

## Commands

- `MIX_BUILD_ROOT=_build-g2b mix test test/ash_surface/dsl/route_presentation_parity_test.exs
  test/ash_surface/route_schema_test.exs
  test/ash_surface/dsl/typed_controller_channel_parity_test.exs` -> 27 tests, 0 failures, rc 0.
- `mix ash_surface.parity --json` -> dsl missing now only the 3 ids below; no errors on
  route.option rows. Global at write time: pass=217 non_goal=79 broken=36 missing=71 (broken
  rows are other lanes').
- `mix format --check-formatted` on the two changed files -> rc 0. `_build-g2b` deleted.

## Operator decisions (still MISSING)

1. `route.option.valibot_schema_name`: proposed non_goal; README has no Valibot statement.
   Proposed wording: "Zod is the only validation target; no Valibot schemas".
2. `typed_controller.option.module_name` / `option.namespace`: the DSL has no typed_controller
   section (descriptor-only RouteSchema), so no Info accessor exists. `module_name` names a
   generated Phoenix controller (conflicts with "it never actuates"); `namespace` is output
   file grouping. Proposed non_goal under the same README quotes as G2; not mapped.
3. Out of scope but noted: `dsl.rpc.entity.rpc_action.option.deprecated` is still MISSING.

## Files changed

lib/ash_surface/compiler/route_schema.ex, test/ash_surface/dsl/route_presentation_parity_test.exs,
parity/court_map.json, this receipt.
