# Wave 3 Lane T13 Receipt

Standing: PARTIAL_ALIVE

Reference `~/ash_typescript/test/ash_typescript/typed_channel/` (6 files). 4 adapted, 2
skipped_gap. No lib edits.

## Per-file disposition

| reference file | disposition | ash_surface tests |
|---|---|---|
| codegen_test.exs | adapted | ported/typed_channel/channel_payload_test.exs |
| multi_resource_codegen_test.exs | adapted | channel_payload_test.exs |
| payload_type_aliases_test.exs | adapted | channel_payload_test.exs |
| verify_typed_channel_test.exs | adapted | ported/typed_channel/channel_verify_test.exs |
| interception_test.exs | skipped_gap | channel_runtime_gap_test.exs |
| payload_formatter_test.exs | skipped_gap | channel_runtime_gap_test.exs |

Per-test notes (what was dropped and why) live in each row's `changes` in
`parity/test_ledger.json`. TS-text-only tests (branded types, factories, subscription helpers,
orchestrator files) have no counterpart and are listed, not skipped silently.

## Commands

| command | rc | result |
|---|---|---|
| `mix test` channel_payload + channel_verify + channel_runtime_gap (MIX_BUILD_ROOT=_build-t13) | 0 | 38 tests, 0 failures, 8 skipped (all 8 in the gap file; 30 run) |
| `mix test test/ash_surface_mock_discipline_test.exs` | 0 | 2 tests, 0 failures |
| `mix format --check-formatted` on the 3 files | 0 | clean |
| `mix ash_surface.parity.tests --summary` | 1 | `files=264 ported=0 adapted=32 skipped_gap=13 non_goal=0 unaccounted=210 broken=9 shallow=1` |

typed_channel directory: files=6 adapted=4 skipped_gap=2 unaccounted=0 broken=0. The 9 broken
rows are `rpc/verify_action_types/*` (another lane's rows), not T13.

## Gaps (loud skip tag `T13-GAP typed_channel runtime interception`)

Phoenix channel interception (intercept/handle_out injection), PayloadFormatter, calc-transform
payload inference, and the warn_on_* config flags have no ash_surface counterpart (channel
support is descriptor-only). Capabilities: runtime.module.TypedChannel.Interception,
runtime.module.TypedChannel.PayloadFormatter.

## Divergences observed

- Cross-channel payload-name conflicts are namespaced by channel name
  (`Channel.check_conflicts`), where ash_typescript raises.
- `Channel.build_with_warnings` returns `missing_returns` twice when fed a discovery that already
  carries it (discovery warnings + recomputed); tests dedupe with `Enum.uniq`. Not fixed (lib).

## Operator decisions

None (no non_goal rows).
