# Lane 19 Receipt

Standing: PARTIAL

Subject: /Users/sac/ash_surface working tree (uncommitted, other lanes in flight; no SHA pinned).

## Files changed
- test/support/zod_fixtures.ex (Domain, Todo on Ash.DataLayer.Ets, Priority enum, Slug custom type,
  Address embedded, union, arrays, map, calculation; `Harness` module for real node/tsc staging)
- test/ts/shouldPass/todo_input.ts, test/ts/shouldFail/todo_input_misuse.ts
- test/ts/zod_runtime_runner.mjs, test/ts/cases.json
- test/ash_surface/ts/{zod_codegen,ts_compile,zod_runtime}_test.exs
- package.json (devDependencies typescript ^5.9.0; NOT installed)

## Tooling facts
- node_modules has zod only; no node_modules/.bin. `tsc` found on PATH (/opt/homebrew/bin/tsc).
  Harness.tool!/1 checks node_modules/.bin then PATH and raises loudly if absent; zod! raises if missing.
- Workspaces live in System.tmp_dir!, removed in on_exit; node_modules symlinked in.

## Commands
- `MIX_BUILD_ROOT=_build-lane19 mix test test/ash_surface/ts` final run: 7 tests, 2 failures.
  - PASS: codegen determinism, exports, ZodGuard.admit on every emitted expr, tsc shouldPass (exit 0),
    tsc shouldFail (nonzero + `error TS`).
  - FAIL (pending port, not lane-19 defects): zod_runtime "minimal valid" (current artifact emits
    `.nullable()` not `.optional()`, so omitted keys fail); codegen constraint chain
    (`title: z.string().min(1).max(80)` absent: constraints not yet rendered, enum/atom/union/slug/
    address emit `z.unknown()`).
- Build dir _build-lane19 deleted.

## Observations
- Current artifact action ids are `Todo.create` (short names), schema const `Todo_create_schema`;
  cases.json and TS files use these ids.
- shouldFail files assert only nonzero exit + `error TS`; not per-error-count.

## Requests
- Lane 20: run `npm install` so node_modules/.bin/tsc exists; then cases.json constraint cases and
  the codegen constraint assertions should flip green once lanes 01/03/17 land.

## Falsifiers
- A zod_runtime failure on an `expect: fail` case that is not a pass-expected case means a constraint
  regressed; shouldPass failing means generated types broke strict TS.
