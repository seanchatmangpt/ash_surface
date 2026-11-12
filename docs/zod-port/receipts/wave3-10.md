# Wave 3 Lane 10 Receipt

Standing: PARTIAL

## Files

No edits by this lane. Pre-existing working-tree edits (other lanes, wave 2) already in place:
`.formatter.exs` (projection: 1 and 2 in locals_without_parens + export),
`test/ash_surface/formatter_registration_canary_test.exs` (sentinel
`AshSurface.RetiredFormatterTarget`), `test/ash_surface/projector/expo_receipts_hash_test.exs`
(`@golden_hash` is `9c93b831...`, equal to sha256 of `@expected_preimage`; assertion at line 63
intact, not weakened).

## Commands

- `MIX_BUILD_ROOT=_build-w310 mix test test/ash_surface/formatter_registration_canary_test.exs
  test/ash_surface/formatter_export_test.exs test/ash_surface/projector/expo_receipts_hash_test.exs`
  -> 13 tests, 0 failures, exit 0.
- `mix format --check-formatted test/ash_surface/resource/*.exs` -> exit 1; only
  `validator_action_types_test.exs` is unformatted (line-length wraps, not projection parens;
  file owned by another lane).

## Stray artifacts

- Removed: `erl_crash.dump` (13 MB; lsof showed no holder; no mix test running), `_build-w310` (own).
- Left: `tmp/l11_example.exs` (1128 B, report only), `_build-b1a` (314M), `_build-b1b`,
  `_build-coord` (314M), `_build-w303..w309`, `_build-w312..w319` (lanes possibly running).
  `_build-w302` vanished during the lane (removed by another lane, not me). Main `_build` untouched.

## UNVERIFIED

- Whether `.formatter.exs` change is what fixed the canary/export tests vs. a concurrent lane
  (state was already green when first read).

## Requests

- Owner of `test/ash_surface/resource/validator_action_types_test.exs`: run `mix format` on it.
