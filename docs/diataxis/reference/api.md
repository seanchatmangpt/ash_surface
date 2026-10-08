# Reference: Public API of ash_surface 26.10.8

Every entry below was verified against the cited file at HEAD. No invented
APIs; anything not listed here is not a public surface.

## Top-level module: `AshSurface` (`lib/ash_surface.ex`)

Constants: `AshSurface.schema_version/0` → `"26.10.8"`.

| Function | Signature | Notes |
|---|---|---|
| `from_app/2` | `atom(), keyword() -> {:ok, Surface.t()} \| {:error, term()}` | `Manifest.generate(otp_app:)` then `from_manifest/2` |
| `from_manifest/2` | `Manifest.t(), keyword() -> {:ok, Surface.t()} \| {:error, term()}` | `:profile` opt; refuses unknown action ids |
| `project/3` | `Surface.t(), module(), keyword() -> {:ok, artifacts, meta} \| {:error, term()}` | facade over `AshSurface.Projector.IR`; refuses modules without `project_ir/2` |
| `action_id/1` | `Entrypoint.t() -> String.t()` | `"Resource#action"` |
| `delegated/2` | `Entrypoint.t(), String.t() -> term() \| nil` | reads `custom.ash_surface` delegated facts |
| `runtime_path/0` / `runtime_source/0` | | path to / source of `priv/static/ash_surface_runtime.mjs` |
| `contract_digest/1` | `map() -> String.t()` | lowercase sha256 over canonical term encoding |
| `verify_surface_digest/1` | `Surface.t() -> :ok \| {:error, {:surface_digest_mismatch, claimed, actual}}` | |

`%AshSurface.Surface{}` fields: `manifest`, `contract`, `digest`, `action_ids`.

Typed profile refusals from `from_manifest/2`: `:profile_must_be_a_map`,
`{:profile_key_not_serializable, k}`, `{:profile_value_not_serializable, v}`,
`:profile_actions_must_be_a_map`, `{:unknown_action_profile, ids}`,
`{:action_profile_must_be_a_map, id, v}`, `{:evidence_required_must_be_boolean, id, v}`,
`{:possible_refusals_must_be_strings, id, v}`,
`{:possible_refusal_not_a_refusal_code, id, code}` (all in `lib/ash_surface.ex`).

## Projector contract: `AshSurface.Projector.IR` (`lib/ash_surface/projector/ir.ex`)

- `@callback project_ir(irs :: input(), opts) :: {:ok, artifacts, meta} | {:error, reason}`
- `from_surface/1` — builds the `ash_surface.surface` IR node from a verified surface
- `to_surface/1` — recovers the surface from IR, re-verifying the digest at the boundary
- `project/3` — dispatches to a projector over IR

IR node shape: `%{kind: "ash_surface.surface", ash: %{manifest, contract, digest, action_ids}}`
(`lib/ash_surface/projector/ir.ex`).

## Projectors

All declare `@behaviour AshSurface.Projector.IR` and implement `project_ir/2`.

| Module | File | Input | Output |
|---|---|---|---|
| `AshSurface.Projectors.JS` | `lib/ash_surface/projectors/js.ex` | `%AshSurface.IR{}`(s) | one `.mjs` (default prefix `ash_surface_client`); JSDoc + embedded Zod; fail-closed admission: `{:not_an_ir, ...}`, `{:unsafe_js_namespace, ...}`, `{:unsafe_js_member, ...}`, `{:js_namespace_collision, ...}`, `{:duplicate_js_member, ...}`, `{:js_binding_collision, ...}`, `{:invalid_prefix, ...}`, `{:unadmitted_field, ...}`, `{:unadmitted_zod, ...}` |
| `AshSurface.Projectors.LiveView` | `lib/ash_surface/projectors/live_view.ex` | `%AshSurface.IR{}` list | navigation/table/form/relationship structure maps; no Phoenix dependency; controls are intent references, never direct calls |
| `AshSurface.Projectors.ARIA` | `lib/ash_surface/projectors/aria.ex` | `%AshSurface.IR{}`(s) | ARIA contract map (semantics, never markup); optional `.json` emission; live regions OBSERVE-only; byte-deterministic ordering |
| `AshSurface.Projector.Expo` | `lib/ash_surface/projector/expo.ex` | `ash_surface.surface` IR | six artifacts: `schemas.mjs`, `actions.mjs`, `events.mjs`, `receipts.mjs`, client `.mjs`, `tanstack.mjs` (default prefix `zoela_surface`) |
| `AshSurface.Projector.VoiceKiosk` | `lib/ash_surface/projector/voice_kiosk.ex` | `ash_surface.surface` IR | one `{prefix}.voice.json`; authority-required actions phrased as confirmations |

## Module map (all paths under `lib/ash_surface/`)

- `ir.ex` — canonical five-section `%AshSurface.IR{}` struct: `:ash`,
  `:semantic`, `:capability`, `:presentation`, `:schema`; `new/1`,
  `sections/0`, `delegated/2`. Serialization + digest via
  `lib/ash_surface/ir/codec.ex` (`to_map/1`, `from_map/1`, `validate_facts/1`,
  `digest/1`).
