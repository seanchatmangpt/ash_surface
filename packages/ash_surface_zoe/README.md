# ash_surface_zoe

ZOE / DfCM devotional human-surface family for
[`ash_surface`](../../README.md), extracted from core (AGENTS.md doctrine:
core is a generalized consumer projection layer over Ash; a devotional product
domain does not belong in it).

**Module names are unchanged** (`AshSurface.HumanSurface`,
`AshSurface.Possibility`, `AshSurface.ZoeDemo`, ...): consumers only add the
dependency.

```elixir
{:ash_surface, "~> 26.9"},
{:ash_surface_zoe, "~> 0.1"}
# in this monorepo: {:ash_surface_zoe, path: "packages/ash_surface_zoe"}
```

## What lives here

| Piece | Path |
| --- | --- |
| Elixir projection structs + `ZoeDemo` | `lib/ash_surface/*.ex` (11 modules, same names as before) |
| Namespace / runtime path | `lib/ash_surface_zoe.ex` (`AshSurfaceZoe.runtime_path/0`) |
| Expo human/demo projector (`AshSurface.Projector.IR`) | `lib/ash_surface_zoe/projector/human.ex` (`AshSurfaceZoe.Projector.Human`) |
| Zod schemas + `parseHumanSurfaceProjection` | `priv/static/ash_surface_zoe.mjs` |
| Tests | `test/ash_surface/*.exs`, `test/js/*.test.mjs` |

## Core seams (what stays in core, and why)

Core imports nothing from this package. This package imports from core only
`AshSurface.Projector.IR` (behaviour + `to_surface/1`), `AshSurface.project/3`
at test time, and `SurfaceRuntimeError` from the core JS runtime. The
generated `human.mjs` imports schemas from `"ash_surface_zoe"`; the package's
schemas import `SurfaceRuntimeError` from `"ash_surface"` (the consumer
resolves both bare specifiers, exactly as generated Expo code already resolves
`"ash_surface"`).

## Projecting the human/demo artifacts

```elixir
{:ok, generic, _} = AshSurface.project(surface, AshSurface.Projector.Expo, prefix: "zoela_surface", target_dir: dir)
{:ok, human, _}   = AshSurface.project(surface, AshSurfaceZoe.Projector.Human, prefix: "zoela_surface", target_dir: dir)
```

The union of the two file sets equals the former single Expo output; the
generic files are byte-identical to before the extraction.

## Versioning and release

Versioned independently from core (`0.1.0`, SemVer; core is CalVer). The
`ash_surface` requirement is the compatibility contract: bump this package when
its own surface changes, and widen/raise the core requirement when a CalVer
core release changes `AshSurface.Projector.IR`, the runtime's
`SurfaceRuntimeError`, or the surface digest law. In the monorepo it uses a
path dependency on core (`../..`); for a Hex release, publish core first,
replace the path dep with `{:ash_surface, "~> 26.9"}`, then `mix hex.publish`
from this directory. Changes are recorded in the root `CHANGELOG.md`.

## Testing

```text
cd packages/ash_surface_zoe
mix deps.get && mix test        # Elixir suite (also: `mix test.zoe` from the repo root)
npm test                        # JS suite (links core runtime as node_modules/ash_surface first)
```

Root-level `mix test.all` does not include this package (core must stay green
without it); run `mix test.zoe` explicitly.

## The ZOE human surface (v26.9.21 family)

AshSurface (with this package) projects the ecosystem into a human grammar without moving
domain truth, planning, or consequence authority into the UI.

```text
SEE -> UNDERSTAND -> EXPLORE -> CHOOSE -> ACT -> LEARN
```

The stable ZOE member areas are:

```text
TODAY | BIBLE | LIFE | ZOE | YOU
```

These are projections, not independent application models:

