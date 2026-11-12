# Wave 2 Identity Schema Receipt

Standing: PARTIAL

## Files

- lib/ash_surface/compiler/identity_schema.ex (edited)
- test/ash_surface/compiler/identity_schema_test.exs (new)

## Changes

- @zod_kinds mirror removed; key fragments via ZodType.fragment/1. allow_nil? maps to
  `.nullable()` only (identity keys are always present; no `.optional().nullable()`).
- get_by rendering delegates to QuerySchema.render_get_input_schema/1 guarded by
  Code.ensure_loaded?/function_exported?; fallback is an inline strict object. Keys come out
  sorted (QuerySchema contract). Empty-key difference kept: IdentitySchema refuses
  (`:no_admitted_identities`), QuerySchema yields `z.object({}).strict()`.
- render_tenant_schema/1: attribute/context strategy and not global? -> required
  `z.string().min(1)`, or `.optional()` when require_tenant_parameters is false; else `nil`
  (rpc.ex:643-660). render_tenant_schema/0 kept.
- Scalar-only guard: identities with map/array/union/embedded/struct/keyword/tuple/resource
  key kinds are skipped (pipeline.ex:1212-1420 semantics, render side).
- Primary-key aliasing (order-insensitive, composite) retained.

## Commands

1. `MIX_BUILD_ROOT=_build-id mix test test/ash_surface/compiler/identity_schema_test.exs`
   exit: compile error in test/support/channel_fixtures.ex:60 (other lane's file, pub_sub
   `transform` required with `returns`); 0 tests executed.
2. Workaround, `MIX_ENV=dev mix run --no-start -e` requiring test/support/zod_fixtures.ex and the
   test file under ExUnit: `6 tests, 0 failures` (includes real node + zod strict-rejection,
   uuid, nullable, tenant empty/missing).

## UNVERIFIED

- Run via the normal `mix test` path (blocked by channel_fixtures compile error, not mine).
- Any projector wiring: nothing calls these renderers yet.

## Requests

- IR must carry identities, get_by, multitenancy strategy/global?, not_found_error? through
  normalize_action.
- DSL options need resource.ex regeneration.
- Error lane: add invalid_identity / missing_identity error types.
