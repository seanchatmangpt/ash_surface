# Wave 2 ZG: zod guard regex tightening

Standing: PASS

## Files

- `lib/ash_surface/projectors/js/zod_guard.ex` (regex token + flag check + moduledoc)
- `test/ash_surface/zod_guard_regex_test.exs` (NEW, 24 cases)
- Existing guard tests unchanged and green.

## Change

- Flags lexed as letters, then must be a subset of `dgimsuvy` with no duplicate
  (`{:error, {:zod_regex_flags, flags}}`).
- Body refuses raw LF, CR, U+2028/U+2029 (byte-level lookahead; no `u` modifier, because `u`
  made `Regex.run` raise on invalid UTF-8 and broke the totality property test, caught by run).
- Bare `[` in the body now must open a class, so `/[/` is unterminated (previously lexed as a
  regex). Unterminated still refused.
- Moduledoc: guard is lexical only; cannot detect JS-invalid regex; safety is
  `ZodType.regex_safe_for_js?/1`.

## Commands

The full test env does not compile (not my files): `test/support/channel_fixtures.ex:60`
raises `Spark.Error.DslError` (pub_sub publish needs `transform` with `returns`), so
`mix test` aborts at compile. Used `MIX_BUILD_ROOT=_build-zg mix run /tmp/zg/runtests.exs
<files>` (ExUnit via Code.require_file, dev env):

- regex, grammar, projectors/js/zod_guard_test, decode_boundary files:
  `2 properties, 68 tests, 0 failures` (final run, exit 0).
- Admitted (tested): `/a/i`, `[/]`, `/a/dgimsuvy`, strict, passthrough, gt/lt, min/max,
  z.iso.*, z.uuid, z.enum, z.literal, z.union, z.discriminatedUnion, z.record, z.any,
  z.unknown, `1.0e20`, `1e+21`. Refused: `/a/zz`, `/a/ii`, `/a/gig`, LF in body/class/escape,
  U+2028/9, unterminated (`/abc)`, `/[/)`).

## Emitter sweep (before merge; scripts /tmp/zg/sweep.exs, s2.exs, s3.exs)

290 OK, 0 REFUSE across: ZodType.fragment over every kind x 8 constraint sets (match with
slashes, lengths, min/max incl. 1.0e20 and 1.0e21, gt/lt, one_of), UnionSchema members and
facts, SelectionSchema, QuerySchema (pagination, sort, get, offset/keyset results),
FilterSchema, CalculationSchema (+aggregates), RelationshipSchema load, IdentitySchema get,
ErrorSchema base/union/all variants, RouteSchema bodies/params/query/response,
EmbeddedSchema. No real refusal found; guard not loosened.

## Findings

- (3) `test/ash_surface/projectors/js/zod_guard_test.exs` exists (60 lines), meaningful
  (admitted constraint chains + refused set with typed reasons). Git tracking not checked
  (no git per lane law); register D-L24-2 says untracked, so it needs staging.
- `render_union_schema` takes atom-key facts (`kind` atom); string-key facts yield
  `invalid_union_fact` (not a guard issue).

## UNVERIFIED

- Full `mix test` and tests via the real test env (blocked by channel_fixtures.ex above).
- Constraint sets beyond those listed; emitters were fed hand-built fixtures, not real
  Ash resources. Concurrent lanes may change emitters after this run.

## Requests

- Owner of `test/support/channel_fixtures.ex`: add `transform` to the publication at line 60.
- Coordinator: stage `test/ash_surface/projectors/js/zod_guard_test.exs` and the new regex test.
