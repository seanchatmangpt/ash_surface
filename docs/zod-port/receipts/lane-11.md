# Lane 11 Receipt

Standing: PASS

## Files changed
- lib/ash_surface/compiler/section/channel.ex (new)
- test/ash_surface/section_channel_test.exs (new)

## Behavior
`Channel.build(discovery, opts)` reads string-keyed `"channels"` once; returns
`{:ok, [%Channel{name, topic, events: [%Event{event, payload_name, zod}]}]}`, sorted by
name/event. Payload via `ZodType.fragment/1` (nil payload -> `z.unknown()`). Non-map payload ->
`{:error, {:non_map_payload, channel, event, payload}}`. Same payload name (`<Camel>Payload`) with
differing schemas -> `{:error, {:payload_name_conflict, name, schemas}}`. No second discovery.

## Commands
- `MIX_BUILD_ROOT=_build-lane11 mix test test/ash_surface/section_channel_test.exs` rc=0,
  "3 tests, 0 failures" (emitted zod passes `ZodGuard.expression/1`; build deterministic).
- Build dir `_build-lane11` deleted.

## Requests
- Lane 17: wire `Section.Channel` into the compiler (it takes a discovery map, not the per-action
  `(action, context)` Section behaviour, so it does not declare `@behaviour`).
- Lane 18 (not mine): compile warning, heredoc indentation at projectors/js/inference.ex:14.

## Falsifiers
- ZodType.fragment output shape changes -> test still only asserts ZodGuard admission, not bytes.