- `Possibility` / `PossibilitySet` project a DfCM maximal reversible frontier.
- `WhyThis` projects evidence-bounded rationale and requires a falsifier for hypotheses.
- `PersonalizationContext` keeps USER_STATED, OBSERVED, and INFERRED profile facets distinct,
  subject-private, and non-authoritative. INFERRED facets require falsifiers.
- `ManufactureTrace` projects `A=mu(O*)`: every O* reference must be present in the
  observed/admitted/grounded/bounded/aligned intersection, and ALIVE requires a receipt.
- `OutcomeHypothesis` projects a practice-to-outcome candidate while fixing `causalClaim=false`.
- `DevotionalEpisode` composes scripture/commentary/prayer/reflection into one ordered
  `STRAIGHT_THROUGH` episode so a devotional can be listened to without manually
  starting every passage.
- `CommitmentBoundary` makes consequences legible to the human, but stops at
  `CONSTRUCT` and hands confirmed intent to BRCE. It never owns DO.
- `Journey` is the subject-private human replay over observed event/evidence/receipt identities.
- `HumanSurface` composes those projections into TODAY/BIBLE/LIFE/ZOE/YOU.
- `AshSurfaceZoe.Projector.Human` manufactures a `*.human.mjs` artifact; core
  `AshSurface.Projector.Expo` keeps emitting schemas/actions/events/receipts/TanStack/client.
- It also manufactures a deterministic `*.demo.mjs` consumer court for Wednesday:
  a DfCM view model, straight-through player, injectable HTML-audio adapter,
  provenance-visible HTML, and a CONSTRUCT-only BRCE intent boundary. The demo
  artifact has no client construction or transport invocation path.

This package's `priv/static/ash_surface_zoe.mjs` exports Zod schemas for every human projection plus
`parseHumanSurfaceProjection(...)`, including subject-private personalization
and receipted manufacture-provenance contracts. Human surfaces require
`authorityBoundary="OBSERVE"` and `doAuthority=false`; commitment boundaries
require `authorityCeiling="CONSTRUCT"` and `nextHandoff="BRCE"`.

### Deterministic Wednesday demo

`AshSurface.ZoeDemo` manufactures a synthetic, deterministic member surface
that exercises the full local projection without pretending that private member
data, live Planning Center state, outcome causality, or production execution has
been observed.

```elixir
surface = AshSurface.ZoeDemo.surface()
map = AshSurface.ZoeDemo.map()
acceptance = AshSurface.ZoeDemo.acceptance()
```

The demo fixture shows four preserved alternatives instead of a single opaque
recommendation: listen to the continuous devotional, read the same episode,
explore serving, or keep the current rhythm. Its personalization basis is a
synthetic USER_STATED goal facet, and the candidate mapping carries an explicit
receipted `A=mu(O*)` trace rather than an opaque recommender score. "Why this?" is explicitly a
hypothesis with a falsifier. The Life projection shows an UNKNOWN candidate
relationship between the devotional and a selected consistency outcome. The
serving path stops at a visible commitment boundary before BRCE.

### Wednesday evidence ceiling

Repository courts can establish the projection contracts, deterministic demo
fixture, generated Expo artifact syntax, Zod admission/refusal behavior,
manufactured human-module execution against the demo fixture, and the existing
manifest -> JavaScript -> HTTP -> Ash consequence -> receipt fixture.

The generated demo consumer now executes the synthetic Wednesday fixture end to
end inside the repository court: four preserved choices, straight-through local
playback over all four devotional segments, an injected HTML-audio-compatible
adapter, visible WhyThis / personalization / `A=mu(O*)` provenance, private
journey replay, and construction of a BRCE handoff with `dispatched=false`.

They do not by themselves establish:

- live ZOE member/profile data;
- live Planning Center reads or writes;
- Bible/audio content licensing or production media availability;
- a causal life outcome from a religious practice;
- production deployment or device-route standing;
- organizational adoption;
- any consequence not represented by an observed BRCE receipt.

