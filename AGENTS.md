# ash_surface doctrine

`ash_surface` is a projection layer, not a second application model.

## Canonical boundaries

1. **Ash resources/actions/policies remain authoritative.** Do not duplicate their semantics in a local resource/action/type schema.
2. **`Ash.Info.Manifest` is the normalized Elixir/cross-language boundary.** New projectors consume the manifest or a public downstream manifest derived from it.
3. **Extension metadata belongs under `custom.ash_surface`.** It must be data, not functions/PIDs/ambient behavior.
4. **AshTypescript remains authoritative for its generated RPC/types/Zod/Valibot/channel variants.** The JS runtime consumes its public versioned JSON manifest; it must not crawl AshTypescript internals.
5. **AshPhoenix remains authoritative for Phoenix forms/LiveView integration.** `ash_surface` does not reimplement `AshPhoenix.Form` or LiveView generators.
6. **AshSDUI remains the server-driven LiveView layout/runtime layer.** `ash_surface` does not own layout trees, widgets, view/binding/state/context semantics.
7. **live_vue remains the Vue↔LiveView bridge.** `ash_surface` does not own Vue rendering, LiveView hooks, navigation, uploads, or SSR.
8. **Server-state caches belong to consumer libraries such as TanStack Query.** Projectors may manufacture adapters/descriptors; the core does not become a cache.

## Transport law

Transport is a projection facet, never action identity. Preserve all admitted alternatives until selection.

- Selection happens **before dispatch**.
- A missing preferred transport may fall back to another admitted transport before dispatch.
- After dispatch, timeout/disconnect is `UNKNOWN_AFTER_DISPATCH`; do not silently replay the action over another transport.
- Post-dispatch retry requires a separately admitted idempotency/consequence protocol and is outside v0.

## Implementation order

Reuse → compose → extend → invent.

Prefer public framework APIs and generators. Do not edit generated artifacts by hand. Do not add RDF/SHACL/BRCE/AsyncAPI/TanStack/Vue/Expo logic to core unless a concrete projector requires it.

## Verification

Cheapest high-information gate first:

1. Node runtime tests for the cross-language adapter.
2. `mix format --check-formatted`.
3. `mix compile --warnings-as-errors`.
4. `mix test`.
5. Exact consumer/e2e tests when a projector is promoted.

Never call rendered/compiled code ALIVE without an exact consumer execution receipt.
