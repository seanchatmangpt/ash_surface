# ash_surface.idempotency/1

The transport law says a timeout or disconnect after dispatch is
`UNKNOWN_AFTER_DISPATCH` and the action is never silently replayed. A retry is
legal only under a **separately admitted idempotency/consequence protocol**.
This document is that protocol. It is opt-in, explicit and fail-closed: an
action that does not admit it can never be retried after dispatch.

Implementations: `priv/static/ash_surface_runtime.mjs` (client side) and
`lib/ash_surface/idempotency.ex` (server-side key law, digest, pure ledger).
Cross-language parity vectors: `test/js/fixtures/idempotency_vectors.json`,
asserted by `test/js/idempotency_parity.test.mjs` and
`test/ash_surface/idempotency_test.exs`.

## Admission (contract profile)

```json
{ "profile": { "idempotency": { "protocol": "ash_surface.idempotency/1", "crossTransport": false, "keyHeader": "Idempotency-Key" } } }
```

| field | meaning |
| --- | --- |
| `protocol` | must be exactly `ash_surface.idempotency/1` |
| `crossTransport` | default `false`. When `true`, a replay may be re-selected among admitted transports (pre-dispatch). Otherwise it is pinned to the transport that dispatched originally |
| `keyHeader` | optional hint handed to the adapter (`context.idempotency.keyHeader`); the adapter puts the key on the wire |

The profile is strict: an unknown field or wrong protocol is
`INVALID_IDEMPOTENCY_PROFILE` before dispatch (never silently ignored).

## Key law

8..128 characters of `[A-Za-z0-9_.:-]`, first character alphanumeric
(`validateIdempotencyKey`, `AshSurface.Idempotency.validate_key/1`). Absent a
caller key (`invoke(input, {idempotencyKey})`) the runtime derives
`"ik_" + sha256hex(canonical({actionId, commandId}))` so the same command
always re-derives the same key. An invalid key is `INVALID_IDEMPOTENCY_KEY`; a
key supplied for an action that does not admit the protocol is
`IDEMPOTENCY_NOT_ADMITTED` (both pre-dispatch, nothing sent).

## Request digest

`sha256hex(canonical({actionId, input}))` over the Zod-admitted input, using the
`AshSurface.CanonicalJSON` law (key-sorted by code point, order-preserving
lists, Jason string escapes). Portable subset only: strings, safe integers,
booleans, null, arrays, plain objects. Floats, unsafe integers, `undefined`
members, lone surrogates and non-plain objects are refused
(`IDEMPOTENCY_INPUT_NOT_PORTABLE` / `{:error, reason}`) because their JSON
spelling is not language-portable. `undefined` input digests as `null`.

## Receipt binding

Every dispatch of an admitting action carries
`receipt.idempotency = {protocol, key, requestDigest, crossTransport, dispatchedTransport, attempt}`
and the adapter receives `context.idempotency = {protocol, key, keyHeader, requestDigest, attempt}`.
Receipts of non-admitting actions have no `idempotency` member.

## Explicit retry

```js
const error = await client.actions[id].invoke(input).catch((e) => e); // TRANSPORT_OUTCOME_UNKNOWN
const outcome = await client.retryUnknown(error /* or error.receipt */, { input });
```

`retryUnknown` is a new explicit call; nothing in the runtime ever retries on
its own. Receipts never carry input values, so the caller supplies `input`;
its digest must equal the receipt's `requestDigest` (`IDEMPOTENCY_DIGEST_MISMATCH`).
`commandId` and `idempotencyKey` cannot be overridden (`INVALID_OPTIONS`); the
retry reuses the receipt's. Order:

1. Admit the receipt (untrusted): must be `unknown_after_dispatch`, name an
   action whose profile admits the protocol, and carry a valid binding.
   Refusals: `RETRY_REQUIRES_RECEIPT` (bare id), `RETRY_NOT_UNKNOWN`,
   `UNKNOWN_ACTION`, `IDEMPOTENCY_NOT_ADMITTED`, `RETRY_RECEIPT_INVALID`.
2. Unless `crossTransport`, the original transport must still be available
   (`RETRY_TRANSPORT_UNAVAILABLE`, pre-dispatch).
3. `reconcile(commandId)` on the ORIGINAL transport.
4. `COMPLETED` -> `{status: "COMPLETED", replayed: false, reconcile}`;
   `STILL_UNKNOWN` (including an adapter without `reconcile`) ->
   `{status: "STILL_UNKNOWN", replayed: false, reconcile}`. Neither replays.
5. `NOT_OBSERVED` -> replay with the same `commandId` and key, on the same
   transport (or re-selected when `crossTransport`), attempt + 1 ->
   `{status: "REPLAYED", replayed: true, result, receipt}`. A replay that fails
   again throws `TRANSPORT_OUTCOME_UNKNOWN` with an `attempt + 1` receipt that
   can be retried again, still only on explicit call.

## Server side

The server must honour the key: `AshSurface.Idempotency.admit(key, digest, state)`
over a caller-supplied map returns `:first`, `{:replay, recorded_outcome}`, or
`{:conflict, :digest_mismatch | :in_flight}`; `reserve/3` and `complete/4`
transition the map purely. Storage, expiry and locking belong to the caller;
this module has no processes or ETS. A key reused with a different request
digest is always a conflict.

## Observability

`createClient({onEvent})` receives payload-free events (ids, codes, transports,
durations): `transport.selected`, `dispatch.started`, `dispatch.completed`,
`dispatch.unknown_after_dispatch {cause}`, `dispatch.refused_pre_dispatch {code}`,
`reconcile.result`, `reconcile.invalid_result`, `retry.requested`,
`retry.skipped {reason}`, `retry.replaying`, `retry.refused {code}`. The hook is
synchronous and exception-safe. Pinned by `test/js/observability_events.test.mjs`.
