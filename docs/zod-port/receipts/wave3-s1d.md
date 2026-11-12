# Wave 3 S1-D Receipt

Standing: PASS

## Commands

- `mix test channel_discovery_test section_channel_test no_local_do_test` (MIX_BUILD_ROOT=_build-s1d): 23 tests, 0 failures, exit 0
- `node --test test/js/channel_transport.test.mjs`: 7 pass, 0 fail, exit 0
- `mix format --check-formatted` on 2 lib + 2 test files: exit 0
- `_build-s1d` deleted.

## Fixed

- H4: payload-name conflicts are scoped per channel (same name, different shape, same
  channel: refused). Across channels a clash is namespaced `<Channel><Event>Payload`.
- L9: `render/1` returns EmbeddedSchema errors (no fail-open fragment); payload names use
  `identifier/1` (valid JS identifier, deterministic); depth cap throws
  `{:depth_exceeded, mod, 8}` caught in discover as `{:error, {:max_depth_exceeded, mod, 8}}`;
  `match` carried as `match` + `match_flags`.
- L10: transport `events.emit`/`onError` throws are contained, reported to `onError`, and
  always recorded in the returned `errors` array.

## Registered (not changed)

- H4 first input (event "created" from two resources in one channel) stays
  `{:duplicate_event, ...}`: ash_typescript `VerifyTypedChannel.verify_unique_event_names`
  requires unique event names across a channel's resources (parity, existing tests pin it).

## Files

- lib/ash_surface/compiler/channel_discovery.ex
- lib/ash_surface/compiler/section/channel.ex
- priv/static/ash_surface_channel_transport.mjs
- test/ash_surface/channel_discovery_test.exs, section_channel_test.exs,
  test/js/channel_transport.test.mjs (fixtures untouched)
