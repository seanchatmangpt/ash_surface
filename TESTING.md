# TESTING

How this repository is tested, grounded in the suites that actually run:
`mix test` (308 tests, 33 files) and `npm test` (175 tests, 13 files), chained
by `mix test.all` and proven zero-config by `mix test.zero` and
`scripts/zero_config_check.sh`.

Path-truth law for this document: every cited path either exists on this
branch, or is marked **[INTEGRATION]** — a sibling-canonical path owned by a
v-wave branch that is absent here by design and lands with the v-wave merge
(ticket `final-integration-010`, merge order in `V_WAVE.md`). An
**[INTEGRATION]** path is never an existing gate; never report one green from
this branch.

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

### Zero-config battery (v1, in-repo)

- `mix test.all` — Elixir suite then JS suite (`npm test`) through a mix
  alias; aborts at the first failing task. Defined in `mix.exs`.
- `mix test.zero` — `mix test.all` re-run under literal `env -i`; only
  `HOME` and `PATH` survive (`@zero_env_allowlist` in `mix.exs`). A hidden
  config dependency fails loudly here, not in CI.
- `bash scripts/zero_config_check.sh` — the fresh-local-clone proof: clones
  this tree to a scratch dir, re-runs the battery in
  `env -i PATH HOME ZERO_CONFIG_SANITIZED=1`, and is fail-closed (no
  auto-skip on network errors; it cannot print a false `ZERO_CONFIG_OK`).
  Terminal line `ZERO_CONFIG_OK` on exit 0. See `scripts/README.md`.

### Zero-config v2 battery **[INTEGRATION]**

`scripts/zero_config_v2.sh` **[INTEGRATION]** — full battery in a fresh
local clone (`env -i PATH HOME`, local `git clone`, `mix deps.get`,
`mix test`, `npm install`, `npm test`, `mix test.zero` when present), plus a
guard that
fails if any `test/` file reads env vars outside the documented allowlist.
Owned by ticket `zero-config-battery-002`; it exists on no branch at the
time of writing and lands at integration. Until it lands, the v1 battery
above is the proof, and the v2 additions (env-read guard, `mix test.zero`
inside the fresh clone) must not be claimed as green.

## 2. What Chicago-style means here

These are state-based tests of real modules, not interaction tests of
collaborators:

- **Real modules, real returns.** Tests call the actual
  `AshSurface.from_manifest/2`, `Observation.create/3`, `Transport.select/3`,
  `createClient`, etc., and assert on returned state (`{:ok, surface}`,
  digests, projected artifacts, receipts). No `assert_received`, no message
  spying, no mock frameworks anywhere in `test/` (every occurrence of the
  word "mock" in the tree is a negative assertion).
- **Doubles only for injected adapters — and even then, real ones.** The
  codebase has zero mock/stub doubles. The only seams are (a) the transport
  endpoint, where tests inject a *real* ephemeral loopback HTTP server
  (`test/support/fixtures.ex`, `node:http` in JS) instead of faking HTTP, and
  (b) the projector module passed to `AshSurface.project/3`
  (`test/ash_surface/project_test.exs`,
  `test/ash_surface/projector/expo_test.exs`). Consequence records are
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

## 3. Delegation tests: real ash_r2rml / ash_a2a, never mocks

The IR era extends the Chicago rules to delegation seams. When a section
builder projects facts owned by a sibling extension (`ash_a2a` for
capability, `ash_r2rml` for semantic), the test subject is a **real inline
Ash resource that registers the real extension** — never a fake of the
extension, never a mock of its Info functions:

- **Real subject.** E.g. an ETS resource with `extensions: [AshA2A]`
  declaring real `a2a skill` overrides (derived defaults, an explicit
  `:external_do` override, an unclassified generic action left to ash_a2a's
  fail-closed `:unknown`, and an `expose?: false` override), plus a real
  unregistered resource as the negative case.
