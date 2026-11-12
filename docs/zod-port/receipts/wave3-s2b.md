# Wave 3 S2b: RouteSchema and Section.Channel adversarial courts under real zod

Standing: PASS

Scope of PASS: the courts below, on this tree state. Full `mix test` not run (shared tree).

## Commands (MIX_BUILD_ROOT=_build-s2bb, deleted afterwards)

- `mix test test/ash_surface/adversarial test/ash_surface/compiler/s1g_schema_courts_test.exs
  test/ash_surface/no_local_do_test.exs test/ash_surface_mock_discipline_test.exs` -> exit 0,
  158 tests, 0 failures, 0 skipped.
- `mix format --check-formatted test/ash_surface/adversarial/*.exs
  lib/ash_surface/compiler/route_schema.ex` -> exit 0.
- Not completed: `mix test test/ash_surface/compiler` crashed at compile of
  test/support/ported/resources/todo.ex:230 (Spark attribute build; other lane's file,
  pre-existing, not touched).

## Courts (test/ash_surface/adversarial/route_channel_adversarial_test.exs)

Seeds 201 (RouteSchema, 200 routes), 211 (Channel payloads, 200), 221 (ChannelDiscovery.verify,
200). Every rendered expression passes ZodGuard.admit/1, is executed under real zod in node;
asserts: valid payload accepted with own keys == names, wrong-typed rejected, extra key rejected
(strict), no prototype pollution. Hostile names: quotes, backslash, newline, U+2028/2029,
constructor, prototype, unicode, `${x}`, `page[size]`, 300-char, glob/path-param collisions.

## Defect found and fixed (renderer vs ZodGuard disagreement)

- S2b-01 RouteSchema emitted computed key `["__proto__"]` for an argument named `__proto__`;
  ZodGuard refused it (`zod_unadmitted_key {:punct,"["}`), 9/200 seeded cases.
  Fix lib/ash_surface/compiler/route_schema.ex: `check_arguments/2` returns typed
  `{:error, {:denied_argument_name, route, "__proto__"}}` (consistent with EmbeddedSchema
  `denied_field_name` and IdentitySchema `identity_key_denied`); dead `object_key("__proto__")`
  clause removed. Court added for the typed error.

## Prior defects closed

- S2-01 (EmbeddedSchema `__proto__`) and S2-02 (IdentitySchema `__proto__`) are already fixed in
  lib (typed refusals); the skipped S2-01 court is un-skipped and passes.

## Other changes

- Unique tmp dirs (unique_integer + OS pid + 6 random bytes) in route_channel, support.exs and
  s1g_schema_courts_test.exs; removes the node_modules symlink race between concurrent runs.
- Path-params court uses an escaped U+2028 literal (removes compiler warning).

## Residual

- `path_params("/a/:__proto__")` still returns `["__proto__"]`; such a route is refused via the
  argument check only when an argument of that name exists (check_path_params requires one).
