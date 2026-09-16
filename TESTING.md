# TESTING

How this repository is tested, grounded in the suites that actually run:
`mix test` (18 tests, 8 files) and `npm test` (15 tests, 3 files).

## 1. Zero-config contract

From a fresh clone, the full verification loop is exactly:

```sh
mix deps.get
mix test
npm install
npm test
```

Nothing else. No environment variables, no database, no external network:

- No DB. The only deps are `ash`, `spark`, `jason`, and `igniter` (dev/test).
  The fixture resource in `test/support/fixtures.ex` uses the in-memory
  `Ash.DataLayer.Ets` data layer; there is no Ecto repo and no Postgres.
- No env. `config/config.exs` sets one Ash string-length option and nothing
  else; `test/test_helper.exs` is a single `ExUnit.start()`.
- No external network. The end-to-end tests listen on ephemeral loopback
  sockets (`:gen_tcp.listen(0, ...)` in `test/support/fixtures.ex`,
  `node:http` in the JS tests) and dispatch to `127.0.0.1` only.
- Scratch writes (projected artifacts, e2e contracts/receipts) go under
  `_build/test/*`, not the source tree.

If any of the four commands above fails on a clean clone, that is a defect,
not a setup problem.

## 2. What Chicago-style means here

These are state-based tests of real modules, not interaction tests of
collaborators:

- **Real modules, real returns.** Tests call the actual
  `AshSurface.from_manifest/2`, `Observation.create/3`, `Transport.select/3`,
  `createClient`, etc., and assert on returned state (`{:ok, surface}`,
  digests, projected artifacts, receipts). No `assert_received`, no message
  spying, no mock frameworks anywhere in `test/`.
- **Doubles only for injected adapters — and even then, real ones.** The
  codebase has zero mock/stub doubles. The only seams are (a) the transport
  endpoint, where tests inject a *real* ephemeral loopback HTTP server
  (`test/support/fixtures.ex`, `node:http` in JS) instead of faking HTTP, and
  (b) the projector module passed to `AshSurface.project/3`
  (`test/ash_surface/projector/expo_test.exs`). Consequence records are
  written to and read back from the real ETS-backed Ash resource.
- **Golden vectors for drift detection.** Fixed known inputs are pinned to
  expected digests/artifact shapes so cross-language or refactoring drift
  fails loudly. Three real examples:
  1. `test/ash_surface/consumer_fixture_test.exs` — after the JS runtime
     produces a receipt, the Elixir side independently recomputes the SHA-256
     `receiptHash` over the canonical JSON and asserts equality. If either
     language's canonicalization or hashing drifts, this fails.
  2. `test/js/zoela_mx_consumer_fixture.test.mjs` — the MX closed loop pins
     content-addressed `stateDigest` values derived from fixed inputs
     (`sha256("need_42:diverged")`, `sha256("need_42:selected")`) so the
     observation/world-state contract cannot silently change shape.
  3. `test/ash_surface/projector/expo_test.exs` — the Expo projector must
     manufacture the exact six-file artifact set
     (`zoela_surface.schemas/actions/events/receipts/tanstack.mjs`,
     `zoela_surface.mjs`) and every file must pass `node --check`; a new,
     renamed, or broken artifact breaks the golden list.

  `test/ash_surface_test.exs` adds the companion properties: the surface
  digest is stable across equivalent map insertion order, and projection
  metadata participates in the digest.

## 3. Suite map

Legend: **[NEW]** = added in the 2026-09-13 wave (MX closed loop, projector,
health, consumer e2e). Unmarked = original surface/runtime suites.

| Product surface | Test file(s) |
| --- | --- |
| `lib/ash_surface.ex` (`AshSurface`, `Surface`, `Projector` structs + build/verify/project/digest) | `test/ash_surface_test.exs` |
| `lib/ash_surface/transport.ex` (`AshSurface.Transport`, incl. `Decision`) | `test/ash_surface_test.exs` (selection/fallback laws), `test/ash_surface/health_test.exs` **[NEW]** (real `select/3` call) |
| `lib/ash_surface/health.ex` | `test/ash_surface/health_test.exs` **[NEW]** |
| `lib/ash_surface/event.ex` | `test/ash_surface/event_test.exs` **[NEW]** |
| `lib/ash_surface/observation.ex` | `test/ash_surface/observation_test.exs` **[NEW]** |
| `lib/ash_surface/planning_episode.ex` | `test/ash_surface/planning_episode_test.exs` **[NEW]** |
| `lib/ash_surface/projector/expo.ex` | `test/ash_surface/projector/expo_test.exs` **[NEW]** |
| Whole closed loop (`Observation` + `PlanningEpisode` + `Event` over the fixture domain) | `test/ash_surface/mx_closed_loop_episode_test.exs` **[NEW]** |
| `lib/ash_surface/formatter.ex` | No dedicated test file. It is a `Spark.Formatter` plugin; its gate is `mix format --check-formatted` itself. |
| `lib/ash_surface/resource/validator.ex` | No dedicated test file. Validates the pack-manufactured `AshSurface.Resource` DSL section; not yet exercised by the suite. |
| `priv/static/ash_surface_runtime.mjs` (Zod/JSDoc runtime: `createClient`, schemas, `SurfaceRuntimeError`) | `test/js/runtime.test.mjs`; `test/js/consumer_fixture.test.mjs` **[NEW]**; `test/js/zoela_mx_consumer_fixture.test.mjs` **[NEW]** |
| Cross-language manifest -> surface -> JS dispatch -> Ash consequence -> receipt | `test/ash_surface/consumer_fixture_test.exs` **[NEW]** (spawns `test/js/consumer_e2e_runner.mjs` against the loopback server) |
| Projected Expo artifacts (manufactured output) | `test/ash_surface/projector/expo_test.exs` **[NEW]** (file set + `node --check`), plus `npm run check` for the runtime itself |

Support: `test/support/fixtures.ex` is the only shared file, and it holds the
fixture Ash domain/resource (ETS) and the ephemeral loopback HTTP server — it
is a fixture domain, not a helpers module.

## 4. How to add a test

Elixir:

- Path mirrors `lib/`: `lib/ash_surface/foo.ex` ->
  `test/ash_surface/foo_test.exs`; nested modules get nested dirs
  (`test/ash_surface/projector/expo_test.exs`).
- `use ExUnit.Case, async: true` unless the test owns processes or scratch
  dirs (the fixture-server, projector, and closed-loop tests use
  `async: false` for exactly that reason).
- Helpers live inside your own test module as `defp`s (see `manifest/0` in
  `test/ash_surface_test.exs`, `canonical_json/1` in
  `test/ash_surface/consumer_fixture_test.exs`). Do not create shared support
  modules; `test/support/fixtures.ex` is reserved for the fixture domain and
  loopback server.
- Scratch output goes under `_build/test/<suite>`; create it in `setup`.

JavaScript:

- `test/js/<name>.test.mjs`, picked up automatically by the
  `node --test test/js/*.test.mjs` glob in `package.json`.
- Use `node:test` + `node:assert/strict`; import the runtime contract from
  `../../priv/static/ash_surface_runtime.mjs`. Helpers are plain functions at
  the top of the file (see `contract()` in `test/js/runtime.test.mjs`).
- Prefer state assertions on parsed/returned values; when you need a server,
  start a real ephemeral `node:http` one on `127.0.0.1` rather than mocking.

Gates before you call it done: `mix test`, `npm test`, and
`mix format --check-formatted` (per `AGENTS.md`, cheapest high-information
gate first; never call generated code ALIVE without an exact consumer
execution receipt).