- **Expectations stated against the real owner.** Every assertion targets
  either `AshA2A.Info` on the same resource (proving pure projection) or the
  extension's published consequence law (proving the builder invents
  nothing). The builder's test fails if the builder duplicates, contradicts,
  or fabricates a delegated fact.
- **Canonical exemplar (sibling-canonical):**
  `test/ash_surface/compiler/capability_section_test.exs` **[INTEGRATION]**
  (owned by the v05 branch; lands at integration). On this branch the
  delegation-law *precursors* are already live:
  `test/ash_surface/action_id_test.exs` pins that serialized
  `semanticId` is exactly `"ash:" <> action_id` (the delegated-facts law of
  the v10 slimming — `semanticId`/`authorityBoundary`/`doAuthority`/
  `receiptRequired` are delegated facts, not derived ones), and
  `test/ash_surface/digest_test.exs` pins the digest determinism those facts
  feed.
- **Deps law for the delegation batteries.** `ash_a2a` and `ash_r2rml` enter
  as real test-env deps, never as vendored copies: the canonical `mix.exs`
  is the v23 branch's (`ash_r2rml` git-pinned to override `ash_a2a`'s hex
  requirement, `ash_a2a` as a git dep, `runtime: false`); until v23 lands,
  the merged v05 local `ash_a2a` test-env line stands, per `V_WAVE.md`
  precedence.

### No-local-DO tripwire **[INTEGRATION]**

The wave plan (ticket `final-integration-010`, gate list "no_local_do green")
names a no-local-DO tripwire: a gate that fails the build when the tree
performs a local DO — consequential actuation outside the brokered,
receipt-bearing path. It is defined nowhere in-repo at the time of writing
(named by the plan, owned by the machinery rows); it lands at integration.
Until then: this branch's tests never actuate anything (loopback sockets and
ETS only), and any future tripwire citation must wait for its owning file.

## 4. Suite map

Legend:

- **[NEW]** = added in the 2026-09-13 wave (MX closed loop, projector,
  health, consumer e2e). Unmarked = original surface/runtime suites.
- **[DEEP]** = deep/adversarial follow-on suite for an already-mapped
  surface (falsifiers, edge tables, invariant batteries).
- **[INTEGRATION]** = sibling-canonical: owned by a v-wave branch, absent
  from this branch by design, lands with the v-wave merge
  (`final-integration-010`); never an existing gate.

