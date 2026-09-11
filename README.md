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
