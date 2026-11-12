# Wave 3 Lane F1-CR: conformance corpus regeneration

Standing: PASS

Subject: /Users/sac/ash_surface working tree (uncommitted; no SHA minted, no git state commands run).

## Wait-gate

wave3-f1sg.md and wave3-f1ff.md were both present when the 20-minute poll finished (poll
exited 0, both listed). Nothing proceeded undisclosed.

## Commands and exits

- `MIX_BUILD_ROOT=_build-f1cr MIX_ENV=test mix run scripts/conformance_regen.exs` exit 0;
  "conformance: 788 vectors in 21 files" (log /tmp/f1cr-regen.log).
- JS replay via `replayCorpus()` from conformance/js/replay.mjs under node v26.10.0, exit 0:
  PASS 578, NOT_APPLICABLE 200, KNOWN_DIVERGENCE 10, FAIL 0, total 788.
- `MIX_BUILD_ROOT=_build-f1cr MIX_ENV=test mix test test/conformance` exit 0: 28 tests,
  0 failures (Elixir runner replays every vector; mutation tests prove replay can fail).
- `_build-f1cr` deleted.

## Diff of regenerated corpus against pre-run snapshot

Only two files moved:

- conformance/vectors/query_envelope.json: keyset result zod `previousPage`/`nextPage`
  changed from `z.string()` to `z.string().nullable()` (qe/keyset-result and the mixed-union
  vector). Cause: query-envelope renderer change landed by another wave-3 lane; the
  corpus was stale against it.
- conformance/MANIFEST.json: sha256 of query_envelope.json only.

conformance/vectors/ir_codec.json was byte-identical before and after regeneration (it
carries neither 85e3b3ca nor 52edac14 as text; it was already current against the w3-01
IR; the golden digest 52edac14 is pinned in test/ash_surface/ir_codec_golden_test.exs).
No stale ir_codec vector or MANIFEST ir_codec hash remained to repair.

## uuid_v7 mirror

Vector `c/kind-uuid-v7` already exists in constraints.json (Elixir: `z.uuid()`). The JS
reference mirror disagreed (`uuid_v7: "z.guid()"` in conformance/js/reference.mjs);
fixed to `z.uuid()`. JS replay of c/kind-uuid-v7: PASS.

## Falsifier

A moved vector without a named cause, or any FAIL in the JS replay, or any failing
test/conformance test.
