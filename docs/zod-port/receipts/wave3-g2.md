# Wave 3 Lane G2: DSL Entities and Options Parity

Standing: PARTIAL

27 of 35 `dsl.*` ids closed (26 pass, 1 non_goal); 8 remain MISSING (listed below).

## Commands

- `MIX_BUILD_ROOT=_build-g2 mix test test/ash_surface/dsl test/ash_surface/resource
  test/ash_surface_verifier_court_test.exs test/ash_surface/formatter_registration_canary_test.exs
  test/ash_surface/no_local_do_test.exs test/ash_surface_mock_discipline_test.exs
  test/ash_surface/typed_query_fields_test.exs test/ash_surface/errors_config_test.exs
  test/ash_surface/parity` -> 186 tests, 7 failures (all in test/ash_surface/parity gate tests,
  racing concurrent G-lane edits to court_map.json); re-run of `test/ash_surface/dsl
  test/ash_surface/parity` after the lanes settled -> 65 tests, 0 failures.
- `mix ash_surface.parity`: dsl section before 29/0/0/0/35 -> after 55/0/1/0/8
  (pass/divergence/non_goal/broken/missing). Global at write time: pass=254 non_goal=78
  broken=6 missing=65; the 6 broken rows are outside the dsl section (not mine).
- `mix format --check-formatted` on test/ash_surface/dsl/*.exs and lib/ash_surface/info.ex -> rc 0.
- ggen scratch regeneration (`/tmp/g2`, `ggen sync run --skip-ea-admission`) -> only resource.ex
  (+1 line) and ggen.lock copied back; verify.ex identical. `_build-g2` and /tmp/g2 deleted.

## Implemented

- ontology.ttl: `surf:SectionShowRaisedErrorsField` (`show_raised_errors?`, boolean) on the
  surface section; regenerated resource.ex + ggen.lock.
- `AshSurface.Resource.Info.show_raised_errors?/1` (resource option, else
  `AshSurface.Config.show_raised_errors/0`); the caller passes it to `Errors.to_errors/2`
  (lib/ash_surface/errors.ex is not owned by this lane, so the wiring is by caller).
- New courts: `test/ash_surface/dsl/rpc_surface_parity_test.exs`,
  `test/ash_surface/dsl/typed_controller_channel_parity_test.exs`.

## Per-id disposition

| id | disposition | court |
|---|---|---|
| rpc.entity.resource.option.resource | pass | rpc_surface_parity: surface section lives on the resource |
| rpc_action.option.action/name/namespace/description/see | pass (projection entity analogue) | rpc_surface_parity, one test per option (introspection, validator refusal, type enforcement) |
| typed_query.option.description / ts_fields_const_name / ts_result_type_name | pass (description / fields_const_name / result_type_name) | rpc_surface_parity |
| rpc.section.typescript_rpc | pass (surface section) | rpc_surface_parity |
| rpc.section.typescript_rpc.option.show_raised_errors? | pass (implemented) | rpc_surface_parity describe show_raised_errors? |
| typed_channel.section.typed_channel, entity.resource, resource.option.module | pass (ChannelDiscovery spec `resources: [Module \| {Module, events}]`) | typed_controller_channel_parity |
| typed_controller.section.typed_controller | pass (Phoenix router introspection analogue) | typed_controller_channel_parity |
| route entity, route options name/method/returns/constraints | pass (RouteSchema descriptor analogue) | typed_controller_channel_parity |
| argument entity, argument options name/type/allow_nil?/constraints/default | pass | typed_controller_channel_parity |
| route.option.run | non_goal, README quote "it never actuates" (already in README) | none |
| route.option.deprecated/description/see/namespace/valibot_schema_name/zod_schema_name; section.option.module_name/namespace | MISSING | see Operator decisions |

## Operator decisions

1. route `deprecated`, `description`, `see`, `zod_schema_name`: RouteSchema descriptors
   (lib/ash_surface/compiler/route_schema.ex, not owned by this lane) carry no presentation
   passthrough. Implementable as pass-through keys in `RouteSchema.build/1` output plus
   courts; needs the route_schema owner.
2. route `valibot_schema_name`: proposed non_goal; README has no Valibot statement.
   Proposed wording to add: "Zod is the only validation target; no Valibot schemas".
3. section `module_name` (names a generated Phoenix controller module) and `namespace`
   (output file grouping): proposed non_goal under "no generated `.ts`, no `.d.ts`, no `tsc`
   build step"/"it never actuates" if the operator agrees; route `namespace` is not mapped to
   `scope_prefix` (a Phoenix mount prefix is not a file namespace).
4. `show_raised_errors?` effect is caller-wired (`Info.show_raised_errors?/1` -> `to_errors`
   option); an Errors-side resource lookup needs errors.ex owner.

## Files changed

ontology.ttl, lib/ash_surface/resource.ex (generated), ggen.lock, lib/ash_surface/info.ex,
parity/court_map.json (my ids only), test/ash_surface/dsl/rpc_surface_parity_test.exs,
test/ash_surface/dsl/typed_controller_channel_parity_test.exs, this receipt.