- `compiler.ex` — `AshSurface.Compiler.compile/1,2`: admitted source
  (`%Ash.Info.Manifest{}` or `Ash.Domain` module) -> `[%AshSurface.IR{}]` via
  DiscoverOnce -> Normalize -> section builders -> assembly
  (`AshSurface.Compiler.Section` behaviour).
- `intent.ex` — `AshSurface.Intent.create/4` — content-addressed
  SurfaceIntent edge (no execution path).
- `intent/dispatch.ex` — `AshSurface.Intent.CommandBus` behaviour,
  `Envelope` struct, `Dispatch.submit/3`.
- `transport.ex` — pure pre-dispatch transport selection; `Decision` struct
  with `dimensions` (`:undelegated | :declared`) and non-dominated `frontier`;
  no post-dispatch fallback.
- `idempotency.ex` — `ash_surface.idempotency/1` protocol: `validate_key/1`,
  `valid_key?/1`, `derive_key/2`, `request_digest/2`, `admit/3`,
  `reserve/3`, `complete/4` over a caller-supplied map ledger.
- `event.ex` — `AshSurface.Event.create/4` (subject_ref, sequence, event_type):
  content-addressed `event_id` (`"ev_" <> first 16 hex of state digest`),
  `authority_boundary: :OBSERVE`.
- `observation.ex` — `AshSurface.Observation.create/3` — read-only state
  snapshot, `authority_boundary: :OBSERVE`, standing runtime-validated via
  `AshSurface.Standing`.
- `planning_episode.ex` — `AshSurface.PlanningEpisode.create/2` — projects a
  planner solve (FOND/HDDL) with `authority_ceiling: :SELECT \| :CONSTRUCT`,
  never DO.
- `mx_episode.ex` — `AshSurface.MXEpisode.compose/1`, `validate/1`,
  `verify/1`, `verify_file/1` over the vendored verifier
  `priv/verifier/verify_closure_episode.py` (no skip path, no fail-open).
  Thirteen top-level mx-episode-schema fields; CalVer fields pinned to
  `v26.10.8`.
- `canonical_json.ex` — `AshSurface.CanonicalJSON.encode/1` — the one
  canonical-JSON law (string-keyed, key-sorted, order-preserving lists).
- `standing.ex` / `vocabulary.ex` — closed vocabularies: base standings
  `ALIVE, PARTIAL_ALIVE, BLOCKED, BUILD_BROKEN, UNSUPPORTED`, open `REFUSED_`
  class (bare `REFUSED` not admitted; `UNKNOWN` is not a standing),
  transports `[:http, :phoenix_channel]`, dimensions
  `[:cost, :latency, :privacy]` with classes `[:low, :medium, :high]`,
  dispatch outcomes `SUCCESS | UNKNOWN_AFTER_DISPATCH`, digest hex length 64.
  Drift-tested against the JS `VOCABULARY` export.
- `a2a_bridge.ex` — `AshSurface.A2ABridge`: `agent_card_fragment/2`
  (`{:ok, %A2A.AgentCard{}} | {:error, :not_compiled}`) and `skills/1`
  (`{:ok, [AshA2A.Skill{}]} | {:error, :not_compiled}`); projects the
  resource's compiled `AshA2A` capability index, identity defaults
  overridable via opts; see
  [how-to/expose-a2a-agent-card.md](../how-to/expose-a2a-agent-card.md).
- `health.ex` — `check/0`, `check_surface/2`, `to_map/1`, `ready?/0`; OBSERVE-only.
- `telemetry.ex` — `events/0`, `transport_selected/1`, plus
  `[:ash_surface, :receipt, :refused]` and `[:ash_surface, :intent, :dispatch]`.
- `obligation.ex`, `section.ex`, `command_center.ex`,
  `castle_capability_intake.ex` — see module docs in those files.

## JavaScript runtime (`priv/static/ash_surface_runtime.mjs`)

- `SURFACE_RUNTIME_VERSION = "26.10.8"`; supported surface majors `[0, 26]`
- `createClient(options)` (line 321): stable `actions[id]`, `resources[resource][action]` namespaces, Zod boundary validation, adaptive transport selection before dispatch, receipts `SUCCESS | UNKNOWN_AFTER_DISPATCH`, reconcile statuses `COMPLETED | NOT_OBSERVED | STILL_UNKNOWN`, bounded dispatch (`timeoutMs`, `signal`)
- Frozen `VOCABULARY` export; `STANDING_VALUES`
- Idempotency helpers: `validateIdempotencyKey` (line 800),
  `deriveIdempotencyKey` (808), `computeRequestDigest` (819)

## MX episode verifier

`priv/verifier/verify_closure_episode.py` — `python3 verify_closure_episode.py <episode.json>`
exits 0 iff the episode is VALID; importable `verify_episode(data)`.
