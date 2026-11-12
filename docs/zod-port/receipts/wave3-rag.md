# Wave 3 RAG: typed_channel channel_verify_test repair

Standing: PASS

## Cause (premise rot, test-fixture defect; lib not at fault)

`channel_verify_test.exs` aliases `AshSurface.Ported.TypedChannel.Fixtures.{Alert,Item,Review}`.
That module was defined inside `channel_payload_test.exs` (a test file). A test file that is
not loaded (isolated run) or not yet compiled (parallel file load) leaves the fixture
undefined, so `Item.entities/1` raised "not a Spark DSL module". Baseline: 11 tests, 5
failures, rc=2 (`mix test .../channel_verify_test.exs`). Bisect via file layout and mtimes:
`channel_payload_test.exs` (02:56) grew the fixtures after verify test (22:19) was written.
Not RX/RS/F1 formatter; lib unchanged.

## Fix

Moved `defmodule ...TypedChannel.Fixtures` (old lines 1-187) verbatim from
`test/ash_surface/ported/typed_channel/channel_payload_test.exs` to
`test/support/ported/typed_channel_fixtures.ex` (compiled via elixirc_paths test).
`KindFixtures` stays in the payload test. Ledger rows (parity/test_ledger.json) reference
unchanged test paths: still valid.

## Commands

- `MIX_BUILD_ROOT=_build-rag mix test .../channel_verify_test.exs`: 11 tests, 0 failures.
- `MIX_BUILD_ROOT=_build-rag mix test test/ash_surface/ported/typed_channel`: rc=0,
  41 tests, 0 failures, 8 skipped (T13-GAP loud skips).
- `MIX_BUILD_ROOT=_build-rag mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.

## Non-vacuity

Scratch copy /tmp/rag (explicit-path tar, deps symlink), `resolved_kind(%Type{kind: kind})`
mutated to return "map": `mix test test/ash_surface/ported/typed_channel` rc=2, 9 failures
(3 in ChannelVerifyTest non_object_payload string/array/enum, 6 in ChannelPayloadTest).
In-place tree not mutated.
