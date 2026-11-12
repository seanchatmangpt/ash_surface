# Wave 3 Lane 04 Receipt (conformance corpus)

Standing: PARTIAL

Regenerated with `wave2-b1a.md`, `wave3-02.md`, `wave3-17.md` present;
`wave3-01.md` was ABSENT at fill (IN-FLIGHT-AT-FILL, landed on the coordinator's
status nudge). Subject: uncommitted working tree of /Users/sac/ash_surface (no SHA).
Any lane-01 change to a renderer after this regeneration turns the Elixir replay RED
until `scripts/conformance_regen.exs` is re-run.

## Files

- conformance/elixir/runner.exs: nine new kinds, `corpus_version` 2.0.0
- scripts/conformance_regen.exs: new generators, `CONFORMANCE_OUT` scratch redirect
- conformance/js/reference.mjs: ZodType twin rewritten (full kind table, gt/lt, array
  cardinality, allow_empty?, flags, PCRE->JS translator, trailing `$`, `.guid()`,
  `naive_datetime` local), error vocabulary twin; stale `/` and backslash notes fixed
- conformance/js/replay.mjs, conformance/js/zod_eval.mjs (new), known_divergences.mjs
- conformance/vectors/*.json (21 files), conformance/MANIFEST.json (regenerated)
- docs/CONFORMANCE.md (counts re-derived), test/js/conformance_replay.test.mjs (+5 tests)
- scripts/chicago_census.txt: untouched (the regen script does not write it)

## Version

corpusVersion 1.0.0 -> 2.0.0 (MAJOR: changed `expected` for existing ids in `ir_codec` and
the constraint regex rendering; also nine new kinds). Recorded in runner.exs
(`@corpus_version`), MANIFEST.json, docs/CONFORMANCE.md (Versioning).

## Commands (MIX_BUILD_ROOT=_build-w304, deleted afterwards)

- `MIX_ENV=test mix run scripts/conformance_regen.exs` -> `conformance: 785 vectors in 21
  files`, exit 0 (12 files / 547 vectors at HEAD).
- `MIX_ENV=test mix test test/conformance` -> `28 tests, 0 failures`.
- `node --test test/js/conformance_replay.test.mjs` -> `tests 15, pass 15, fail 0`, exit 0.
  Replay statuses over 785 vectors: PASS 573, NOT_APPLICABLE 200, KNOWN_DIVERGENCE 12,
  FAIL 0.
- Non-vacuity (scratch corpus copy): flipped probe verdict (`qe/sort-plus-minus`) and
  flipped fallback fact (`tw/http/adapter-throws-after-dispatch`) both FAIL; also pinned by a
  new JS test.
- Mock grep over test/conformance, conformance/, conformance_replay.test.mjs: 0 matches.

## What was added

- constraints: 90 vectors (was 25): gt/lt, array cardinality and nested items,
  allow_empty?, regex flags, PCRE-unsafe dropped, trailing `$` translation, optional /
  default / has_default / allow_nil, ci_string/binary, new kinds, enum `values`, one_of
  numeric, integral-float rendering (`1.0`, `1.0e20` as PENDING_DECISION).
- New kinds (vector counts): filter_operators 26, query_envelope 26, selection_admission 14,
  relationship_loads 11, calculation_envelope 10, identity_get 11, error_envelope 30
  (all 20 types), union_schema 12, transport_wire 8.
- Schema-renderer kinds record the rendered zod text plus probe verdicts minted by really
  executing it under zod via node. JS twin law = execution parity (renderer refusals are
  NOT_APPLICABLE with a reason).
- transport_wire: Elixir mints the dispatch fence and the CSRF fact against real
  `Plug.CSRFProtection` (accepted header `x-csrf-token`, missing token refused); JS drives
  the real http/channel transports (real `node:http` server, hand-written channel) through
  the real client.

## Known divergences

Unchanged set from w3-17's reading: no refusal-pattern entry exists (already aligned).
Added 2 (the Erlang float lexical form rendered into zod text): `c/float-integral-min`,
`c/float-exponent-max`. Total pinned: 12.

## UNVERIFIED

- Full `mix test` (VM-exit abort); only test/conformance + the JS replay were run.
- wave3-01 renderer changes (absent at fill).
- JS twin of renderer logic exists only for `constraints`/ZodType and the error vocabulary;
  for the eight renderer kinds JS proves execution parity, not independent re-rendering.
- Union facts mode (`render_union_schema`) has no vectors (its facts shape refused the
  probe input; only `members` is covered). `aggregate_metadata` (JSDoc lines) not covered.
- Finding for the union lane: a member `tag` names the FIELD (overriding `discriminator`);
  pinned as `us/tag-overrides-discriminator`.

## Requests

- After lane 01 lands, re-run the regen script and the two replay commands above.
