# ash_surface

`ash_surface` is a **manifest-first projection/runtime layer** for Ash applications.
It preserves Ash as the application model and turns the already-normalized public
surface into consumer-facing projections without teaching every consumer how to
rediscover resources, actions, relationships, types, filters, pagination, or
transport details.

## The fence

Ash already provides the source semantics. `Ash.Info.Manifest` is Ash's normalized
code-generation boundary. AshTypescript already projects that boundary into typed
RPC functions, validation schemas, HTTP calls, Phoenix Channel variants, and a
public versioned JSON manifest. AshPhoenix already owns Phoenix forms/LiveView.
AshSDUI already owns server-driven LiveView layouts. `live_vue` already owns the
Vue↔LiveView bridge.

So `ash_surface` does **not** replace any of them:

```text
Ash resources/actions/policies
            │
            ▼
     Ash.Info.Manifest
            │
       custom.ash_surface     ← projection metadata only
            │
            ▼
        AshSurface
       /     |      \
      /      |       \
AshTypescript  AshPhoenix   future projectors
      │
public JSON manifest
      │
      ▼
framework-neutral JS runtime
      │
React / Vue / Expo / TanStack adapters
```

The core rule is:

> **One application model, many lawful projections.**

## What v0 implements

### Elixir contract

`AshSurface.from_manifest/2`:

1. accepts an existing `%Ash.Info.Manifest{}`;
2. validates projection profile entries against the exact manifest action set;
3. stores metadata only under `custom.ash_surface`;
4. serializes through `Ash.Info.Manifest.JsonSerializer`;
5. binds the Ash manifest schema version and AshSurface wrapper schema version;
6. emits a stable SHA-256 content digest.

Unknown action metadata is refused instead of creating a dangling second model.

```elixir
{:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :my_app)

{:ok, surface} =
  AshSurface.from_manifest(manifest,
    profile: %{
      audience: :public,
      actions: %{
        "MyApp.Post#read" => %{consumer: :web}
      }
    }
  )

surface.digest
surface.contract
```

### AshTypescript runtime adapter

`priv/static/ash_surface_runtime.mjs` consumes **AshTypescript's public JSON
manifest**, not private AshTypescript modules. It builds action descriptors and
selects between the already-generated HTTP and Phoenix Channel functions.

```javascript
import * as rpc from "./ash_rpc.js";
import manifest from "./ash_rpc_manifest.json" with { type: "json" };
import { createSurface } from "./ash_surface_runtime.mjs";

const surface = createSurface({
  manifest,
  rpc,
  channel: joinedAshTypescriptChannel,
  prefer: "phoenix_channel",
});

const createTodo = surface.actions["todos:Todo:createTodo"];
const result = await createTodo.invoke({ input: { title: "Ship it" } });
```

The adapter deliberately does **not**:

- regenerate TypeScript types;
- regenerate Zod/Valibot schemas;
- own form validation;
- own client/server-state caching;
- own Vue/React/Expo rendering;
- automatically retry a dispatched action over a second transport.

Those capabilities already have mature owners.

## Transport semantics

Transport selection is pre-dispatch and reversible:

```text
Ash action identity
      │
      ├─ HTTP generated function
      └─ Phoenix Channel generated function
                  │
          select before dispatch
                  │
                dispatch
                  │
       success OR unknown-after-dispatch
```

If the preferred Channel is unavailable **before** dispatch, HTTP can be selected.
If a Channel or HTTP invocation fails after dispatch, `ash_surface` returns
`TRANSPORT_OUTCOME_UNKNOWN` and does not replay the action on another transport.
A timeout does not prove that a consequential action did not execute.

## Projection boundary

Additional consumers implement `AshSurface.Projector` and receive a verified
`AshSurface.Surface`. Projectors should consume normalized manifest data rather
than re-walking Spark/Ash internals.

Future projectors may include:

- TanStack Query descriptors;
- Expo/React Native bindings;
- Vue bindings feeding `live_vue`;
- AsyncAPI/event contracts;
- AshSDUI correspondence metadata.

They are not part of the core until their exact consumer boundary is implemented
and verified.

## Development

```bash
node --test test/js/runtime.test.mjs
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

The JavaScript test is dependency-free. Elixir verification requires a normal
Elixir/Ash toolchain.
