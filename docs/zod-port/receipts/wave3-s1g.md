# Wave 3 S1-G receipt: union / embedded / validation-error schemas

Standing: PARTIAL_ALIVE

## Commands
- mix test (union, embedded, error_schema_deep, s1g courts, no_local_do, zod_type_parity,
  calculation_schema_kinds, section_channel, projectors/): 175 tests, 1 failure (exit 2),
  the failure is `js_schema_wiring_test.exs:44` (expects `.regex(new RegExp(`; ZodType regex
  literal emission, outside owned files; not touched by this lane).
- mix test embedded + s1g courts + union + no_local_do: 57 tests, 0 failures (exit 0).
- mix format --check-formatted on changed lib/test files: exit 0.
  (`error_schema_deep_test.exs` was already unformatted pre-lane; only 2 lines edited, left.)

## Fixed
- M7: union container members now thread resources/cycle_depth/schema_suffix/non_resources;
  enum members keep `values`; `.nullable()` deduped; duplicate tags -> `{:error,{:duplicate_tag,t}}`;
  name==tag/discriminator and discriminator `value` collision -> `{:error,{:duplicate_member_key,..}}`.
- M8: ValidationErrorSchema inlines resource references from `:resources` (record fallback if
  unknown, `:cycle_depth` option); no bare identifiers, so guard admits. EmbeddedSchema default
  suffix now `Config.zod_schema_suffix()`.
- L2: atom-keyed fields (both modules), typed `{:invalid_field,f}`, `.strict()` on empty struct,
  `:max_bytes` cap -> `{:schema_too_large,bytes,cap}` in both, `__` key quoting in both.
- Courts: test/ash_surface/compiler/s1g_schema_courts_test.exs (real zod under node + ZodGuard).
- Re-pinned (reason in test comments): embedded suffix PostZodSchema/DateZodSchema, empty struct
  `.strict()`, validation-error resource refs inlined/record.

## Registered (not fixed)
- EmbeddedSchema still emits bare `<Name><Suffix>` references for instance_of resources
  (moduledoc: declaration-site reference; schema.ex callers depend on it); not guard-admissible.
- `map_error_type/2` raises ArgumentError on schema_too_large (render/2 returns typed error).
- No config.ex/zod_guard.ex edits (no blockers).

## Files
lib/ash_surface/compiler/{union_schema,embedded_schema,validation_error_schema}.ex;
test/ash_surface/compiler/{s1g_schema_courts_test,embedded_schema_test}.exs;
test/ash_surface/error_schema_deep_test.exs. `_build-s1g` deleted.
