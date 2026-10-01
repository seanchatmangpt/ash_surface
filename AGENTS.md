# Engineering Standards Root Binding

> Generated adoption header. Shared engineering semantics are rooted at `seanchatmangpt/engineering-standards@5a3bb6446aeaee2255a7523d4d8cebf6042960c3`.

- Repository subject: `seanchatmangpt/ash_surface@7d5492795d9b9a0956f51545ed1ad1932768b77e`
- Ecosystem role: human command-surface and interaction projection
- Adoption manifest: `engineering-standards.json`
- Project profile: `semantic/engineering-standards-profile.ttl`

The local constitution below remains authoritative for repository-specific mechanics. It may narrow the root but may not redefine shared WorkOrder identity, authority, receipt/replay, generated-artifact sovereignty, or evidence standing. Ticket, agent, capability, plan, proof, and generated output do not acquire ambient DO authority.

---

# ash_surface doctrine

`ash_surface` is a generalized consumer projection/runtime layer over Ash semantics. It is not AshTypescript and it does not require TypeScript.

## Canonical boundaries

1. **Ash resources/actions/policies remain authoritative.** Do not duplicate their semantics in a second application model.
2. **`Ash.Info.Manifest` is the normalized upstream boundary.** `ash_surface` consumes Ash semantics directly from the manifest plus `custom.ash_surface` projection metadata.
3. **AshSurface generalizes consumer projection.** The intended shape is `Ash -> Manifest -> AshSurface -> {JavaScript, Phoenix, Vue, Expo, ...}`. A target projection is a projection of AshSurface, not the source of AshSurface.
4. **JavaScript is first-class and TypeScript-free.** The JavaScript projection emits ordinary `.mjs`; editor/static typing is JSDoc; runtime boundary typing/validation is Zod. Do not emit `.ts` or `.d.ts`, require `tsc`, or introduce TypeScript as a supported contract.
5. **AshTypescript is prior art only.** It may inform projection ergonomics, but it is not an authority, runtime dependency, input manifest, or generated-artifact owner for `ash_surface`.
6. **Application-facing runtime semantics belong here.** `createClient`, stable resource/action namespaces, projection metadata, adaptive pre-dispatch transport selection, boundary validation, and synchronization/projection hooks must preserve Ash action identity and consequence semantics.
7. **AshPhoenix remains authoritative for Phoenix forms/LiveView integration.** Do not reimplement `AshPhoenix.Form` or its generators.
8. **AshSDUI and live_vue remain their own rendering/runtime owners.** AshSurface may project descriptors into them without absorbing their layout/rendering machinery.
9. **Server-state caches belong to consumer libraries.** AshSurface may generate adapters/descriptors; core does not become a cache.

## JavaScript law

The JavaScript projection is:

```text
π_JS(AshSurface) = JavaScript + JSDoc + Zod
```

Never:

```text
π_JS(AshSurface) = TypeScript
```

Generated JavaScript must remain directly executable by Node/browser runtimes without a TypeScript build step.

## Transport law

Transport is a projection facet, never action identity. Preserve all admitted alternatives until selection.

- Selection happens **before dispatch**.
- A missing preferred transport may fall back to another admitted transport before dispatch.
- After dispatch, timeout/disconnect is `UNKNOWN_AFTER_DISPATCH`; do not silently replay the action over another transport.
- Post-dispatch retry requires a separately admitted idempotency/consequence protocol.

## Implementation order

Reuse -> compose -> extend -> invent.

Prefer public Ash APIs and the Ash extension ggen pack. Generated extension artifacts are pack-owned. Do not hand-edit them. Do not add RDF/SHACL/BRCE/AsyncAPI/TanStack/Vue/Expo logic to core unless a concrete projection requires it.

## Verification

Cheapest high-information gate first:

1. Zod/JSDoc JavaScript runtime tests against the AshSurface contract.
2. `node --check` on emitted `.mjs`.
3. `mix format --check-formatted`.
4. `mix compile --warnings-as-errors`.
5. `mix test`.
6. Exact consumer/e2e tests when a projection is promoted.

Never call generated or rendered code ALIVE without an exact consumer execution receipt.
