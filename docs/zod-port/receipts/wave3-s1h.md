# Wave 3 S1-H Receipt (Expo schemas, route schema)

Standing: PARTIAL_ALIVE

Lane S1-H, M9/M10/M11. Build root `_build-s1h` (deleted at end).

## Commands

- `mix test` court + route_schema + route_introspector: 23 tests, 0 failures (exit 0)
- `mix test test/ash_surface/projector test/ash_surface/route_schema_test.exs
  test/ash_surface/route_introspector_test.exs test/ash_surface/no_local_do_test.exs`:
  110 tests, 2 failures (exit 2) -- both PRE-EXISTING, not session-introduced
  (`act_decimal must accept {"f":2}`: ZodType maps decimal to z.string();
  `untyped must accept {}`: required z.unknown() key). Neither file is owned here.
- `mix format --check-formatted` on the 5 changed files: exit 0 (after `mix format`).

## Fixed

- M9: input schema = writable public attributes of the action's resource (id/inserted_at
  excluded; has_default and nil-able omittable); unknown resource gives
  `{:error, {:unknown_resource, id, name}}`. ZodGuard.expression/1 runs on each schema.
- M10: collision-free stems (all colliding ids get an 8-hex sha256 suffix), leading-digit
  `_` prefix, nil id `{:action_without_id, _}`, duplicate ids refused, SCHEMAS keys via
  JSON/computed key (`__proto__` safe), ACTIONS emitted key-sorted via OrderedObject and
  refuses `__proto__` keys (`{:proto_key_refused, "ACTIONS"}`). Node-executed: colliding
  module loads cleanly.
- M11: arg keys quoted / computed (`page[size]`, `user-id`, `__proto__`); nil name and
  duplicate names refused; glob `*path` params extracted (RouteSchema + Introspector);
  integer/float path and query args accept numeric strings via z.preprocess (blank and
  junk rejected), executed under node. ash_typescript has no coercion, so this is an
  ash_surface improvement proven by the court, not a registered divergence.

## Files changed

- lib/ash_surface/projector/expo.ex
- lib/ash_surface/compiler/route_schema.ex
- lib/ash_surface/compiler/route_schema/introspector.ex
- test/ash_surface/projector/expo_wave3_s1h_court_test.exs (new)
- test/ash_surface/projector/generated_artifacts_exec_test.exs (re-pinned)

## Re-pins (reason: M9 removes non-writable `id` from inputs, unknown resource now errors)

- invalid `id: "not-a-uuid"` cases replaced by `cost_physical: 1.5`; uuid-weakening mutation
  replaced by integer-weakening; dropped-`status` case replaced by dropped `member_id`
  (status has a default); `unresolved` degrade case removed (now a typed error).

## Registered / not done

- Contract actions carry no per-action inputs/accepts, so inputs derive from manifest
  resource fields (writable flag), not Section.Schema's discovery map. Section.Schema was
  not called (its inputs are Ash-introspected, absent from the surface contract).
