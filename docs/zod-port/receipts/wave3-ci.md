# Wave 3 Lane CI Receipt

Standing: PARTIAL

- Item I11: route_channel_adversarial_test.exs executes RouteSchema and Section.Channel zod under node with real zod.
- Cause of the one red case: tree default output formatter is camel_case, so non-wire field names lose "_"; court now sets "wire" => true on channel payload fields. No lib defect; no lib edits.
- `MIX_BUILD_ROOT=_build-ci mix test test/ash_surface/adversarial/route_channel_adversarial_test.exs` x3: 7 tests, 0 failures.
- `mix test test/ash_surface/adversarial`: 133 tests, 4 failures, all in container_renderers_adversarial_test.exs (not owned; same formatter premise, seeds 15 and 23). UNVERIFIED that this is the cause.
