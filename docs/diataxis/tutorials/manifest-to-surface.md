# Tutorial: From an Ash Application to a Verified Consumer Surface

Learn mode: you are following along to learn the core loop. Every step below
was verified against the sources named in each section; nothing here invents
an API.

Prerequisites:

- Elixir ~> 1.15 (`mix.exs`)
- An Ash application with at least one `Ash.Domain` (`ash ~> 3.33.1`)

## 1. Generate the surface from your app

`AshSurface.from_app/2` generates the OTP app's public `Ash.Info.Manifest`
and builds a verified surface in one call
(`lib/ash_surface.ex`, `from_app/2`):

```elixir
{:ok, surface} = AshSurface.from_app(:my_app)
```

Or start from a manifest you already have (`AshSurface.from_manifest/2`,
`lib/ash_surface.ex`):

```elixir
{:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :my_app)
{:ok, surface} = AshSurface.from_manifest(manifest, profile: %{"tier" => "gold"})
```

Each entrypoint becomes a stable action id, `Resource#action`
(`AshSurface.action_id/1`, `lib/ash_surface.ex`).

## 2. Inspect the surface

A `%AshSurface.Surface{}` carries exactly four facts
(`lib/ash_surface.ex`, `defmodule Surface`):

- `manifest` — your manifest, decorated with `custom.ash_surface` metadata
- `contract` — the cross-language contract map
- `digest` — lowercase sha256 hex (64 chars) over the canonical encoding of
  `contract` (`AshSurface.contract_digest/1`, `lib/ash_surface.ex`)
- `action_ids` — the sorted list of `"Resource#action"` ids

The contract map is

```elixir
%{
  "surfaceSchemaVersion" => "26.10.7",
  "ashManifestSchemaVersion" => Ash.Info.Manifest.schema_version(),
  "generatorIdentity" => "ash_surface:v26.10.7",
  "manifestDigest" => ...,   # digest of the serialized Ash manifest
  "marketplaceIdentity" => "ggen-marketplace:v26.10.7 CalVer",
  "manifest" => ...,          # Ash-owned semantics, serialized by Ash
  "surface" => %{"profile" => ..., "actions" => [...]},
}
```

fields as built by `contract/2` and `surface_envelope/2`
(`lib/ash_surface.ex`).

## 3. Add per-action profile metadata

The profile's optional `"actions"` map is keyed by action id; unknown ids are
refused, never silently kept (`validate_profile_actions/2`,
`lib/ash_surface.ex`):

```elixir
{:ok, surface} =
  AshSurface.from_manifest(manifest,
    profile: %{
      "actions" => %{
        "MyApp.Post#read" => %{
          "evidenceRequired" => true,
          "possibleRefusals" => ["REFUSED_NO_AUTHORITY"]
        }
      }
    }
  )
```

Two per-action fields are type-checked
(`validate_action_profile/2`, `lib/ash_surface.ex`):

- `"evidenceRequired"` must be a boolean
- `"possibleRefusals"` must be a list of strings, each matching the
  `REFUSED_<TOKEN>` pattern (`AshSurface.Vocabulary.refusal_code?/1`)

Unknown ids produce `{:error, {:unknown_action_profile, ["Nope#x"]}}` —
verified by the doctest at `lib/ash_surface.ex` (lines 64-66).

## 4. Verify the digest at the boundary

Anything that receives a surface from outside the constructor recomputes the
digest instead of trusting the claimed value
(`AshSurface.verify_surface_digest/1`, `lib/ash_surface.ex`):

```elixir
:ok = AshSurface.verify_surface_digest(surface)
```

## 5. Project into a consumer artifact

`AshSurface.project/3` is the public facade: the surface travels as
`ash_surface.surface` IR and the projector's `project_ir/2` runs over it
(`lib/ash_surface.ex`, `project/3`; `lib/ash_surface/projector/ir.ex`).
A module without `project_ir/2` is refused with
`{:error, {:unsupported_projector, module}}`.

The JS projector consumes canonical per-action IR, so compile the surface's
manifest first (`AshSurface.Compiler.compile/1`, `lib/ash_surface/compiler.ex`):

```elixir
{:ok, irs} = AshSurface.Compiler.compile(surface.manifest)

{:ok, artifacts, meta} =
  AshSurface.Projectors.JS.project_ir(irs, prefix: "my_app_client", target_dir: "assets/js")

artifacts  # %{"my_app_client.mjs" => source}
meta       # %{prefix: "my_app_client", action_count: n, namespace_count: m}
```

Surface-consuming projectors (Expo, VoiceKiosk) instead take the whole
surface through `AshSurface.project/3`, which wraps it as
`ash_surface.surface` IR (`lib/ash_surface.ex`, `project/3`):

```elixir
{:ok, artifacts, meta} = AshSurface.project(surface, AshSurface.Projector.Expo)
```

A module without `project_ir/2` is refused with
`{:error, {:unsupported_projector, module}}`.

## 6. Consume in JavaScript

The runtime adapter ships at `priv/static/ash_surface_runtime.mjs`; get its
path from the library (`AshSurface.runtime_path/0`) or read it with
`AshSurface.runtime_source/0`.

```javascript
import { createClient } from "./ash_surface_runtime.mjs";

const client = createClient({
  contract: ashSurfaceContract,   // surface.contract serialized as JSON
  transports: {
    http: httpAdapter,
    phoenix_channel: channelAdapter,
  },
});
```

`createClient` is exported at `priv/static/ash_surface_runtime.mjs:321`. The
runtime exposes stable `actions[id]` lookup, `resources[resource][action]`
namespaces, Zod validation at the untrusted boundary, adaptive transport
selection before dispatch, explicit receipts for `SUCCESS` vs
`UNKNOWN_AFTER_DISPATCH`, and validated `reconcile` replies
(`COMPLETED | NOT_OBSERVED | STILL_UNKNOWN`).

## Recap

`from_app/from_manifest` -> verified `Surface` (digest-verified at every
boundary) -> `project/3` through a projector -> executable consumer artifact
-> `createClient` in the consumer. One Ash model, many lawful consumer
projections.
