# Changelog

All notable changes to `ash_surface` are recorded here. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: CalVer
`YY.M.N` (e.g. `26.9.17`). There are no git tags yet; entries below are seeded
from `git log` since the PR #7 merge (`7d5c354`, 2026-09-26) up to `2654cdc`.

## [Unreleased]

### Added
- Supply-chain gating: `.github/dependabot.yml`, `security.yml` (daily
  `mix hex.audit`, `npm audit`, lock hygiene, SBOM drift), `release.yml`
  (tag-triggered gates, SBOM, build provenance, environment-gated hex publish).
- Deterministic CycloneDX 1.5 SBOM generator (`scripts/sbom.sh`) covering
  `mix.lock` and `package-lock.json`.
- `SECURITY.md`, `docs/SUPPLY_CHAIN.md`, `docs/RELEASING.md`.
- `mix supply.check` alias (`deps.unlock --check-unused` + `hex.audit`).

### Removed (breaking)
- **Breaking: the ZOE / DfCM devotional human-surface family left core.**
  `AshSurface.{HumanSurface, PersonalizationContext, Possibility,
  PossibilitySet, WhyThis, OutcomeHypothesis, DevotionalEpisode, Journey,
  CommitmentBoundary, ManufactureTrace, ZoeDemo}`, their Zod schemas and
  `parseHumanSurfaceProjection` (was in `priv/static/ash_surface_runtime.mjs`),
  and the `*.human.mjs` / `*.demo.mjs` Expo artifacts (with the
  `human_surface: true` key of `AshSurface.Projector.Expo` meta) moved to the
  in-repo package `packages/ash_surface_zoe` (`{:ash_surface_zoe, ...}`).
  Module names are unchanged, so consumers only add the dependency; JS
  consumers import the schemas from `ash_surface_zoe`
  (`priv/static/ash_surface_zoe.mjs`) instead of `ash_surface`. The human/demo
  artifacts are now emitted by `AshSurfaceZoe.Projector.Human` (an
  `AshSurface.Projector.IR` implementation). Generic Expo artifacts are
  byte-identical. Run the package suite with `mix test.zoe`.

### Changed
- **Breaking:** one projector contract. The legacy `AshSurface.Projector`
  behaviour (`project/2`), `Projector.IR.from_manifest_projector/1`,
  `Projector.IR.ManifestProjector`, and the `legacy_only?/1` dispatch guard
  are removed. `Projector.Expo` and `Projector.VoiceKiosk` implement
  `project_ir/2` (surface travels as `ash_surface.surface` IR; digest
  re-verified) with byte-identical artifacts and meta; `JS`, `ARIA`,
  `LiveView`, `Expo`, and `VoiceKiosk` all declare
  `@behaviour AshSurface.Projector.IR`. The callback `input` type is widened
  to name `%AshSurface.IR{}` structs; `ARIA.project_ir/2` now refuses non-IR
  input with `{:error, {:not_an_ir, term}}`. `AshSurface.project/3` stays the
  facade but now verifies the surface digest. `Expo.project/2` and
  `VoiceKiosk.project/2` are gone (use `AshSurface.project/3`);
  `VoiceKiosk.project_ir/1` (bare intents map) is renamed `voice_ir/2`.
  Migration note: `docs/PROJECTORS.md` §4.
- Hex `package/0` now ships `LICENSE`, `CHANGELOG.md`, `SECURITY.md`.

### Known issues
- `mix hex.build` refuses the package while `ash_a2a` and `ash_r2rml` are git
  dependencies ("Only Hex packages can be dependencies"). Source tarball and
  provenance work; hex publication is blocked until those are published.

## [26.9.17] - 2026-09-28

Hardening wave on top of PR #7 (`914bf28`..`2654cdc`).

### Security
- `mint` 1.10.1 -> 1.11.0 (EEF-CVE-2026-91043, EEF-CVE-2026-92103,
  EEF-CVE-2026-94194) (`10b2be4`).
- Boundary refusals are typed at `from_manifest`, `EventProjection` and
  `Codec`; the closure verifier is port-bounded (`7b5299e`).
- Runtime: null-prototype registries, bounded dispatch, validated reconcile
  (`bc80ed3`); the generated Expo client's reconcile is bounded and validated
  (`1916c09`).
- JavaScript emission refuses unsafe inputs; projectors project compiled IR
  without crashing (`06f7a7f`).
- Portable `commandId`, pre-dispatch abort, narrowed digest binding, typed JS
  refusals (`2654cdc`).
- `REFUSED_*` refusal vocabulary enforced; ARIA reads compiled `fields`
  (`7fad2ca`).

### Changed
- Coverage gate raised 90 -> 97 (measured 98.30%); Chicago census re-pinned
  (137 suites, floor 1217) (`3247167`).

### Tests
- State-based (Chicago) suites closing coverage gaps and hardening refusal
  boundaries (`914bf28`).

## Earlier (pre-26.9.17, PR #7 and before)

- Lineage court re-judgment in CI on the checked-out head; documented
  `ASH_SURFACE_LINEAGE_HEAD` in the zero-config allowlist (`b23025a`,
  `ea3a378`).
- `ash_a2a` repinned to the released `v26.9.22` tag; `ash` and `mint` moved
  beyond then-current advisories (`be95b3e`, `ccfe956`).
- ZOE human surface, command center, and bounded consumer demo (`df0e859`,
  `560c848`, `f7d5c3e`).
