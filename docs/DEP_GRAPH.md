# DEP_GRAPH — the v26.9.16 dependency law

The law is versioned **v26.9.16** because its sharpest statements were codified in the
`ash_a2a` v26.9.16 wave (`/Users/sac/ash_a2a/mix.exs` lines 156–223: the `:rdf`,
`:wasmex`, `:libcluster`/`:horde` edges and their scope limits). This repo —
`ash_surface` 26.9.13 (`mix.exs:4`) — is the composition layer of that law. Every
claim below is grounded in a cited file; the two law-layer repos were read read-only.

## Ownership (who owns what, one concern per owner)

| Concern | Owner | Grounds |
|---|---|---|
| MEANING | `ash_r2rml` | "W3C R2RML and RDF semantic mapping compiler" (`/Users/sac/ash_r2rml/mix.exs:11`); owns the semantic stack `rdf`/`sparql`/`sparql_client`/`json_ld` (`ash_r2rml/mix.exs:129–132`) |
| CAPABILITY / AUTHORITY / CONSEQUENCE | `ash_a2a` | "exposes Ash actions as A2A agent skills, compiling a verified AgentCard and dispatching inbound A2A messages" (`/Users/sac/ash_a2a/mix.exs:38–40`) |
| Shared-discovery schema manufacture | the **AshTypescript pattern** (prior art, never a dependency) | `AGENTS.md:11` (#5), `README.md:29` |
| Human rendering | the **ash_admin pattern** (prior art, never a dependency) | same boundary class as AshSDUI/live_vue, `AGENTS.md:14` (#8) |
| Composition + human-interaction projection | `ash_surface` (this repo) | `AGENTS.md:9` (#3), `AGENTS.md:12` (#6) |

**MEANING — `ash_r2rml`.** What a resource *means* (its triples, IRIs, ontology
alignment) is compiled there and nowhere else. It is the only repo of the three
that owns an RDF stack (`/Users/sac/ash_r2rml/mix.exs:129–132`). Nothing else in
the law mints meaning.

**CAPABILITY/AUTHORITY/CONSEQUENCE — `ash_a2a`.** What an agent *can* do (verified
AgentCard), who may do it, and what actually happened. Its own dep comments state
the consequence law: adapters "never gain independent DO capability, only observed
provider evidence via RuntimeReceipt" (`/Users/sac/ash_a2a/mix.exs:111–113`) and
"queue acceptance is not an execution receipt; a state transition is not a DO"
(`/Users/sac/ash_a2a/mix.exs:121–123`). Even its `:wasmex` graphlaw host is
envelope-only: "Elixir's job at this boundary is envelope, standing, refusal
typing, authority, receipts and admission orchestration, never the derivation
itself" (`/Users/sac/ash_a2a/mix.exs:218–222`), and its `:rdf` edge is
"SERIALIZATION/PARSING ONLY … never for validation, reasoning, entailment, or
canonicalization" (`/Users/sac/ash_a2a/mix.exs:174–178`).

**Shared-discovery schema manufacture — the AshTypescript pattern.** One generated
schema artifact manufactured from Ash truth so external consumers discover
resources/actions without hand-written contracts. The *pattern* is owned; the
*package* is not admitted: AshTypescript "is not an authority, runtime dependency,
input manifest, or generated-artifact owner for `ash_surface`" (`AGENTS.md:11`,
`README.md:29`). `ash_surface` re-expresses the pattern manifest-first
(`Ash.Info.Manifest` + `custom.ash_surface`, `AGENTS.md:8`).

**Human rendering — the ash_admin pattern.** Read Ash resources/actions/policies
and render operator-facing UI from them. `ash_surface` may project descriptors
into such renderers "without absorbing their layout/rendering machinery"
(`AGENTS.md:14`); AshPhoenix remains authoritative for forms (`AGENTS.md:13`).

**Composition + human-interaction projection — `ash_surface`, and only that.**
`Ash -> Manifest -> AshSurface -> {JavaScript, Phoenix, Vue, Expo, ...}`
(`AGENTS.md:9`). It owns `createClient`, stable namespaces, projection metadata,
pre-dispatch transport selection, boundary validation, sync hooks
(`AGENTS.md:12`).

## Edge directions

```text
            MEANING                      CAPABILITY / AUTHORITY / CONSEQUENCE
        ┌─────────────┐                          ┌─────────────┐
 Ash ──▶│ ash_r2rml   │◀─── depends on (only ───│  ash_a2a    │──▶ AgentCard / skills / receipts
 truth  │ 26.9.12     │    legal law-layer edge)│ 26.9.14     │    (:a2a, :oban, :flame, :wasmex …)
        └─────────────┘   ash_a2a mix.exs:97    └─────────────┘
              │                                        │ consumes meaning, never defines it
              ▼                                        │
        Ash.Info.Manifest + custom.ash_surface ◀────────┘
              │
              ▼
        ┌─────────────┐     π_JS (mjs + JSDoc + Zod)
        │ ash_surface │ ──▶ π_Phoenix / π_Vue / π_Expo … (projection of AshSurface, AGENTS.md:9)
        └─────────────┘
```

Current, real edges (read from the three `mix.exs` files):

- **Ash → all three.** `ash ~> 3.33.1` (`mix.exs:44`), `ash_r2rml ~> 3.0 and >= 3.28.0`
  (`/Users/sac/ash_r2rml/mix.exs:120`), `ash_a2a ~> 3.0` (`/Users/sac/ash_a2a/mix.exs:65`).
  `ash_surface`'s floor already sits above both law layers', so a consumer
  composing all three resolves one Ash.
- **ash_a2a → ash_r2rml.** `{:ash_r2rml, "~> 26.8"}` (`/Users/sac/ash_a2a/mix.exs:97`) —
  the only legal edge between the two law layers. Direction: capability *consumes*
  meaning.
- **ash_a2a → rdf / wasmex** (v26.9.16): parser and wasm-host edges only, never
  derivation (`/Users/sac/ash_a2a/mix.exs:174–223`).
- **Manifest → ash_surface → projections.** `AGENTS.md:8–9`.
- **AshTypescript ↛ ash_surface** and **ash_admin ↛ ash_surface**: no edge, ever —
  pattern references only (`README.md:29`, `AGENTS.md:11,14`).

## What never flows backward

- **`ash_surface` never determines EXISTENCE.** "Ash resources/actions/policies
  remain authoritative" (`AGENTS.md:7`); "a target projection is a projection of
  AshSurface, not the source of AshSurface" (`AGENTS.md:9`). No resource, action,
  or policy is born here.
- **`ash_surface` never determines MEANING.** "Do not add RDF/SHACL/BRCE/AsyncAPI/
  TanStack/Vue/Expo logic to core unless a concrete projection requires it"
  (`AGENTS.md:46`). Meaning lives in `ash_r2rml`; the surface would consume its
  output, never emit it.
- **`ash_surface` never determines DO.** "Transport is a projection facet, never
  action identity" (`AGENTS.md:35`); post-dispatch failure is
  `UNKNOWN_AFTER_DISPATCH` with no silent replay, and post-dispatch retry needs a
  separately admitted idempotency/consequence protocol (`AGENTS.md:39–40`).
  Authority and consequence stay in `ash_a2a`.
- **`ash_r2rml` never learns about agents.** No `ash_a2a` dependency exists in
  `/Users/sac/ash_r2rml/mix.exs:118–148`; meaning must not import capability.
- **Renderers never own semantics.** AshSDUI/live_vue (and the ash_admin pattern)
  keep their own machinery; `ash_surface` hands them descriptors only
  (`AGENTS.md:14`).

## Current vs target dependency list (`ash_surface`)

Current — `mix.exs:43–48` (v26.9.13):

| dep | constraint | role |
|---|---|---|
| `ash` | `~> 3.33.1` | upstream truth |
| `spark` | `~> 2.7` | DSL/extension substrate |
| `jason` | `~> 1.4` | JSON |
| `igniter` | `~> 0.7`, dev/test only | code generation |

Target — **unchanged: the same four, nothing added.** The law is enforced by what
is absent:

- never `ash_r2rml` (meaning stays upstream; the surface reads manifests, not the
  semantic compiler),
- never `ash_a2a`, `:wasmex`, `:oban`, `:flame` (authority/consequence never reach
  the surface),
- never AshTypescript (prior art only, `README.md:29`),
- never ash_admin (rendering pattern only),
- never a TypeScript toolchain (JavaScript law, `AGENTS.md:10,17–31`).

The JS runtime cost (Zod) is a consumer-side requirement of emitted artifacts, not
a Mix dependency of this repo (`README.md:175`).
