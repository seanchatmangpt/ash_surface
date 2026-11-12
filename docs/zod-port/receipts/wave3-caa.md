# Wave 3 CAA: identity_tenant fixture DslError

Standing: PASS

Cause: `Account` identities on `Ash.DataLayer.Ets` lacked `pre_check_with`
(Ash.DataLayer.Verifiers.RequirePreCheckWith). Fix: `pre_check_with:` set to the fixture Domain
on both identities in `test/support/zod_fixtures/identity_tenant.ex` (only file edited).

- `MIX_ENV=test mix compile --force --warnings-as-errors` before: rc=1 (DslError); after: rc=0.
- `mix test test/ash_surface/ported/typed_controller`: rc=0, 101 tests, 0 failures, 13 skipped.
- identity_tenant_fixture_test + s1i_identity_selection_fieldname_test: rc=0, 14 tests, 0 failures, 0 DslError.
- Other warnings: only in deps (toml lib/decoder.ex single-quoted charlists, forced recompile);
  none in ash_surface.
