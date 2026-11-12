# Wave 3 Repair RAT

Standing: PASS

Lane RAT. Repairs from `wave3-skmutf.md` (items 9-12). Build root `_build-rat`; scratch `/tmp/rat`.

## Task A: runtime_source_of_truth_ast_guard_test.exs

Walker now scope-aware (alias/import per block, `__MODULE__` resolved, no crash). Newly caught:
`import` of forbidden modules, `import Ash` + bare actuating call, `apply/3`, `Kernel.apply/3`,
piped/`Map.fetch`/`Access` reads and dot access on retired keys (rpc-action-shaped receivers
only; live `ctx.enable_sort?` is a different struct), `Module.concat` literals,
`Ash.stream/run_action/load/calculate`. Self-tests added per form (known-bad flips it).
Guard + RAK: `mix test` = 62 tests, 0 failures, rc=0.

## Task B: RAK survivors (scratch shim-court, sha256 restore byte-exact)

| item | shim | shim result | restored |
|---|---|---|---|
| VF2 | value_formatter keyword `Enum.reverse` | 13 tests, 1 failure rc=2 | 0 failures |
| V3 | validator `sort_by ... :desc` | 12 tests, 1 failure rc=2 | 0 failures |
| I3 | identity_schema drop `keyword` | 14 tests, 1 failure rc=2 | 0 failures |

`mix ash_surface.parity.tests` rc=0 (unaccounted=0 broken=0). No lib edits in the repo.
