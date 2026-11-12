# Wave 2 lane rc: routes, channels, envelope

Standing: PASS

## Files

- lib/ash_surface/compiler/route_schema.ex (edited)
- lib/ash_surface/compiler/route_schema/introspector.ex (new)
- lib/ash_surface/compiler/section/channel.ex (edited)
- lib/ash_surface/compiler/channel_discovery.ex (new)
- lib/ash_surface/envelope.ex (new)
- test/support/channel_fixtures.ex (new; Item, Alert, Scalar, Dup over Ash.Notifier.PubSub)
- tests: route_schema_test, route_introspector_test, section_channel_test,
  channel_discovery_test, envelope_test (all under test/ash_surface/)

## Commands

`MIX_BUILD_ROOT=_build-rc MIX_ENV=test mix test` on the five test files above:
`31 tests, 0 failures` (exit 0 by output). Node-executed Zod parse (real node + zod
from node_modules) ran for route params/query/body and a discovered channel payload.
Ash.Notifier.PubSub ships with ash 3.33.11 (fixtures compile and discover).

## Behavior changes

- Route args: missing `allow_nil?` is nullable; path params must say false
  (`path_param_nullable`); `mounts` drives `path_param_sometimes_present`;
  `duplicate_route_name` keyed by name + scope_prefix; `scope_prefix` in descriptor;
  `returns` + constraints; `ZodType.fragment` called directly.
- Channel: `duplicate_event`, `returns_kind` -> `non_object_payload`,
  `build_with_warnings/2`; container payloads render via `EmbeddedSchema`.
- `Channel.build/2` return shape unchanged.

## UNVERIFIED

- Full `mix test` (VM-exit abort pre-existing); only targeted files run.
- Integration with compiler.ex calling ChannelDiscovery/Envelope (not owned).
- Channel payload `ZodType` definition shape for nested unions/type_refs beyond fixtures.

## Requests

- Another lane owning compiler.ex may call `ChannelDiscovery.discover/2` and
  `Channel.build_with_warnings/2` to surface warnings.
