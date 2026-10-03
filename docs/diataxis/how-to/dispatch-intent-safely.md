# How To: Record a Human Intent and Dispatch It Without Replaying a Consequence

Goal mode: you have a verified surface and need to get a human's aim to a
server-side actuation path without ever replaying a consequential action.
Everything below was verified against `lib/ash_surface/intent.ex`,
`lib/ash_surface/intent/dispatch.ex`, and `lib/ash_surface/idempotency.ex`.

## Prerequisites

- A verified `%AshSurface.Surface{}` (see the manifest-to-surface tutorial)
- An actuation boundary implementing the `AshSurface.Intent.CommandBus`
  behaviour (`lib/ash_surface/intent/dispatch.ex`)

## 1. Record the intent (never actuates)

`AshSurface.Intent.create/4` records that a human aimed a surface action at a
subject with some input — and nothing more. There is no
`execute`/`submit`/`dispatch` path in `lib/ash_surface.intent` (`lib/ash_surface/intent.ex`).

```elixir
intent = AshSurface.Intent.create("MyApp.Post#read", %{"id" => 1}, "ir:abc123")
intent.intent_id  # sha256 over the canonical JSON of [action_id, input, subject_ref]
```

Time is not identity: a different `:created_at` replays the same id
(doctest, `lib/ash_surface/intent.ex`).

## 2. Inject a command bus and dispatch

Actuation happens only on the far side of an injected `CommandBus`. The bus
owns the authority cut, the actuation, and the receipt;
`ash_surface` owns only the manufacture of the intent handed over
(`AshSurface.Intent.CommandBus` moduledoc, `lib/ash_surface/intent/dispatch.ex`).

```elixir
defmodule MyApp.CommandBus do
  @behaviour AshSurface.Intent.CommandBus

  @impl true
  def submit(%AshSurface.Intent.Envelope{} = envelope, context) do
    # your actuation + receipt minting
    {:ok, receipt_ref}
  end
end
```

Submit an admitted candidate map through the bus
(`AshSurface.Intent.Dispatch.submit/3`, `lib/ash_surface/intent/dispatch.ex:87`):

```elixir
case AshSurface.Intent.Dispatch.submit(candidate_map, MyApp.CommandBus, %{request_id: id}) do
  {:ok, receipt_ref} -> ...
  {:error, reason} -> ...   # e.g. {:error, :REFUSED_NO_AUTHORITY}
end
```

Outcomes per `AshSurface.Telemetry` (`lib/ash_surface/telemetry.ex`):
`:submitted`, `:bus_error`, or `{:refused, class}` with class one of
`:invalid_candidate`, `:unknown_action`, `:invalid_context`,
`:no_command_bus`.

## 3. Make a post-dispatch retry lawful with idempotency

Transport law: after dispatch, a timeout or disconnect is
`UNKNOWN_AFTER_DISPATCH` and the action is never silently replayed. A retry
is legal only when the action's contract profile admits the
`ash_surface.idempotency/1` protocol AND the call carried an idempotency key
(`AshSurface.Idempotency` moduledoc, `lib/ash_surface/idempotency.ex`;
`docs/IDEMPOTENCY.md`).

Server-side, over a caller-supplied plain-map ledger:

```elixir
```elixir
{:ok, digest} = AshSurface.Idempotency.request_digest("MyApp.Post#read", %{"id" => 1})
key = AshSurface.Idempotency.derive_key("MyApp.Post#read", command_id)

:ok = AshSurface.Idempotency.validate_key(key)
:first = AshSurface.Idempotency.admit(key, digest, state)  # pure: state unchanged
{:ok, state1} = AshSurface.Idempotency.reserve(key, digest, state)
# ... actuate ...
{:ok, state2} = AshSurface.Idempotency.complete(key, digest, {:done, result}, state1)
# A retry: admit/3 now returns {:replay, result}
```

- `validate_key/1` — 8..128 chars of `[A-Za-z0-9_.:-]`, starting alphanumeric
- `derive_key/2` — `"ik_" <> sha256(canonical(%{"actionId", "commandId"}))`
- `request_digest/2` — sha256 of `canonical(%{"actionId" => id, "input" => input})`;
  floats and other non-JSON-portable terms are refused
- `admit/3` — `:first`, `{:replay, recorded_outcome}`, or
  `{:conflict, :digest_mismatch | :in_flight}` (fail closed)
- `reserve/3` / `complete/4` — mark in-flight / record the outcome

Persistence, expiry, and concurrency of the ledger are the caller's
(`lib/ash_surface/idempotency.ex`). The JS twin is `retryUnknown` in
`priv/static/ash_surface_runtime.mjs` (plus `validateIdempotencyKey`,
`deriveIdempotencyKey`, `computeRequestDigest` exported at lines 800/808/819).

## 4. Observe the dispatch

`AshSurface.Telemetry` emits `[:ash_surface, :intent, :dispatch]` with
`action_id` and `outcome` metadata, never payload values
(`lib/ash_surface/telemetry.ex`). Other events:
`[:ash_surface, :transport, :select]` and `[:ash_surface, :receipt, :refused]`.

```elixir
:ok = :telemetry.attach("my-handler", [:ash_surface, :intent, :dispatch], fn _e, _m, meta, _ -> ... end, nil)
```

## 5. Check readiness

`AshSurface.Health.check/0` returns `{:ok, report} | {:error, report}` with
real runtime checks — no hardcoded `:ok`
(`lib/ash_surface/health.ex`). `AshSurface.Health.check_surface/2` assesses
an exact surface with the three-valued taxonomy `:healthy`,
`:missing_runtime`, `:digest_drift`; it is deterministic and OBSERVE-only.

## Troubleshooting

- `{:error, {:unsupported_projector, mod}}` — the projector has no
  `project_ir/2` (`lib/ash_surface.ex`, `project/3`).
- `{:error, :no_command_bus}` — `Dispatch.submit/3` received `nil` or a
  module without the behaviour (`lib/ash_surface/intent/dispatch.ex`).
- `{:conflict, :digest_mismatch}` — same key, different request payload;
  always a conflict, never a replay (`lib/ash_surface/idempotency.ex`).
