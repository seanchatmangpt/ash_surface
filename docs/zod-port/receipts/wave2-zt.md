# Wave 2 lane zt: ZodType port

Standing: PARTIAL

## Files changed
- lib/ash_surface/compiler/zod_type.ex
- test/ash_surface/zod_type_core_test.exs (regex pin re-pinned to `^a\/b\d$`)
- test/ash_surface/zod_type_wave2_test.exs (new, 8 tests)

## Delivered
1. Regex literal: only unescaped `/` escaped; backslash pairs untouched.
2. `regex_safe_for_js?/1` (public) omits PCRE-only patterns; `match_flags` (i/m/s) emitted sorted.
3. float/integer `greater_than`/`less_than` -> `.gt/.lt` after min/max; array
   min_length/max_length applied after `z.array(..)`; string `allow_empty?: false` ->
   `.min(max(min_length||1,1))` only when key present.
4. Kinds: uuid_v7 time_usec duration_name url_encoded_binary module file function any keyword
   tuple struct; `enum` reads "values" (empty/absent -> z.string()).
5. `allow_nil` and `has_default` accepted.
6. Overrides: binary exprs only, module keys via inspect, keyword/garbage config tolerated;
   `unmappable_kinds/2` walks items/item_type/fields/members.
7. Fallbacks unified to `z.unknown()`.

## Commands
- `MIX_BUILD_ROOT=_build-zt mix test test/ash_surface/zod_type_{core,parity,wave2}_test.exs`
  -> exit 0, 18 tests, 0 failures.
- ZodGuard files (decode_boundary_zod_guard, zod_guard_grammar, zod_guard_regex,
  projectors/js/zod_guard) -> exit 2, 67 tests + 2 properties, 2 failures, both in
  lib/ash_surface/projectors/js/zod_guard.ex (other lane, in flight): `regex(/[/)` admitted;
  `admit/1` raises ArgumentError on invalid-UTF8 binary `<<128>>`. Not caused by this lane.
- Earlier in session zod_guard.ex had a SyntaxError (line 74); owner fixed it before the runs above.

## UNVERIFIED
- Full `mix test` not run. No ZodType call sites in Schema/Expo re-run (golden churn unknown).
- Enum value order is sorted (matches one_of), not source order; ref order not compared.

## Requests to other lanes
- schema_constraint_test.exs:99-102 (not found at test/ash_surface/schema_constraint_test.exs;
  owner lane must locate) pins the old doubled-backslash regex output; re-pin to single backslash.
- Golden/digest churn: any golden containing `.regex(` with backslashes, fallback
  `z.unknown().optional()` -> `z.unknown()`, new `.min(1)` on allow_empty? false, `.gt/.lt`,
  array `.min/.max` will change; regenerate conformance vectors/digests.
- zod_guard.ex owner: the two failures above.
- Containers/unions not routed in ZodType (cycle with EmbeddedSchema); remain for Schema layer.
