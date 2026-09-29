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

## Human boundary (v26.9.16)

`ash_surface` is to humans what the A2A wire protocol is to machines: a **projection/interaction boundary** into the same admitted semantic system. Machines reach Ash semantics over the agent-to-agent wire; humans reach the same semantics through a rendered, interactive surface. Neither boundary mints existence, meaning, or consequence — both project what Ash has already admitted.

The composition is four prior arts converging on Ash:

```text
ash_admin ....... human projection of an Ash application
ash_r2rml ....... meaning: rows mapped into admitted semantics
AshTypescript ... shared-discovery pattern (one contract, many consumers)
ash_a2a ......... capability/consequence law (what may be done, what it costs)
                     │
                     ▼
                    Ash
```

Each contributes a pattern, never authority. `ash_admin` shows that a human surface is a projection of resources/actions, not a second application model. `ash_r2rml` shows that meaning is mapped into the system, never invented at the boundary. AshTypescript shows one contract discovered by many consumers — pattern-level prior art only, per the TypeScript disclaimer above. `ash_a2a` shows the capability/consequence law: expose only what has been admitted, and carry the consequence semantics of doing it.

Two invariants hold at this boundary:

1. **AshSurface determines nothing about existence, meaning, or DO.** It mints no resources, actions, or types; it decides no authority; it never actuates. Existence and meaning come from Ash; consequence requires the authority and receipts the capability laws already demand.
2. **AshSurface projects admitted semantics for human interaction.** Everything a human sees, invokes, or edits on a surface is a projection of semantics Ash has already admitted — never a parallel model, never a widening.

Canonical elaboration lives in the sibling documents: [`ARCHITECTURE.md`](ARCHITECTURE.md) for the layer/boundary structure, and [`PROJECTORS.md`](docs/PROJECTORS.md) for the projector contract (`AshSurface.Projector.IR`) and its lawful targets.

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
- a bounded dispatch (`timeoutMs`, `signal`) that settles a hung adapter as unknown-after-dispatch;
- validated `reconcile` replies (`COMPLETED | NOT_OBSERVED | STILL_UNKNOWN`);
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

Dispatch is bounded per call:

```javascript
await createPost.invoke(
  { title: "Ship it" },
  { timeoutMs: 5_000, signal: abortController.signal },
);
```

A `signal` that is already aborted is refused **before** dispatch (`DISPATCH_ABORTED_PRE_DISPATCH`, no adapter call, no receipt). An adapter that never answers within `timeoutMs`, or whose `signal` aborts after dispatch, settles as `TRANSPORT_OUTCOME_UNKNOWN` (`dispatchState: "unknown_after_dispatch"`, cause `DISPATCH_TIMEOUT` / `DISPATCH_ABORTED`) - never a hang, never a replay over another transport. Timers and abort listeners are always released. An invalid `timeoutMs` (non-positive, non-finite, non-number) or a `commandId` that is not a non-empty string is refused before dispatch (`INVALID_OPTIONS`). Default command ids are `cmd_` + a UUID from `crypto.randomUUID`, falling back to `crypto.getRandomValues` and then a non-crypto id, so the client also runs on React Native/Hermes, Node 18 and non-secure browser contexts. Transports are looked up as own properties only, everywhere. A malformed `reconcile` reply is `INVALID_RECONCILE_RESULT`, not trusted. Client registries are null-prototype objects, so contract-supplied resource or action names such as `__proto__` or `constructor` are ordinary keys and cannot reach `Object.prototype`.

On the Elixir side, `AshSurface.Transport.select/3` treats declared/available transport lists as sets: a repeated member is `{:error, {:duplicate_transport, [...]}}`.

## Idempotent retry and observability

A post-dispatch retry exists only for actions whose profile admits the separately specified `ash_surface.idempotency/1` protocol (see [docs/IDEMPOTENCY.md](docs/IDEMPOTENCY.md)). It is never automatic: `client.retryUnknown(error, { input })` reconciles on the original transport first and replays (same command, same key, same transport unless `crossTransport` is admitted) only on `NOT_OBSERVED`. `COMPLETED` and `STILL_UNKNOWN` never replay, and an action without the protocol refuses retry with `IDEMPOTENCY_NOT_ADMITTED`. The server-side key law, canonical request digest and pure ledger live in `AshSurface.Idempotency`.

`createClient({ onEvent })` opts in to synchronous, exception-safe, payload-free events (`transport.selected`, `dispatch.started`, `dispatch.completed`, `dispatch.unknown_after_dispatch`, `dispatch.refused_pre_dispatch`, `reconcile.result`, `retry.*`). `VOCABULARY` exports the runtime's closed vocabularies for cross-language drift tests.

