# wave3-rl

Standing: PASS

Lane RL (build root `_build-rl`, deleted at finish). Both RI observations re-checked against the
reference; neither is a divergence, so no lib change and no KD row.

## Findings

1. Tenant: reference `Rpc.Pipeline.parse_request` takes `normalized_params[:tenant]` or the conn
   tenant and never demands one (pipeline.ex:74-82, 204). The only `tenant_required` in the
   reference is `defimpl Rpc.Error, for: Ash.Error.Invalid.TenantRequired` (error.ex:222), raised
   by Ash at execution (stage 2, not ported). ash_surface: `AshSurface.Errors` maps the same
   struct to `tenant_required` (errors.ex:249). A bare `{:tenant_required, _}` tuple is no clause
   in either. Parity already holds.
2. Private arguments: `parse_action_input` and `InputFormatter` are line-for-line the reference
   (diff shows only module-alias renames). Reference tests for private arguments are codegen-only.
   Parity already holds.

## Changes (tests only)

- `rpc/d/rpc_pipeline_surface_test.exs`: added test that a real
  `Ash.Error.Invalid.TenantRequired` yields type `tenant_required` / "Tenant required"; relabelled
  the observation tests as reference parity.
- `rpc/c/private_arguments_surface_test.exs`: comment states reference parity.

## Commands

- `mix test test/ash_surface/ported/rpc test/ash_surface/no_local_do_test.exs`: 1786 tests, 1
  failure, 213 skipped. The failure is `rfp/requested_fields_processor_typed_structs_test.exs:495`
  (`:bogus` vs `"bogus"`), untracked file owned by another lane, not touched here: UNVERIFIED cause.
- Owned two files + no_local_do_test: rc=0, 50 tests, 0 failures.
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0 (first run, no rerun needed).

## Falsifier

Reference gaining a parse-time tenant demand or private-argument refusal.
