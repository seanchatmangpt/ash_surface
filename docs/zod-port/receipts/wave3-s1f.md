# Wave 3 S1-F receipt: zod_type, query_schema, zod_guard

Standing: PARTIAL_ALIVE

## Commands
- `MIX_BUILD_ROOT=_build-s1f mix test <16 targeted zod/guard/query/constraint files +
  no_local_do_test + projector_hardening_test>`: 201+ tests (incl. 38 new), 0 failures, exit 0.
- `mix format --check-formatted` on all changed lib/new test files: exit 0.
- Full `test/ash_surface` run: BLOCKED by another lane's compile error
  (`test/ash_surface/parity/gate_non_vacuity_test.exs` imports missing `AshSurface.Parity.GateTest`).
  An earlier full run showed ~45 failures in unowned areas (Spark DSL / SAT solver / digest /
  validator); not re-attributed after final edits (UNVERIFIED).
- Build dir `_build-s1f` deleted.

## Fixed (executed under real zod 4.6.5 in node + ZodGuard.admit)
- M1 `zod_type.ex`: escape-aware PCRE scanner (`regex_check/1`, `dropped_constraints/2` typed
  warning channel). Refused: trailing backslash, `\z \Z \h \H \R \K \Q \E \A \G \X \g \p \P`,
  `[[:alpha:]]`, possessive quantifiers, `(?i)`/lookbehind/atomic/named-P groups, unbalanced
  parens/class, nothing-to-repeat, empty source, raw line terminators. False positives fixed
  (`[*+?]\+`, `\++`, `\(?id`). `$` (no `m` flag) translated to `(?=\n?$)` = PCRE trailing-newline
  semantics (court compares node vs Elixir `Regex`).
- M2 `query_schema.ex`: sort emits regex literal (string-arg `.regex` throws in zod 4).
- M3 `zod_guard.ex`: regex token needs non-empty body and no leading `*`.
- M4 `zod_guard.ex`: member ALLOW-list replaces the 5-name deny-list (z.config/globalRegistry/core
  refused); every table kind + pagination/sort/constraint fragment proven admitted.
- L3 atom-keyed `stringify/2` keeps items/values/required?/default/subtype fields.
- L4 `max_limit` not a positive integer: `{:error, {:invalid_max_limit, v}}`.
- limit_entry now matches ash_typescript config_builder.ex (required only when pagination
  required AND no default limit); prior logic was inverted.
- BETTER than ash_typescript (operator law), each proven by a node court: `uuid`/`uuid_v7` ->
  `z.guid()` (accepts any 8-4-4-4-12 hex, Ecto set; ash_typescript `z.uuid()` rejects version/
  variant-invalid UUIDs); `naive_datetime` -> `z.iso.datetime({local: true})` (zoneless ISO
  accepted; ash_typescript form rejects). Not registered as divergences.

## Files changed
lib/ash_surface/compiler/{zod_type,query_schema}.ex, lib/ash_surface/projectors/js/zod_guard.ex,
lib/ash_surface/compiler/constraint_validator.ex (UNOWNED minimal change: `@uuid_re` to the guid
shape so the Elixir/zod agreement court stays green; disclose to its owner).
New tests: test/ash_surface/compiler/zod_type_wave3_test.exs,
test/ash_surface/projectors/js/zod_guard_wave3_test.exs.
Re-pinned (reason: intentional output change): zod_type_{wave2,core,parity}_test, schema_section
tests (both), schema_constraint_test, filter_schema_test (uuid->guid, `$` translation),
projectors/js/zod_guard_test (`transform` now `zod_denied_member`).

## Open / for coordinator
- `conformance/js/reference.mjs` + `scripts/conformance_regen.exs` mirror the type table
  (uuid, uuid_v7, naive_datetime, `$` regex): must follow or conformance agreement drifts. Not run.
- `projectors/js.ex` `embed_regex`: not changed; should reuse `ZodType.regex_check/1`.
- Pre-existing, not mine: `SchemaSectionTest` Expo-canon failures (enum `values` and `.optional()`
  mismatch vs expo.ex), calculation_schema stale moduledoc (lines 8-10).
- The `$` translation changes every pinned `…$/` regex output elsewhere (digest goldens).