| Product surface | Test file(s) |
| --- | --- |
| `lib/ash_surface.ex` (`AshSurface`, `Surface`, `Projector` structs + build/verify/project/digest, `from_manifest/2`, `from_app/1`, `action_id/1`, `runtime_source/0`) | `test/ash_surface_test.exs`; `test/ash_surface/from_manifest_test.exs`; `test/ash_surface/from_app_test.exs`; `test/ash_surface/project_test.exs`; `test/ash_surface/action_id_test.exs`; `test/ash_surface/runtime_source_test.exs` |
| Manifest/surface serialization envelope + cross-language digest law + version sync (`mix.exs` @version, runtime `SURFACE_RUNTIME_VERSION`, `package.json`) | `test/ash_surface/manifest_serializer_test.exs`; `test/ash_surface/digest_test.exs`; `test/ash_surface/version_sync_test.exs`; `test/js/digest_cross_language.test.mjs`; `test/js/version_sync.test.mjs` |
| `lib/ash_surface/transport.ex` (`AshSurface.Transport`, incl. `Decision`, select/fallback/outcome laws) | `test/ash_surface_test.exs` (selection/fallback laws); `test/ash_surface/transport_select_test.exs` **[NEW]**; `test/ash_surface/transport_fallback_test.exs` **[NEW]**; `test/ash_surface/transport_outcome_test.exs` **[NEW]**; `test/ash_surface/transport_falsifiers_test.exs` **[NEW]**; real `select/3` call in `test/ash_surface/health_test.exs` **[NEW]**; `test/js/transport_law.test.mjs` **[NEW]** |
| `lib/ash_surface/health.ex` | `test/ash_surface/health_test.exs` **[NEW]**; `test/ash_surface/health_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/event.ex` | `test/ash_surface/event_test.exs` **[NEW]**; `test/ash_surface/event_deep_test.exs` **[DEEP]**; `test/js/event_observation.test.mjs` **[NEW]** |
| `lib/ash_surface/observation.ex` | `test/ash_surface/observation_test.exs` **[NEW]**; `test/ash_surface/observation_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/planning_episode.ex` | `test/ash_surface/planning_episode_test.exs` **[NEW]**; `test/ash_surface/planning_episode_deep_test.exs` **[DEEP]**; `test/js/planning_episode.test.mjs` **[NEW]** |
| `lib/ash_surface/projector/expo.ex` (six-file artifact set, schemas/actions/events/receipts emissions, client factory, determinism) | `test/ash_surface/projector/expo_test.exs` **[NEW]**; `test/ash_surface/projector/expo_schemas_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_actions_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_events_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_receipts_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_client_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_determinism_test.exs` **[DEEP]** |
| Whole closed loop (`Observation` + `PlanningEpisode` + `Event` over the fixture domain) | `test/ash_surface/mx_closed_loop_episode_test.exs` **[NEW]**; `test/ash_surface/mx_closed_loop_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/formatter.ex` | `test/ash_surface/formatter_test.exs` (DSL delegation law; the formatter gate itself is `mix format --check-formatted`) |
| `lib/ash_surface/resource/validator.ex` | `test/ash_surface/resource/validator_test.exs`; `test/ash_surface/resource/validator_adversarial_test.exs` **[DEEP]** |
| `priv/static/ash_surface_runtime.mjs` (Zod/JSDoc runtime: `createClient`, schemas, `SurfaceRuntimeError`) | `test/js/runtime.test.mjs`; `test/js/zod_boundaries.test.mjs` **[NEW]**; `test/js/error_paths.test.mjs` **[NEW]**; `test/js/namespaces_deep.test.mjs` **[DEEP]**; `test/js/receipts_primitives.test.mjs` **[NEW]**; `test/js/consumer_fixture.test.mjs` **[NEW]**; `test/js/zoela_mx_consumer_fixture.test.mjs` **[NEW]**; `test/js/e2e_hermetic.test.mjs` **[NEW]** |
| Cross-language manifest -> surface -> JS dispatch -> Ash consequence -> receipt | `test/ash_surface/consumer_fixture_test.exs` **[NEW]** (spawns `test/js/consumer_e2e_runner.mjs` against the loopback server) |
| Projected Expo artifacts (manufactured output) | `test/ash_surface/projector/expo_test.exs` **[NEW]** (file set + `node --check`), plus `npm run check` for the runtime itself |

IR-era rows (the v26.9.16 v-wave; all sibling-canonical unless noted):

