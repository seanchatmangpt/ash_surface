# TESTING

How this repository is tested, grounded in the suites that actually run:
`mix test` (1264 tests, pinned floor 1257, 123 `test/**/*_test.exs` files) and
`npm test` (371 tests, 26 `test/js/*.test.mjs` files), chained
by `mix test.all` and proven zero-config by `mix test.zero`,
`scripts/zero_config_check.sh`, and `scripts/zero_config_v2.sh`.

Path-truth law for this document: every cited path either exists on this
branch, or is marked **[INTEGRATION]** — a sibling-canonical path owned by a
v-wave branch that is absent here by design and lands with the v-wave merge
(ticket `final-integration-010`, merge order in `V_WAVE.md`). An
**[INTEGRATION]** path is never an existing gate; never report one green from
this branch. At this SHA the v-wave has landed: zero paths carry the
**[INTEGRATION]** marker (the vocabulary is retained for future waves).

## 1. Zero-config contract

From a fresh clone, the full verification loop is exactly:

```sh
mix deps.get
npm install
mix test
npm test
```

Nothing else. No environment variables, no database, no external network:

- No DB. The deps are `ash`, `spark`, `jason`, `telemetry`, `igniter` and
  `stream_data` (`runtime: false`; `dialyxir` is dev/test only), plus the
  delegation deps `ash_r2rml` and
  `ash_a2a` (git-pinned, `runtime: false` — see section 3). The fixture
  resource in `test/support/fixtures.ex` uses the in-memory
  `Ash.DataLayer.Ets` data layer; there is no Ecto repo and no Postgres.
- No env. `config/config.exs` sets one Ash string-length option plus a
  test-only `:logger` level of `:warning`, and nothing
  else; `test/test_helper.exs` is a single `ExUnit.start()`.
- No external network. The end-to-end tests listen on ephemeral loopback
  sockets (`:gen_tcp.listen(0, ...)` in `test/support/fixtures.ex`,
  `node:http` in the JS tests) and dispatch to `127.0.0.1` only.
- Scratch writes (projected artifacts, e2e contracts/receipts) go under
  `_build/test/*`, not the source tree.

