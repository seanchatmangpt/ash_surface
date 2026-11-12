# Wave 3 RZ: route argument key formatting

Standing: PARTIAL_ALIVE

## Reference finding (divergence from RW's raw pin)

ash_typescript formats route argument names, it does not emit them raw:

- `typed_controller/codegen/route_renderer.ex:147,155,357,381`: query/body/zod keys use
  `format_output_field(arg.name)`.
- `route_renderer.ex:417,426,474`: path param object keys and interpolation variables are
  `format_output_field(param)`; the URL template placeholders stay the router's verbatim.
- `request_handler.ex:324,338-344`: server maps client names back (output formatter table,
  else input formatter parse), covering path params arriving under router segment names.

## Change

- `lib/ash_surface/compiler/route_schema.ex`: params/query/body keys via
  `FieldName.emitted/1` once; `path`/`path_params` verbatim; `field_names`
  (`params`/`query`/`body`: client name => server name) added to route facts; collisions refused
  by `EmittedKeys.check/2` as `{:emitted_key_collision, {:route, name}, key, names}`.
- Re-pinned: RW route test in `formatter_single_emission_test.exs` (all four formatters, hostile
  names url_id, is_active?, éa_b, id2_x, __x; node+zod accept formatted / reject internal where
  differing / reject wrong types; template + inverse table asserted) plus a collision test.
  Two older pins updated to the lawful behaviour: `ported/typed_controller/codegen_test.exs`
  (`userId:`), `emitted_key_collision_renderers_test.exs` (fooBar/foo_bar now refused).
- Not done: mapped per-argument names (no such field in the route arg descriptor): UNSUPPORTED
  here. Shim-court non-vacuity not run: UNVERIFIED. IR digest/conformance not regenerated.

## Gates (MIX_BUILD_ROOT=_build-rz, un-piped rc)

- `mix test test/ash_surface/compiler test/ash_surface/ported/typed_controller`: rc=0,
  444 tests, 0 failures, 13 skipped.
- `mix ash_surface.parity.tests`: rc=0 (files=264 unaccounted=0 broken=0).
- Build root deleted.
