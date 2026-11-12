# Wave 3 Lane 17 Receipt

Standing: PARTIAL

## Files
- priv/static/ash_surface_runtime.mjs: VOCABULARY gains `issueShapeKeys`, `issueRefusalCodes`.
- lib/ash_surface/vocabulary.ex: `issue_shape_keys/0`, `issue_refusal_codes/0`, `to_map/0` keys.
- NEW test/js/runtime_issue_vocabulary.test.mjs; NEW test/ash_surface/vocabulary_issue_twin_test.exs.

## Commands
- `node --test` (issue vocab, version_sync, runtime_hardening, zod_boundaries,
  idempotency_retry, transport_law): tests 153, pass 153, fail 0.
- `mix test` vocabulary_issue_twin, vocabulary_drift, vocabulary_test: 13 doctests,
  10 tests, 0 failures (exit 0). The drift test enforces JS/Elixir key-set equality.

## Known divergences
- (a) refusal pattern: already aligned before this lane. Runtime pattern is
  `^REFUSED_[A-Za-z0-9_]+$`, and no refusal entry exists in
  conformance/js/known_divergences.mjs. Nothing to close; w3-04 need drop none.
  docs/CONFORMANCE.md:116-136 may still describe it as open (not my file).
  Twin ExUnit test pins the multiline vectors on the Elixir side.

## UNVERIFIED
- Item (3) helpers not exported. Not compared against conformance/js/reference.mjs.
- Zod issue `code` values are not enumerated (zod-version-dependent); only the shape is pinned.
- No version bump was needed (still 26.10.8).

## Requests
- w3-04: conformance MANIFEST/docs may reference the vocabulary; add the two new keys if
  vectors pin the vocabulary dump.
- Owner of js.ex: its safeParse path (line ~578) emits the same path/message/code shape;
  no twin pin exists on the Elixir projector side.