Order law: `npm install` precedes `mix test`. The Elixir e2e suite spawns
`test/js/consumer_e2e_runner.mjs`, whose line 4 is `import { z } from "zod"`
— without `node_modules`, `mix test` fails. Both battery scripts encode this
(`scripts/zero_config_check.sh`, `scripts/zero_config_v2.sh`: "npm install
--no-audit — before mix test: e2e tests import zod").

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
  `env -i PATH HOME ZERO_CONFIG_SANITIZED=1` (npm install before mix test,
  per the order law above), and is fail-closed (no auto-skip on network
  errors; it cannot print a false `ZERO_CONFIG_OK`). Terminal line
  `ZERO_CONFIG_OK` on exit 0. See `scripts/README.md`.

### Zero-config v2 battery (in-repo)

- `bash scripts/zero_config_v2.sh` — everything v1 proves, plus: (1) an
  env-read guard — no file under `test/` reads an environment variable
  outside the documented allowlist (`@zero_env_allowlist` in `mix.exs`);
  reads must carry a literal variable name, and an opaque read fails
  closed; (2) the **chicago suite census** (ticket
  `chicago-zeroconfig-census-048`, below); (3) `mix test.zero` re-run
  inside the fresh clone when the alias is defined there. Hermetic re-exec
  through `env -i PATH HOME`, per-step `EXIT[<label>]=<code>` receipt
  lines, fail-closed (any failure aborts before the terminal line, so it
  cannot print a false `ZERO_CONFIG_OK`). Owned by ticket
  `zero-config-battery-002` (census owned by
  `chicago-zeroconfig-census-048`); live in-repo at this SHA.

### Chicago suite census (in the v2 battery)

The battery pins the full chicago suite set: `scripts/chicago_census.txt`
is the golden census — one `# floor: <N>` line plus one suite path per
line (149 suites at this SHA: 123 mix + 26 npm), regenerated with
`git ls-files 'test/*_test.exs' 'test/js/*.test.mjs' | LC_ALL=C sort` and
the floor re-measured from `mix test` whenever suites change. Two
fail-closed battery steps consume it:

- **file set** (before deps are fetched) — every pinned suite must exist
  in the fresh clone; deleting a suite file turns the battery RED, as does
  a missing census, a missing/duplicated/malformed floor line, an empty
  list, or a path escaping the clone.
- **mix test count floor** (after `mix test`) — the clone's `mix test`
  count must be >= the pinned floor (1257 at this SHA; re-pinned 2026-09-28
  from 1029 when the Chicago coverage wave added the `*_coverage_test.exs`,
  boundary/projector/MX-verify hardening and JS runtime-hardening suites;
  earlier re-pinned 2026-09-23 from 842 when the census grew the command_center, human_surface, zoe_demo,
  codec_props and event_replay_state suites), so gutting a suite
  without deleting its file also fails. The summary parser handles the
  ExUnit >= 1.19 `Result: N passed (…)` / `Result: X/Y passed` lines and
  the classic `N tests, M failures` line; an unparsable summary fails
  closed.

This is the same golden-vector discipline as section 2's drift detection,
applied to the suite set itself: a removed or emptied-out suite is a
battery failure, never a silent shrink of the proof.

### Suites added by the 2026-09-28 hardening waves

Beyond the per-module Chicago suites, these gates exist and are part of the
census:

- **Execution receipts, not source fragments.** Every manufactured artifact
  (Expo schemas/actions/events/receipts/client/tanstack, the voice kiosk JSON,
  the JS projector output) is imported and executed by Node against the real
  runtime shim (`test/ash_surface/projector/generated_artifacts_exec_test.exs`,
  `test/ash_surface/projector/expo_client_reconcile_test.exs`, runners `test/js/generated_*_runner.mjs`).
  Each has a mutation sanity check: a hand-broken copy of the artifact must
  fail its runner. Only intentional public contracts that execution cannot
  observe (the `// @generated` header, import specifiers) are still pinned as
  text.
- **Cross-language conformance corpus** (`conformance/`, `docs/CONFORMANCE.md`):
  language-neutral vectors minted by the real Elixir implementation and replayed
  by Elixir (`test/conformance/`) and JavaScript
  (`test/js/conformance_replay.test.mjs`); a divergence is pinned as a
  `KNOWN_DIVERGENCE` with a reason, never skipped silently.
- **Decode-boundary fuzzing** (`test/ash_surface/fuzz_*_test.exs`,
  `decode_boundary_*_test.exs`): untrusted entry points (`IR.Codec.from_map/1`,
  the `from_manifest` profile, `EventProjection.from_receipt/2`, the projectors
  over decoded IR) are total and typed under StreamData input.
- **Single-sourced vocabulary with a drift test**
  (`test/ash_surface/vocabulary_drift_test.exs`): `AshSurface.Vocabulary` is deep-compared to the
  JS runtime's `VOCABULARY` export.
- **Falsifier** (`scripts/ci_falsifier.sh`, CI job `falsifier`): 11 mutation
  recipes; each guard must turn RED under its mutation and GREEN after restore.
  There is no whole-file runtime SHA golden any more; the runtime is pinned by
  behaviour.
- **ZOE package** (`packages/ash_surface_zoe`, `mix test.zoe`, CI job
  `zoe-package`): the extracted human-surface family has its own suites and is
  deliberately not part of `mix test.all`.

### Playwright surface

`npm test` runs hermetically without a browser: the accessibility suite
(`test/js/playwright_accessibility.test.mjs`) gates on a Playwright runtime and
reports 4 skipped tests when it is absent. Installing the runtime per the CI
recipe (`.github/workflows/ci.yml`): `npm install --no-save --package-lock=false
playwright@1.63.0 && npx playwright install chromium` — admits the gate and the
suite runs against real headless Chromium over data: URLs (loopback-only, no
server boot). Witnessed at `main@d55c576d1`: 371/371 pass, 0 skipped (see
`~/xaas/docs/sjira/v26.10.6/plans/w901-ash-surface-playwright.md`); re-witnessed
**ALIVE** at HEAD `154385c82` post-W984mf — 2/2 accessibility courts + boundary
refusals against real Chromium, 0 skips
(`~/xaas/docs/sjira/v26.10.7/plans/w984mf-ash-surface-playwright.md`).

**Verified 2026-10-08** (lane W984ne, tree @ `154385c82`): the W984mf-era stale
digest fixture (`test/js/fixtures/digest_cross_language_fixtures.json`, which
pinned `db26ae10…` where the real pipeline and the JS twin both compute
`532b4a1a…`, causing the 6 `digest_cross_language_v3` failures disclosed in the
W984mf receipt) has been regenerated in this tree via
`AshSurface.DigestParityFixtures.encode()`; `npm test` re-run on this tree:
**371/371 pass, 0 fail, 0 skipped**, accessibility suite admitted against real
headless Chromium. Receipt:
`~/xaas/docs/sjira/v26.10.7/plans/w984mf-ash-surface-playwright.md`. (The
W984mk fixture-regen receipt was not yet on disk at verification time; the
regenerated fixture bytes were verified directly instead. The regenerated fixture landed in the conformance re-pin commit of
this change.)

## 2. What Chicago-style means here

These are state-based tests of real modules, not interaction tests of
collaborators:

- **Real modules, real returns.** Tests call the actual
  `AshSurface.from_manifest/2`, `Observation.create/3`, `Transport.select/3`,
  `createClient`, etc., and assert on returned state (`{:ok, surface}`,
  digests, projected artifacts, receipts). No mock frameworks anywhere in
  `test/` (every occurrence of the word "mock" in the tree is a negative
  assertion); `assert_received` appears only in
  `test/ash_surface/telemetry_coverage2_test.exs`.
- **Doubles only for injected adapters — and even then, state-asserted.**
  There is no mock framework. The seams are (a) the transport endpoint,
  where tests inject a *real* ephemeral loopback HTTP server
  (`test/support/fixtures.ex`, `node:http` in JS) instead of faking HTTP,
  (b) the projector module passed to `AshSurface.project/3`
  (`test/ash_surface/project_test.exs`,
  `test/ash_surface/projector/expo_test.exs`), and (c) the compiler's
  `:sections` injection, where `test/ash_surface/compiler_discovery_test.exs`
  binds `test/support/compiler_echo_section.ex` — a behaviour-conformant
  echo stub that records its calls in the process dictionary so discovery
  and injection laws are asserted on recorded state. Consequence records are
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
     manufacture the exact six-file generic artifact set
     (`zoela_surface.schemas/actions/events/receipts/tanstack.mjs`,
     `zoela_surface.mjs`) and every file must pass `node --check`; a new,
     renamed, or broken artifact breaks the golden list. The `human`/`demo`
     artifacts moved to the `ash_surface_zoe` package
     (`packages/ash_surface_zoe`, `mix test.zoe`).

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
- **Canonical exemplar:** `test/ash_surface/compiler/capability_section_test.exs`
  (the delegation-law exemplar for the capability section builder). The
  delegation-law *precursors* remain live as companions:
  `test/ash_surface/action_id_test.exs` pins that serialized
  `semanticId` is exactly `"ash:" <> action_id` (the delegated-facts law of
  the v10 slimming — `semanticId`/`authorityBoundary`/`doAuthority`/
  `receiptRequired` are delegated facts, not derived ones), and
  `test/ash_surface/digest_test.exs` pins the digest determinism those facts
  feed.
- **Deps law for the delegation batteries.** `ash_a2a` and `ash_r2rml` enter
  as real deps, never as vendored copies: `mix.exs` pins `ash_r2rml` to git
  ref `7d958a8` (`override: true`, its version satisfying `ash_a2a`'s hex
  requirement) and `ash_a2a` to the released tag `v26.9.22` (repinned
  2026-09-23, commit be95b3e; was git ref `e25ed6e`; the tag pulls
  `rdf ~> 3.0` and the wasmex NIF), both `runtime: false` so
  neither enters the boot path. This is the v23-canonical shape, landed at
  this SHA.

### No-local-DO tripwire (live)

`test/ash_surface/no_local_do_test.exs` — the invariant
"AshSurface does not determine whether it may DO" as executable law. It
walks every file under `lib/ash_surface/**/*.ex` plus the root
`lib/ash_surface.ex` envelope (`File.read!/1` + `Code.string_to_quoted!/1`,
raw source AND AST), asserting the surface never executes resource actions
itself and never re-derives the delegated `do_authority` fact — authority is
read through `AshSurface.IR.Capability.authority_required/1`, never computed
locally. Named by the wave plan (ticket `final-integration-010`, gate list
"no_local_do green"); live on this branch as part of `mix test`.

## 4. Suite map

Legend:

- **[NEW]** = added in the 2026-09-13 wave (MX closed loop, projector,
  health, consumer e2e). Unmarked = original surface/runtime suites.
- **[DEEP]** = deep/adversarial follow-on suite for an already-mapped
  surface (falsifiers, edge tables, invariant batteries).
- **[INTEGRATION]** = sibling-canonical path absent from this branch by
  design, lands with the v-wave merge. Vocabulary retained; zero rows carry
  this marker at this SHA.

| Product surface | Test file(s) |
| --- | --- |
| `lib/ash_surface.ex` (`AshSurface`, `Surface`, `Projector` structs + build/verify/project/digest, `from_manifest/2`, `from_app/1`, `action_id/1`, `runtime_source/0`) | `test/ash_surface_test.exs`; `test/ash_surface/from_manifest_test.exs`; `test/ash_surface/from_app_test.exs`; `test/ash_surface/project_test.exs`; `test/ash_surface/action_id_test.exs`; `test/ash_surface/runtime_source_test.exs` |
| Manifest/surface serialization envelope + cross-language digest law + version sync (`mix.exs` @version, runtime `SURFACE_RUNTIME_VERSION`, `package.json`) | `test/ash_surface/manifest_serializer_test.exs`; `test/ash_surface/digest_test.exs`; `test/ash_surface/version_sync_test.exs`; `test/js/digest_cross_language.test.mjs`; `test/js/digest_cross_language_v2.test.mjs`; `test/js/version_sync.test.mjs` |
| `lib/ash_surface/ir.ex` — `AshSurface.IR`, five sections `ash \| semantic \| capability \| presentation \| schema` (+ `version`, `digest`) and the v10 delegated-facts block; `lib/ash_surface/ir/capability.ex` | `test/ash_surface/ir_test.exs`; `test/ash_surface/ir_struct_test.exs` |
| `lib/ash_surface/ir/codec.ex` — IR serialization + content-addressing codec over the admitted five-section `AshSurface.IR` (`AshSurface.IR.Surface` was deleted 2026-09-16, commit 2be0e73 — no parallel canon module remains; a tripwire asserts `Code.ensure_loaded` fails for it) | `test/ash_surface/ir_codec_test.exs`; `test/ash_surface/ir_codec_golden_test.exs` |
| `lib/ash_surface/compiler.ex` — DiscoverOnce compiler orchestrator (`compile/2` with `:sections` injection); `lib/ash_surface/section.ex` — `AshSurface.Compiler.Section` behaviour | `test/ash_surface/compiler_test.exs`; `test/ash_surface/compiler_discovery_test.exs` (echo section: `test/support/compiler_echo_section.ex`) |
| Compiler section builders (`lib/ash_surface/compiler/section/{ash,capability,presentation,schema,semantic}.ex`) + section readers/facts (`lib/ash_surface/compiler/{aria,capability,presentation,schema,semantic,ash_truth,ir}.ex`) | `test/ash_surface/compiler/ash_section_test.exs`; `test/ash_surface/compiler/capability_section_test.exs` (the delegation exemplar, see section 3); `test/ash_surface/compiler/presentation_section_test.exs`; `test/ash_surface/compiler/schema_section_test.exs`; `test/ash_surface/compiler/semantic_section_test.exs`; `test/ash_surface/compiler/aria_section_test.exs`; companions: `test/ash_surface/ash_section_truth_test.exs`; `test/ash_surface/capability_delegation_test.exs`; `test/ash_surface/semantic_delegation_test.exs`; `test/ash_surface/schema_section_test.exs`; `test/ash_surface/presentation_section_test.exs` |
| Intent group (`lib/ash_surface/intent.ex`, `lib/ash_surface/intent/{candidate,dispatch}.ex`) | `test/ash_surface/intent_test.exs`; `test/ash_surface/intent/candidate_test.exs`; `test/ash_surface/intent/dispatch_test.exs`; `test/ash_surface/intent_path_test.exs`; `test/ash_surface/intent_round_trip_test.exs` |
| `Projector.IR` behaviour (`lib/ash_surface/projector/ir.ex`, `lib/ash_surface/projector/ir_entry.ex`) + IR event projection | `test/ash_surface/projector/ir_projector_test.exs`; `test/ash_surface/projector_ir_determinism_test.exs`; `test/ash_surface/ir/event_projection_test.exs`; `test/js/ir_projection.test.mjs`; `test/js/ir_projector_deep.test.mjs` |
| `lib/ash_surface/projector/voice_kiosk.ex` — fifth projector, IR extensibility proof | `test/ash_surface/projector/voice_kiosk_test.exs` |
| `lib/ash_surface/projectors/{aria,js,live_view}.ex` — projector set | `test/ash_surface/projectors/aria_projector_test.exs`; `test/ash_surface/projectors/js_projector_test.exs`; `test/ash_surface/projectors/live_view_test.exs`; `test/ash_surface/aria_projector_test.exs`; `test/ash_surface/live_view_projector_test.exs` |
| No-local-DO invariant walk over `lib/ash_surface/**/*.ex` (see section 3) | `test/ash_surface/no_local_do_test.exs` |
| Whole-tree refactor safety net + validator/IR alignment | `test/ash_surface/refactor_safety_net_test.exs`; `test/ash_surface/resource/validator_ir_alignment_test.exs` |
| `lib/ash_surface/transport.ex` (`AshSurface.Transport`, incl. `Decision`, select/fallback/outcome laws) | `test/ash_surface_test.exs` (selection/fallback laws); `test/ash_surface/transport_select_test.exs` **[NEW]**; `test/ash_surface/transport_fallback_test.exs` **[NEW]**; `test/ash_surface/transport_outcome_test.exs` **[NEW]**; `test/ash_surface/transport_falsifiers_test.exs` **[NEW]**; real `select/3` call in `test/ash_surface/health_test.exs` **[NEW]**; `test/js/transport_law.test.mjs` **[NEW]** |
| `lib/ash_surface/health.ex` | `test/ash_surface/health_test.exs` **[NEW]**; `test/ash_surface/health_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/event.ex` | `test/ash_surface/event_test.exs` **[NEW]**; `test/ash_surface/event_deep_test.exs` **[DEEP]**; `test/js/event_observation.test.mjs` **[NEW]** |
| `lib/ash_surface/observation.ex` | `test/ash_surface/observation_test.exs` **[NEW]**; `test/ash_surface/observation_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/planning_episode.ex` | `test/ash_surface/planning_episode_test.exs` **[NEW]**; `test/ash_surface/planning_episode_deep_test.exs` **[DEEP]**; `test/js/planning_episode.test.mjs` **[NEW]** |
| `lib/ash_surface/projector/expo.ex` (eight-file artifact set, schemas/actions/events/receipts emissions, client factory, determinism) | `test/ash_surface/projector/expo_test.exs` **[NEW]**; `test/ash_surface/projector/expo_schemas_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_actions_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_events_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_receipts_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_client_test.exs` **[DEEP]**; `test/ash_surface/projector/expo_determinism_test.exs` **[DEEP]** |
| Whole closed loop (`Observation` + `PlanningEpisode` + `Event` over the fixture domain) | `test/ash_surface/mx_closed_loop_episode_test.exs` **[NEW]**; `test/ash_surface/mx_closed_loop_deep_test.exs` **[DEEP]** |
| `lib/ash_surface/formatter.ex` **[RETIRED]** (chicago-formatter-retire-033: decorative plugin for the never-existing `AshSurface.Resource`; decision ledgered HANDWRITTEN+UNSUPPORTED) | canary against the pattern's return: `test/ash_surface/formatter_registration_canary_test.exs`; the formatting gate itself remains `mix format --check-formatted` |
| `lib/ash_surface/resource/validator.ex` | `test/ash_surface/resource/validator_test.exs`; `test/ash_surface/resource/validator_adversarial_test.exs` **[DEEP]** |
| `priv/static/ash_surface_runtime.mjs` (Zod/JSDoc runtime: `createClient`, schemas, `SurfaceRuntimeError`) | `test/js/runtime.test.mjs`; `test/js/zod_boundaries.test.mjs` **[NEW]**; `test/js/error_paths.test.mjs` **[NEW]**; `test/js/namespaces_deep.test.mjs` **[DEEP]**; `test/js/receipts_primitives.test.mjs` **[NEW]**; `test/js/consumer_fixture.test.mjs` **[NEW]**; `test/js/zoela_mx_consumer_fixture.test.mjs` **[NEW]**; `test/js/e2e_hermetic.test.mjs` **[NEW]** |
| Cross-language manifest -> surface -> JS dispatch -> Ash consequence -> receipt | `test/ash_surface/consumer_fixture_test.exs` **[NEW]** (spawns `test/js/consumer_e2e_runner.mjs` against the loopback server) |
| Projected Expo artifacts (manufactured output) | `test/ash_surface/projector/expo_test.exs` **[NEW]** (file set + `node --check`), plus `npm run check` for the runtime itself |

Support: `test/support/fixtures.ex` holds the fixture Ash domain/resource
(ETS) and the ephemeral loopback HTTP server — it is a fixture domain, not a
helpers module. `test/support/compiler_echo_section.ex` is the one injected
double (see section 2), kept in `test/support` so it compiles to a beam the
compiler's `Code.ensure_loaded` validation can witness.

## 5. How to add a test

Elixir:

- Path mirrors `lib/`: a module at `lib/ash_surface/<name>.ex` is tested at
  `test/ash_surface/<name>_test.exs`; nested modules get nested dirs
  (`lib/ash_surface/projector/expo.ex` ->
  `test/ash_surface/projector/expo_test.exs`).
- `use ExUnit.Case, async: true` unless the test owns processes or scratch
  dirs (the fixture-server, projector, and closed-loop tests use
  `async: false` for exactly that reason).
- Helpers live inside your own test module as `defp`s (see `manifest/0` in
  `test/ash_surface_test.exs`, `canonical_json/1` in
  `test/ash_surface/consumer_fixture_test.exs`). The only shared support
  files are `test/support/fixtures.ex` (fixture domain + loopback server)
  and `test/support/compiler_echo_section.ex` (the compiler `:sections`
  double); do not add others without a seam that requires a compiled module.
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
the zero-config story, add `mix test.zero`,
`bash scripts/zero_config_check.sh`, and `bash scripts/zero_config_v2.sh`
(per `AGENTS.md`, cheapest high-information gate first; never call generated
code ALIVE without an exact consumer execution receipt; never report an
**[INTEGRATION]** path — a path absent from this branch by design — green
from this branch; the no-local-DO tripwire runs inside `mix test`).
