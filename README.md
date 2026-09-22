# ash_surface

`ash_surface` is a **manifest-first consumer projection/runtime layer** for Ash applications.
Ash remains the application model. AshSurface turns that model into application-facing consumer surfaces without forcing each consumer to rediscover resources, actions, relationships, types, filters, pagination, transport, or projection metadata.

## Core boundary

```text
Ash resources/actions/policies
            │
            ▼
     Ash.Info.Manifest
            │
   custom.ash_surface
            │
            ▼
         AshSurface
      ┌─────┼──────────┬─────────┐
      ▼     ▼          ▼         ▼
    π_JS  π_Phoenix   π_Vue     π_Expo   ...
```

AshSurface is the generalized consumer-facing layer. JavaScript is one projection of it:

```text
π_JS(AshSurface) = executable .mjs + JSDoc + Zod
```

There is **no TypeScript support contract** in `ash_surface`: no generated `.ts`, no `.d.ts`, no `tsc` build step, and no AshTypescript runtime dependency. AshTypescript is useful prior art for the client-projection problem, but it is not an input, authority, or artifact owner here.

The core rule is:

> **One Ash application model, many lawful consumer projections.**

## Elixir contract

`AshSurface.from_manifest/2`:

1. accepts an existing `%Ash.Info.Manifest{}`;
2. validates projection metadata against the exact public Ash action set;
3. stores extension metadata only under `custom.ash_surface`;
4. serializes Ash-owned semantics through `Ash.Info.Manifest.JsonSerializer`;
5. adds a small `surface` envelope for derived action identity and projection metadata;
6. does not create a second resource/action/type model;
7. binds both Ash Manifest and AshSurface schema identities;
8. emits a stable SHA-256 content digest over the resulting cross-language contract.

```elixir
{:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :my_app)

{:ok, surface} =
  AshSurface.from_manifest(manifest,
    profile: %{
      audience: :public,
      actions: %{
        "MyApp.Post#read" => %{
          consumer: :web,
          transport: :auto
        }
      }
    }
  )

surface.contract
surface.digest
```

Unknown action metadata is refused rather than becoming a dangling client model.

## JavaScript projection

The JavaScript runtime consumes the **AshSurface contract directly**.

It provides:

- `createClient(...)`;
- stable `actions[id]` lookup;
- stable `resources[resource][action]` namespaces;
- JSDoc-described public APIs;
- Zod validation at the untrusted JavaScript boundary;
- adaptive transport selection before dispatch;
- explicit receipts for completed vs unknown-after-dispatch outcomes;
- no TypeScript compilation step.

```javascript
import { createClient } from "./ash_surface_runtime.mjs";

const client = createClient({
  contract: ashSurfaceContract,
  transports: {
    http: httpAdapter,
    phoenix_channel: channelAdapter,
  },
  prefer: "phoenix_channel",
});

const createPost = client.resources["MyApp.Post"].create;
const result = await createPost.invoke({ title: "Ship it" });
```

The JavaScript files are ordinary `.mjs`. JSDoc supplies editor/static typing. Zod supplies executable boundary schemas. No generated TypeScript is necessary or supported.

## Transport semantics

Transport is not action identity.

```text
Ash action identity
      │
      ├─ admitted HTTP adapter
      └─ admitted Phoenix Channel adapter
                  │
          select before dispatch
                  │
                dispatch
                  │
       completed OR unknown-after-dispatch
```

If a preferred transport is unavailable **before** dispatch, another admitted transport may be selected. Once dispatch has occurred, a timeout/disconnect does not prove non-execution. AshSurface therefore returns `TRANSPORT_OUTCOME_UNKNOWN` and does not silently replay the action over another transport.

## Projection boundary

Additional consumers implement `AshSurface.Projector` and receive a verified `AshSurface.Surface`. They should consume normalized manifest data rather than re-walking Spark/Ash internals.

Current architectural ownership remains intact:

- AshPhoenix owns Phoenix forms/LiveView integration.
- AshSDUI owns server-driven LiveView layout/runtime semantics.
- `live_vue` owns Vue↔LiveView rendering/hooks/SSR.
- cache libraries such as TanStack Query own server-state caching.

AshSurface may manufacture adapters/descriptors for those consumers without absorbing their responsibilities.

## ggen extension manufacture

The Ash extension surface is modeled as admitted RDF and manufactured through `ggen-marketplace/packs/ash-extension-core-pack` rather than hand-maintained Spark boilerplate. The generated extension artifacts are pack-owned; edits belong in the ontology/pack path and must be regenerated.

## Development

```bash
npm install --ignore-scripts --no-audit --no-fund
node --check priv/static/ash_surface_runtime.mjs
node --test test/js/runtime.test.mjs
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The JavaScript projection requires Zod at runtime and does not require TypeScript.


## DfCM live command center projection

`AshSurface.Obligation` and `AshSurface.CommandCenter` provide the consumer
surface for a Blue River Dam / SA2A operational loop without moving actuation
authority into the UI layer.

```text
external systems
    -> semantic admission / Knowledge Hooks
    -> SA2A capability + authority
    -> planner SELECT / CONSTRUCT
    -> CommandBus DO
    -> receipts + independent observation
    -> AshSurface.CommandCenter (OBSERVE only)
```

The command-center projection composes already-admitted observations,
operational obligations, planning episodes, capability descriptions, and
receipt identities. It derives no business semantics and cannot dispatch a
command. An obligation's identity is stable across state changes while its
state digest changes, making assignment/escalation transitions replayable and
consumer-safe.

This boundary is intentionally DfCM: upstream systems may be Planning Center,
WebEOC, Everbridge, ArcGIS, a security vendor, a human observer, or a future
adapter. AshSurface preserves those lawful alternatives instead of becoming
their owner.


## ZOE human surface v26.9.21

AshSurface now projects the ecosystem into a human grammar without moving
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
- `AshSurface.Projector.Expo` manufactures a `*.human.mjs` artifact alongside
  schemas/actions/events/receipts/TanStack/client artifacts.
- It also manufactures a deterministic `*.demo.mjs` consumer court for Wednesday:
  a DfCM view model, straight-through player, injectable HTML-audio adapter,
  provenance-visible HTML, and a CONSTRUCT-only BRCE intent boundary. The demo
  artifact has no client construction or transport invocation path.

The JavaScript runtime exports Zod schemas for every human projection plus
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

The CI security audit is also a separate gate. As of this implementation the
runner advisory feed flags the currently locked latest Ash/Mint releases; that
condition must remain visible rather than being suppressed merely to make the
demo branch green.