## Projection boundary

Additional consumers implement `AshSurface.Projector.IR` (`project_ir/2`; recover a verified `AshSurface.Surface` with `AshSurface.Projector.IR.to_surface/1`) and are run through `AshSurface.project/3`. They should consume normalized manifest data rather than re-walking Spark/Ash internals.

Current architectural ownership remains intact:

- AshPhoenix owns Phoenix forms/LiveView integration.
- AshSDUI owns server-driven LiveView layout/runtime semantics.
- `live_vue` owns Vue↔LiveView rendering/hooks/SSR.
- cache libraries such as TanStack Query own server-state caching.

AshSurface may manufacture adapters/descriptors for those consumers without absorbing their responsibilities.

## ggen extension manufacture

The Ash extension surface is modeled as admitted RDF and manufactured through `ggen-marketplace/packs/ash-extension-pack` (pinned `baa5f117`; the earlier `ash-extension-core-pack` was deprecated and removed — marketplace commits 5dc0f283f/9e9c23875) rather than hand-maintained Spark boilerplate. The generated extension artifacts are pack-owned; edits belong in the ontology/pack path and must be regenerated.

## Testing

Two commands, zero configuration: no environment variables, no database, no external services. The Elixir suite builds a real Ash application inside the test process.

```bash
mix test   # Elixir suite
npm test   # JavaScript suite (node --test)
```

`mix test` shells out to Node for the consumer-execution paths, so Node plus a one-time `npm install` (see Development) are the only prerequisites.

What is covered:

- **Core contract** — `AshSurface.from_manifest/2`: surface envelope, SHA-256 digest, refusal of unknown action metadata.
- **Consumer fixture (Elixir)** — end-to-end execution: manifest -> surface -> JS runtime -> HTTP dispatch -> Ash consequence -> cryptographic receipt.
- **Closed-loop episodes** — machine-only execution with independent episode verification.
- **Planning episodes** — FOND/HDDL projection under a strict non-DO authority ceiling.
- **Observations and events** — verified observation projections with content-addressed `stateDigest`, plus realtime event projection.
- **Health** — `AshSurface.Health.check/0` against real checks in the test runtime.
- **Expo projector** — complete Expo client artifacts verified with `node --check`.
- **JavaScript runtime** — `createClient`, stable resource/action namespaces, adaptive transport selection, Zod boundary validation, dispatch receipts.
- **JavaScript consumer fixtures** — the AshSurface contract consumed by real Node test runners, including the Zoela MX consumer.

See `TESTING.md` for the full testing doctrine and `scripts/zero_config_check.sh` for the zero-configuration guard.

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
consumer-safe. An obligation may be projected `:resolved` only when a
non-empty `postcondition_ref` is supplied — `AshSurface.Obligation.new/1`
raises `ArgumentError` (`"resolved obligation requires a postcondition_ref"`)
otherwise, making postcondition proof a hard precondition for resolved
projection (`lib/ash_surface/obligation.ex`). A command's `standing` defaults
to `:PARTIAL_ALIVE` (below the ALIVE evidence ceiling) and accepts only the
closed set
`[:ALIVE, :PARTIAL_ALIVE, :REFUSED, :BLOCKED]` — any other value raises
(`AshSurface.CommandCenter.new/1`, `lib/ash_surface/command_center.ex`).

This boundary is intentionally DfCM: upstream systems may be Planning Center,
WebEOC, Everbridge, ArcGIS, a security vendor, a human observer, or a future
adapter. AshSurface preserves those lawful alternatives instead of becoming
their owner.


## ZOE human surface (extracted to `ash_surface_zoe`)

The ZOE / DfCM devotional human-surface family (`HumanSurface`, `Possibility`,
`PossibilitySet`, `WhyThis`, `OutcomeHypothesis`, `PersonalizationContext`,
`ManufactureTrace`, `DevotionalEpisode`, `CommitmentBoundary`, `Journey`,
`ZoeDemo`), its Zod schemas, and the `*.human.mjs` / `*.demo.mjs` Expo
artifacts are a domain product, not generalized consumer projection. They live
in the in-repo package [`packages/ash_surface_zoe`](packages/ash_surface_zoe/README.md)
with unchanged module names: add `{:ash_surface_zoe, ...}` to use them. Core
`AshSurface.Projector.Expo` emits only the generic schemas/actions/events/
receipts/client/TanStack artifacts.

The CI security audit is also a separate gate. As of this implementation the
runner advisory feed flags the currently locked latest Ash/Mint releases; that
condition must remain visible rather than being suppressed merely to make the
demo branch green.
