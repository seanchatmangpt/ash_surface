# Wave 3 Receipt: Lane CK (I13) and Lane CQ

Standing: PASS

## Lane CK (I13)

- `lib/ash_surface/compiler/section/channel.ex:56` returns
  `Enum.uniq(carried ++ missing_returns(channels))`, so warnings are deduplicated in the lib.
- `Enum.uniq` is removed from `channel_payload_test.exs`; grep for `Enum.uniq` in that file
  returns zero matches.

## Lane CQ (alert_cleared payload)

- Defect: "per-type payload mapping" at `channel_payload_test.exs:341` got
  `[false, false]`, expected `[true, false]`.
- Cause: premise rot in the test. Payload keys are emitted camelCase by default
  (reference-parity behaviour), so the schema key is `clearedAt`; the test sent `cleared_at`,
  which the strict object rejects. The renderer (`zod_type.ex`, `z.iso.datetime()`) is correct.
- Fix: test payloads re-pinned to `clearedAt`. No lib change.
- Command: `MIX_BUILD_ROOT=_build-cq mix test test/ash_surface/ported/typed_channel`
  - before: rc=2, 38 tests, 1 failure, 8 skipped
  - after: rc=0 (captured un-piped), 38 tests, 0 failures, 8 skipped
- Pre-existing vs session: `git log` shows no commits for the three suspect files; they are
  uncommitted working-tree changes, so introducing commit is UNVERIFIED.
