# Security Policy

## Supported versions

`ash_surface` uses CalVer (`YY.M.N`). Only the **latest** released version
receives security fixes. Older releases are not backported; upgrade.

## Reporting a vulnerability

Do not open a public issue. Use GitHub private vulnerability reporting
("Security" tab -> "Report a vulnerability") on
<https://github.com/seanchatmangpt/ash_surface>, or email the maintainer
listed in `mix.exs`/the commit history.

Process: acknowledgement within 3 business days; triage and severity within
7 days; fix and coordinated disclosure targeted within 90 days (sooner for
actively exploited issues). Reporters are credited unless they decline. Include
a minimal reproduction; a failing test against the public API is ideal.

## Scope: what the boundary guarantees

Per `AGENTS.md` doctrine, Ash resources/actions/policies remain authoritative;
AshSurface projects them and does not replace them. Within that:

In scope (a defect here is a vulnerability):
- Boundary validation: the Zod-validated JavaScript runtime and typed
  `REFUSED_*` refusals at `from_manifest`, `EventProjection`, `Codec`.
- Generated JavaScript is ordinary `.mjs` and must not execute injected input;
  the projector refuses unsafe emission.
- Transport law: selection before dispatch; a post-dispatch timeout or
  disconnect is `UNKNOWN_AFTER_DISPATCH` and is never silently replayed over
  another transport.
- Bounded dispatch/reconcile and null-prototype registries (no prototype
  pollution via action or resource names).
- Supply chain: lockfile integrity, SBOM, provenance (docs/SUPPLY_CHAIN.md).

Out of scope (not guaranteed here):
- Authorization. Policies live in Ash; a client-side check is a projection,
  never enforcement. Bypassing server policy is an Ash/application issue.
- Server-state caching, Phoenix forms (AshPhoenix), SDUI/live_vue rendering.
- Vulnerabilities in dependencies (report upstream; we track them through
  Dependabot and the daily audit).
- Generated code that has not been executed by a consumer: it is not claimed
  ALIVE without an execution receipt.
