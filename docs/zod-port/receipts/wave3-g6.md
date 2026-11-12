# Wave 3 Lane G6 Receipt

Standing: PARTIAL_ALIVE

Slice: installer 6, task 3, error 4, type 4 (ids from `mix ash_surface.parity`, wave3-q1).

## Commands

- `mix test` over installer_parity, error_type_parity, installer, no_local_do, mock_discipline,
  zod_type_wave2, zod_type_parity: 40 tests, 1 failure (exit 2). The failure is
  `zod_type_wave2_test.exs:45` `uuid_v7` expecting `z.guid()` while disk now renders `z.uuid()`:
  a concurrent lane's edit to the `uuid_v7` row, not session-introduced by G6.
- `mix test` installer_parity + error_type_parity alone: 0 failures (11 tests).
- `mix format --check-formatted` on changed files: exit 0.
- `mix ash_surface.parity`: exit 1. Slice counts before: installer 6, task 3, error 4, type 4
  MISSING. After: installer 3, task 2, error 0 own ids, type 0 own ids. The report also shows
  `type.kind.*` (30) and `error.type.*` (13) wildcard-row failures introduced by a concurrent
  change to the gate ("occurs only in a comment or string literal"); not G6 ids.

## Dispositions

| id | disposition |
|---|---|
| installer Framework / Esbuild / Vite | pass: new `lib/ash_surface/installer/{framework,esbuild,vite}.ex`, wired in `ash_surface.install`; idempotence courts on real Igniter test projects |
| installer Inertia / LandingPage / Layout | MISSING, proposed non-goal (below) |
| task npm_install | pass: real `npm install` in a temp dir, plus failure raise |
| task codegen flag run_endpoint / validate_endpoint | MISSING, proposed non-goal (below) |
| error AuthenticationFailed / InvalidToken impls, types authentication_failed / invalid_token | pass: table already in `errors.ex`; executed court with real Splode structs under the reference module names (AshAuthentication is not a dep) |
| type kind binary_id, date_time | pass: added to `ZodType` base table (`z.guid()`, `z.iso.datetime()`), node-admitted by ZodGuard |
| type constraint escape? | pass: new `ltree` kind, `escape?: true` renders `z.array(z.string())`, else string-or-array union |
| type constraint instance_of | pass: court pins struct record shape unchanged under `instance_of` |

## Operator decisions

Proposed non-goals (README not edited; README must gain wording, e.g. "no framework scaffolding:
no Inertia pages, landing page or layout generation"):
- Installer.Inertia, Installer.LandingPage, Installer.Layout: scaffold a TypeScript/React frontend
  shell; ash_surface installer only wires config, formatter, zod and resource DSL.
- codegen flags `run_endpoint`/`validate_endpoint`: set fixed RPC endpoint paths in generated TS;
  ash_surface transports are adapter-supplied (README "Transport semantics"), no fixed paths.
- The 3 `instance_of` court pins shape only; richer typed-struct field expansion is not implemented.

## Files changed

- lib/ash_surface/installer/{framework,esbuild,vite}.ex (new)
- lib/mix/tasks/ash_surface.install.ex, lib/ash_surface/compiler/zod_type.ex (additive)
- test/ash_surface/installer_parity/{framework_parity,npm_install_task}_test.exs (new)
- test/ash_surface/error_type_parity/error_type_parity_test.exs (new)
- parity/court_map.json (12 entries added)
- `_build-g6` deleted.
