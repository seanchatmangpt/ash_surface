# ash_surface Documentation — Diátaxis Index

This directory is the canonical navigation surface for current `ash_surface` documentation. Current behavior is defined by executable code and tests; prose records only what those surfaces support.

## Tutorials

Learning-oriented, end-to-end paths:

- [`tutorials/manifest-to-surface.md`](tutorials/manifest-to-surface.md) — from an Ash application to a verified consumer surface: generate, verify, consume the surface.

## How-to guides

Goal-oriented procedures:

- [`how-to/dispatch-intent-safely.md`](how-to/dispatch-intent-safely.md) — record a human intent and dispatch it to a server-side actuation path without ever replaying a consequential action.
- [`how-to/expose-a2a-agent-card.md`](how-to/expose-a2a-agent-card.md) — project a resource's compiled `AshA2A` capability index onto the A2A wire as an agent-card fragment via `AshSurface.A2ABridge`.

## Reference

Exact factual contracts:

- [`reference/api.md`](reference/api.md) — public API of `ash_surface` 26.10.8, verified against cited files at HEAD; anything not listed is not a public surface.

## Explanation

Conceptual architecture and rationale:

- [`explanation/projection-boundary-laws.md`](explanation/projection-boundary-laws.md) — why AshSurface projects and never decides: the boundary law, no minted resources/actions/types, no authority, no actuation.

## Capability standing rules

- **ALIVE** requires observed execution against the exact admitted subject.
- Source inspection, workflow presence, test names, and documentation are not execution proof.
- When local execution is unavailable, exact-head GitHub CI may qualify the changed subject, but only successful runs on the exact head are admitted.
- Semantic projections and generated/read models have no ambient execution authority.

## Canonical-source decisions

- Executable Ash/Igniter code under `lib/` is authoritative for behavior.
- `docs/diataxis/README.md` (this file) is authoritative for documentation navigation; individual pages link to, rather than duplicate, contracts owned by other quadrants.
