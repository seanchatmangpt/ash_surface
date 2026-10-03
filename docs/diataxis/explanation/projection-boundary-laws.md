# Explanation: Why AshSurface Projects and Never Decides

Understanding mode: this is the reasoning behind the design, drawn from the
module docs themselves. All claims trace to the cited files.

## The boundary law

`ash_surface` starts from `Ash.Info.Manifest` and adds only projection
metadata under `custom.ash_surface`. It mints no resources, actions, or types;
it decides no authority; it never actuates. Existence and meaning come from
Ash; consequence requires the authority and receipts the capability laws
already demand. The core rule: **one Ash application model, many lawful
consumer projections** (`README.md`, `lib/ash_surface.ex` moduledoc).

## IR is a dumb carrier

`AshSurface.IR` (`lib/ash_surface/ir.ex`) is the canonical normalized
intersection every wave of the surface projects from — five sections
(`:ash`, `:semantic`, `:capability`, `:presentation`, `:schema`), one codec
(`lib/ash_surface/ir/codec.ex`). The invariant, wave-wide law, stated in the
moduledoc:

> IR determines NOTHING about existence, meaning, or DO-authority — it
> carries admitted facts from its five sources.

Reading a fact in the IR is not evidence it was verified this session, and no
field authorizes a DO. Consumers must re-derive standing from the sources;
the IR only transports what those sources admitted.

## Delegated facts, not re-derivations

`semanticId`, `authorityBoundary`, `doAuthority`, and `receiptRequired` are
delegated facts: each is read from the manifest's `custom.ash_surface` profile
metadata when a delegating authority stored it there, and is `nil` otherwise —
never defaulted, never re-derived (`lib/ash_surface/ir.ex`, `delegated/2`;
`lib/ash_surface.ex`, `surface_envelope/2`). The same "not delegated" reading
governs transport dimension facts (`lib/ash_surface/transport.ex`): an absent
cost/latency/privacy class is "not delegated", not a guessable default.

## Planning is not actuation

`AshSurface.Intent` (`lib/ash_surface/intent.ex`) records that a human aimed
a surface action at a subject with some input — nothing more. Creation and
inspection only; there is no `execute`/`submit`/`dispatch` path there.
Actuation requires an explicit cut: an operator-injected
`AshSurface.Intent.CommandBus` (behaviour in `lib/ash_surface/intent/dispatch.ex`)
that owns the authority cut, the actuation, and the receipt. The same
ceiling appears in `AshSurface.PlanningEpisode` (`authority_ceiling` is
strictly `SELECT` or `CONSTRUCT`, never DO) and in the JS projector, whose
descriptors carry dispatch-INTENT only — "there is no invoke/dispatch
execution path anywhere in the artifact"
(`lib/ash_surface/projectors/js.ex`).

## Transport law: selection before dispatch, no replay after

`AshSurface.Transport` (`lib/ash_surface/transport.ex`) is pure pre-dispatch
selection. Once dispatch begins, no automatic transport fallback: a timeout
or disconnect after dispatch is `UNKNOWN_AFTER_DISPATCH`, never silently
replayed. The only lawful retry path is the separately admitted
`ash_surface.idempotency/1` protocol
(`lib/ash_surface/idempotency.ex`), which requires the action's profile to
admit the protocol AND the call to carry an idempotency key, and fails closed
on digest conflicts.

## Standing vocabulary: refusals are outcomes, UNKNOWN is not a standing

`AshSurface.Standing` (`lib/ash_surface/standing.ex`) owns five base
standings — `ALIVE`, `PARTIAL_ALIVE`, `BLOCKED`, `BUILD_BROKEN`,
`UNSUPPORTED` — plus the open `REFUSED_*` class. Bare `:REFUSED` is not
admitted (an unnamed refusal is a fabricated refusal). `:UNKNOWN` is
deliberately not a standing: post-dispatch timeout/disconnect is
`UNKNOWN_AFTER_DISPATCH`, a transport outcome, and `validate!/1` refuses it.

Vocabulary is single-sourced in `AshSurface.Vocabulary`
(`lib/ash_surface/vocabulary.ex`) and drift-tested against the frozen
`VOCABULARY` export of the JS runtime (`priv/static/ash_surface_runtime.mjs`),
so a change on one side fails the build until the other side follows.

## Content addressing everywhere

Identity is content, never wall clock:

- `Surface.digest` — sha256 over the canonical term encoding
  (`AshSurface.contract_digest/1`), recomputed by anything receiving a
  surface from outside the constructor (`AshSurface.verify_surface_digest/1`).
- `Intent.intent_id` — sha256 over the canonical JSON of the ordered triple
  `[surface_action_id, input, subject_ref]`; `created_at` deliberately
  excluded — "time is not identity" (`lib/ash_surface/intent.ex`).
- `Event.event_id` — `"ev_"` + first 16 hex chars of the state digest over
  canonical JSON (`lib/ash_surface/event.ex`).
- `PlanningEpisode.episode_id` — `"ep_"` prefix of the canonical digest
  (`lib/ash_surface/planning_episode.ex`).
- One canonical-JSON law, `AshSurface.CanonicalJSON`
  (`lib/ash_surface/canonical_json.ex`), key-sorted so map construction
  history (flatmap vs HAMT) can never leak into a digest; the JS twin
  (`canonicalStringify`) must agree.

## Health and telemetry observe, never mutate

`AshSurface.Health` (`lib/ash_surface/health.ex`) performs real checks with
no hardcoded `:ok`, tags every report `authority_boundary: :OBSERVE`, and
never writes state. `AshSurface.Telemetry` (`lib/ash_surface/telemetry.ex`)
carries metadata only — never payload or input values — and is
fire-and-forget: an observer can never break a caller.

## Why a Python verifier ships in priv/

`priv/verifier/verify_closure_episode.py` is vendored in-repo so the
independent MX closed-loop replay check can never fail-open-skip on a missing
marketplace checkout: the verifier runs unconditionally, no skip path
(`priv/verifier/verify_closure_episode.py` header; `lib/ash_surface/mx_episode.ex`).

## Human boundary

`ash_surface` is to humans what the A2A wire protocol is to machines: a
projection/interaction boundary into the same admitted semantic system
(`README.md`, v26.9.16). Neither boundary mints existence, meaning, or
consequence — both project what Ash has already admitted.