| Canonical surface (owner) | Test file(s) |
| --- | --- |
| `lib/ash_surface/ir.ex` — `AshSurface.IR`, five sections `ash \| semantic \| capability \| presentation \| schema` (+ `version`, `digest`), extended by the v10 delegated-facts block (v01 + v10) | `test/ash_surface/ir_test.exs` **[INTEGRATION]**; delegation-law precursors already on this branch: `test/ash_surface/action_id_test.exs`, `test/ash_surface/digest_test.exs` |
| `lib/ash_surface/compiler.ex` — DiscoverOnce compiler orchestrator + `AshSurface.Compiler.Section` behaviour (`build(action, context)`) (v02) | `test/ash_surface/compiler_test.exs` **[INTEGRATION]** |
| `lib/ash_surface/compiler/capability.ex` — capability section, ash_a2a projection (v05) | `test/ash_surface/compiler/capability_section_test.exs` **[INTEGRATION]** (the delegation-test exemplar, see section 3) |
| `lib/ash_surface/compiler/presentation.ex` — presentation section reader (v06) | `test/ash_surface/compiler/presentation_section_test.exs` **[INTEGRATION]** |
| `lib/ash_surface/compiler/aria.ex` — accessibility-as-data in `IR.Schema.aria` (v08) | `test/ash_surface/compiler/aria_section_test.exs` **[INTEGRATION]** |
| ash / semantic / schema section builders (v03 / v04 / v07; semantic projects ash_r2rml facts) | not landed on any branch at the time of writing **[INTEGRATION]** — cite no test path until they land |
| `lib/ash_surface/ir/codec.ex` — IR serialization + content-addressing codec over `AshSurface.IR.Surface` (v09) | `test/ash_surface/ir_codec_test.exs` **[INTEGRATION]** |
| `lib/ash_surface/projector/voice_kiosk.ex` — fifth projector, IR extensibility proof (v20) | `test/ash_surface/projector/voice_kiosk_test.exs` **[INTEGRATION]** |
| `Projector.IR` behaviour (v16) | defined on no branch at the time of writing; the extant projectors (this branch's `lib/ash_surface/projector/expo.ex` included) run through `AshSurface.project/3` until it lands **[INTEGRATION]** |
| intent group (codec/intent, v11–v15) | no owning file landed on any branch **[INTEGRATION]** — cite no path until it lands |
| `scripts/zero_config_v2.sh` — zero-config v2 battery (ticket `zero-config-battery-002`) | on no branch; see section 1 **[INTEGRATION]** |
| no-local-DO tripwire (`no_local_do` gate, ticket `final-integration-010`) | defined nowhere in-repo; see section 3 **[INTEGRATION]** |

Support: `test/support/fixtures.ex` is the only shared file, and it holds the
fixture Ash domain/resource (ETS) and the ephemeral loopback HTTP server — it
is a fixture domain, not a helpers module.

## 5. How to add a test

Elixir:

- Path mirrors `lib/`: a module at `lib/ash_surface/<name>.ex` is tested at
  `test/ash_surface/<name>_test.exs`; nested modules get nested dirs
  (`lib/ash_surface/projector/expo.ex` ->
  `test/ash_surface/projector/expo_test.exs`).
- `use ExUnit.Case, async: true` unless the test owns processes or scratch
  dirs (the fixture-server, projector, closed-loop, and formatter tests use
  `async: false` for exactly that reason — the formatter test also mutates
  global Spark app env).
- Helpers live inside your own test module as `defp`s (see `manifest/0` in
  `test/ash_surface_test.exs`, `canonical_json/1` in
  `test/ash_surface/consumer_fixture_test.exs`). Do not create shared support
  modules; `test/support/fixtures.ex` is reserved for the fixture domain and
  loopback server.
- Scratch output goes under `_build/test/<suite>`; create it in `setup`.
- Delegation seams follow section 3: register the real sibling extension on
  the inline resource and assert against its real `Info`/published law —
  never a mock of it.

JavaScript:

- `test/js/<name>.test.mjs` (one file per suite, e.g.
  `test/js/error_paths.test.mjs`), picked up automatically by the
  `node --test test/js/*.test.mjs` glob in `package.json`.
- Use `node:test` + `node:assert/strict`; import the runtime contract from
  `../../priv/static/ash_surface_runtime.mjs`. Helpers are plain functions at
  the top of the file (see `contract()` in `test/js/runtime.test.mjs`).
- Prefer state assertions on parsed/returned values; when you need a server,
  start a real ephemeral `node:http` one on `127.0.0.1` rather than mocking.

Gates before you call it done: `mix test`, `npm test` (or the chained
`mix test.all`), and `mix format --check-formatted`; when the change touches
the zero-config story, add `mix test.zero` and
`bash scripts/zero_config_check.sh` (per `AGENTS.md`, cheapest
high-information gate first; never call generated code ALIVE without an exact
consumer execution receipt; never report an **[INTEGRATION]** gate —
`scripts/zero_config_v2.sh`, `no_local_do` — green from this branch).
