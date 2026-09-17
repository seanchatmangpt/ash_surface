# ARCHITECTURE — ash_surface v26.9.16 (the Semantic Surface Compiler)

`ash_surface` is a generalized consumer projection/runtime layer over Ash semantics
(`AGENTS.md`). v26.9.16 names the wave that made the IR canonical, delegated the four
authority facts, and fixed the edge-ownership table. This document is the architecture
as text-art; every element cites its canonical module path. Provenance of in-flight
pieces is in §7.

## 1. The whole architecture as text-art

```text
        +============================ ASH (authoritative) ============================+
        |  resources . actions . policies . types                                     |
        |  THE single normalized upstream boundary: Ash.Info.Manifest                 |
        +------------------------------------+----------------------------------------+
                                             | admitted source
                                             | (Manifest | Ash.Domain module)
                                             v
              +----------------- SEMANTIC SURFACE COMPILER -----------------+
              |  AshSurface.Compiler            lib/ash_surface/compiler.ex |
              |                                                               |
              |    DiscoverOnce ---> Normalize ---> section builders ---> IR |
              |      (one pass,      (plain action    (ash semantic       (as-
              |       one receipt     map, keyed       capability pre-     sembly,
              |       token per       Resource#action  sentation schema    sorted,
              |       compile)        id)              once/action)        digest)   |
              +------------------------------------+------------------------+
                                                   | one %AshSurface.IR{} per public action
                                                   v
                          +===================== SURFACE IR =====================+
                          |  AshSurface.IR            lib/ash_surface/ir.ex        |
                          |  five sections (see table in section 3) + version     |
                          |  + content-addressed digest                             |
                          |  codec: AshSurface.IR.Codec   lib/ash_surface/ir/codec.ex
                          +----+----------+----------+----------+----------+------+
                               |          |          |          |          |
                pi_LiveView ---+          |          |          |          +--- pi_voice
                (server-render;           |          |          |              (speech I/O
                 AshPhoenix                |          |          |               projection)
                 authoritative)            |          |          |
                                     pi_JS ----------+          +--- pi_ARIA
                                     (.mjs + JSDoc + Zod;          (accessibility as
                                      TypeScript-free law)          data, Schema.aria)
                               |          |          |          |          |
                               +----------+----------+--+-------+----------+
                                                   |
                                              landed reference projector:
                                              AshSurface.Projector.Expo
                                              lib/ash_surface/projector/expo.ex
                                                   |
                                                   v
   +############################## HUMAN (the only DO-authority source) #############################+
   |   surfaces render. they NEVER actuate. a projector that dispatches is a contract violation.        |
   +------------------------------------+----------------------------------------------------------------+
                                        | act / select / utter
                                        v
                                SURFACE INTENT
                     (semanticId-keyed intent; never a second app model)
                                        |
                                        v
                                   CANDIDATE
                 AshSurface.PlanningEpisode   lib/ash_surface/planning_episode.ex
                 candidate_actions; authority_ceiling in {SELECT, CONSTRUCT}
                 ============================ NEVER DO =================================
                                        |
                                        v
                        ADMISSION / AUTHORITY
             runtime: priv/static/ash_surface_runtime.mjs
             Zod input parse (typed INPUT_VALIDATION_FAILED) then
             doAuthority / authorityBoundary gate; capability law is
             delegated truth read from the IR (nil = not delegated).
                                        |
                                        v
                                   COMMAND BUS
             commandId mint + transport selection PRE-DISPATCH only
             (declared -> available -> frontier -> selected; delegated
             cost/latency/privacy class facts ride the action profile and
             weigh the admitted alternatives, nil = not delegated ->
             preference law; AshSurface.Transport
             lib/ash_surface/transport.ex); idempotent replay by commandId.
                                        |
                                        v
              +--------------------------------- DO ---------------------------------+
              |  adapter.invoke  --  THE ONLY CONSEQUENTIAL CUT. one dispatch,    |
              |  no silent cross-transport retry. timeout/disconnect after this   |
              |  point is UNKNOWN_AFTER_DISPATCH.                                  |
              +------------------------------------+--------------------------------+
                                                   | receipt-bearing return
                                                   v
                                    RECEIPT
             buildMXReceipt/5 provenance lattice: transportReceipt +
             domainReceiptRef + consequenceReceipt + outcome
             (SUCCESS | UNKNOWN_AFTER_DISPATCH), frozen.
                                                   |
                                                   v
                                 SURFACE EVENT
             AshSurface.Event   lib/ash_surface/event.ex
             authority_boundary: :OBSERVE, receipt_ref carried, sequenced
             server -> client observation stream (AshSurface.Observation).
                                                   |
                                                   +-----------------> observed state feeds
                                                                       the next projection cycle
```

## 2. Stage law (one line each, with the canonical path)

| Stage | Law | Canonical path |
|---|---|---|
| Ash | authoritative; no second application model | upstream `Ash.Info.Manifest` |
| Compiler | DiscoverOnce, Normalize, sections, assembly; fails closed on missing sections | `lib/ash_surface/compiler.ex` |
| SurfaceIR | dumb carrier; "IR determines NOTHING about existence, meaning, or DO-authority" | `lib/ash_surface/ir.ex` |
| IR codec | JSON-isomorphic serialization + content addressing | `lib/ash_surface/ir/codec.ex` |
| Projectors | receive verified `AshSurface.Surface`; never rediscover Spark internals | `lib/ash_surface.ex` (`AshSurface.Projector` behaviour) |
| Expo (reference) | manufactures schemas/actions/events/receipts/client `.mjs` | `lib/ash_surface/projector/expo.ex` |
| JS runtime | `pi_JS = JavaScript + JSDoc + Zod`, never TypeScript; transport is a facet, not identity; selection weighs delegated cost/latency/privacy facts and exposes the non-dominated frontier (twin of `AshSurface.Transport`) | `priv/static/ash_surface_runtime.mjs` |
| Observation | OBSERVE-only, zero DO authority | `lib/ash_surface/observation.ex` |
| Planning | `AshSurface != Planner`; ceiling SELECT/CONSTRUCT | `lib/ash_surface/planning_episode.ex` |
| Event | OBSERVE-boundary stream of receipts and state | `lib/ash_surface/event.ex` |
| Health | standing reports, OBSERVE-tagged | `lib/ash_surface/health.ex` |
| Validation | profile verified against exact public action set | `lib/ash_surface/resource/validator.ex` |

## 3. The SurfaceIR five-section field table

`%AshSurface.IR{}` — `lib/ash_surface/ir.ex` (five-section form landed with the wave;
`@ir_version "26.9.16"` in `lib/ash_surface/compiler.ex`). Every field is owned by
exactly one section builder implementing `AshSurface.Compiler.Section`. The default
`compile/1` bindings are the five `AshSurface.Compiler.Section.*` adapters
(`lib/ash_surface/compiler/section/*.ex`, gapfix-adapters-001), each bridging the
real edge-owner builder and carrying its projection verbatim into the mounted
`AshSurface.IR.*` slice: `Section.Ash` -> `Compiler.AshTruth` (the ONE canon for
`:ash`; the `IR.Ash`-@type-violating rival `Compiler.Ash` is retired),
`Section.Semantic` -> `Compiler.Semantic`, `Section.Capability` ->
`Compiler.Capability` (conformed to the canonical build/2), `Section.Presentation`
-> `Compiler.Presentation`, `Section.Schema` -> `Compiler.Schema`.

| Section | Struct | Fields | Truth source (edge owner) |
|---|---|---|---|
| `:ash` | `IR.Ash` | `resource`, `action`, `action_type`, `inputs`, `outputs`, `policies` | Ash manifest (re-states, never re-decides) |
| `:semantic` | `IR.Semantic` | `subject_iri`, `capability_iri`, `predicates`, `shape_id`, `ontology` | meaning edge (r2rml) |
| `:capability` | `IR.Capability` | `capability_id`, `consequence_class`, `authority_required`, `receipt_required` | capability edge (a2a) |
| `:presentation` | `IR.Presentation` | `label`, `group`, `order`, `widget`, `format` | rendering edge (admin-pattern); the ONLY metadata ash_surface owns |
| `:schema` | `IR.Schema` | `input`, `output`, `zod`, `aria` | schema edge (shared-discovery); `aria` from `lib/ash_surface/compiler/aria.ex` |

Plus two envelope fields: `version` (IR version string) and `digest`
(`canonical_term -> term_to_binary -> SHA-256 -> lower hex` over the normalized
action map — stable across map insertion order).

## 4. The edge-ownership table

AshSurface owns exactly one edge: composition. Everything else is delegated truth
read at the edge, never re-derived locally.

| Edge | Owner | What it owns |
|---|---|---|
| meaning | r2rml (`ash-r2rml-paas-pack`, ggen-marketplace) | subject/predicate IRI mappings, shape ids, ontology bindings (`IR.Semantic`) |
| capability | a2a (`ash_a2a`; `AshA2A.Skill`, `AshA2A.CapabilityIndex.Compiler`, `AshA2A.CommandBus` admission law) | consequence class, `authority_required`, `receipt_required` (`IR.Capability`) |
| schema | shared-discovery | boundary input/output shape discovery; the Zod projection base (`IR.Schema.input/output`) |
| rendering | admin-pattern (ash_admin-style presentation overrides) | label/group/order/widget/format (`IR.Presentation`) |
| composition | surface (`ash_surface`, this repo) | how the five sections compose into per-target consumer projections |

Section builders are pure projections of their edge owner's truth:
`lib/ash_surface/compiler/capability.ex` projects `ash_a2a` capability truth verbatim;
`lib/ash_surface/compiler/presentation.ex` declares the five admin-pattern overrides
as "the only metadata ash_surface owns"; `lib/ash_surface/compiler/aria.ex` puts
accessibility semantics in `IR.Schema.aria` as data.

## 5. The DfCM v26.9.16 corrections (REMOVED local derivation -> new owner)

One change (see commit `c6744cb`, branch `exp/v10`): the profile-envelope path in
`lib/ash_surface.ex` stopped deriving four facts. They are now DELEGATED FACTS read
through `AshSurface.IR.delegated/2` from `custom.ash_surface` — `nil` when not
delegated, never re-derived. The JS schema (`priv/static/ash_surface_runtime.mjs`,
`surfaceActionSchema`) mirrors the law: the four keys are nullable, an absent key
means "not delegated" and normalizes to `null`; no client-side defaults.

| REMOVED local derivation (old code in `lib/ash_surface.ex`) | New owner |
|---|---|
| `semanticId` default `"ash:#{id}"` minted for every action | meaning edge (r2rml); delegated via `custom.ash_surface` |
| `authorityBoundary` inferred from action type (`:read -> "OBSERVE"`, else `"DO"`) | capability edge (a2a admission law); delegated |
| `doAuthority` coupled to boundary (`boundary == "DO"`) | capability edge (a2a `AshA2A.CommandBus` admission law); delegated |
| `receiptRequired` defaulted to `true` | capability edge (a2a consequence class); delegated |

Consequence law: `digest`, `action_id`, `runtime_source` were untouched (mechanism,
golden values lawfully re-frozen); everything on the read path that re-derived a
delegated fact was deleted, not branched.

## 6. The projector recipe (~60 lines)

The recipe every projector (LiveView, JS, ARIA, voice) follows; the landed reference
is `lib/ash_surface/projector/expo.ex` against the `AshSurface.Projector` behaviour in
`lib/ash_surface.ex`.

```text
# --- the ash_surface projector recipe (v26.9.16) -------------------------------
# 0. Law you accept by writing a projector:
#    IN  : %AshSurface.Surface{} (already verified, digest-stable) or [IR]
#    OUT : ordinary executable artifacts + a write manifest
#    NEVER re-discover Ash semantics from Spark internals.
#    NEVER dispatch: a projector that actuates is a contract violation.
#
# 1. Implement the behaviour (lib/ash_surface.ex):
#
#      @behaviour AshSurface.Projector
#      @impl true
#      def project(%AshSurface.Surface{} = surface, opts \\ []) do
#        prefix     = Keyword.get(opts, :prefix, "my_surface")
#        target_dir = Keyword.get(opts, :target_dir)          # nil = render only
#        actions    = get_in(surface.contract, ["surface", "actions"]) || []
#        ...                                                   # 2..4 below
#      end
#
# 2. Read only admitted truth from each action entry:
#      id / resource / action            identity — re-use, never re-mint
#      semanticId / authorityBoundary /
#      doAuthority / receiptRequired     DELEGATED-OR-NIL — a null MUST be
#                                        emitted as null; defaulting = fabrication
#      profile.presentation              label/group/order/widget/format only
#      profile.transportFacts            delegated cost/latency/privacy classes
#                                        (low|medium|high) per transport; nil =
#                                        not delegated (Transport weighs what
#                                        is declared, never defaults)
#
# 3. Emit artifacts (one pure render fn per artifact, string in -> string out):
#      "#{prefix}.schemas.mjs"  => render_schemas(actions)   # Zod boundaries
#      "#{prefix}.actions.mjs"  => render_actions(actions)   # MX descriptors
#      "#{prefix}.events.mjs"   => render_events()           # OBSERVE stream
#      "#{prefix}.receipts.mjs" => render_receipts()         # reconcile primitives
#      "#{prefix}.mjs"          => render_client(prefix)     # pre-bound factory
#    Per-target facets ride the same loop: LiveView -> templates/heex,
#    ARIA -> role/state map off IR.Schema.aria, voice -> intent grammar.
#
# 4. Write only when target_dir is given (File.mkdir_p! + one write per
#    artifact); always return {:ok, artifacts_map, manifest}.
#
# 5. Gates the projector must survive (the suite re-projects into tmp/):
#      mix test                              # determinism + delegated-fact truth
#      node --check <every emitted .mjs>     # executable, TypeScript-free
#      npm test                              # JS consumer truth
#      mix format --check-formatted
#      mix compile --warnings-as-errors
#
# 6. Refusals you MUST honor (typed, never silent):
#      REFUSED_GENERATOR_OWNED   artifact owned by a generator, not a projector
#      unknown action id         refuse — no second application model
#      delegated fact nil        emit null — never synthesize a default
# ------------------------------------------------------------------------------
```

## 7. Provenance — where each piece lives at this writing

This document lives on `exp/v46` (base `282f3ca`, `@surface_schema_version` at the pre-bump CalVer of that base — the exact value stays in that branch's history).
The v26.9.16 wave is admitted on per-section branches and converges at integration:

| Element | Branch | Canonical path (post-integration) |
|---|---|---|
| SurfaceIR struct family | `exp/v01` | `lib/ash_surface/ir.ex` |
| Compiler (DiscoverOnce) + Section behaviour | `exp/v02` | `lib/ash_surface/compiler.ex` |
| Capability section (a2a projection) | `exp/v05` | `lib/ash_surface/compiler/capability.ex` |
| Presentation section reader | `exp/v06` | `lib/ash_surface/compiler/presentation.ex` |
| ARIA section | `exp/v08` | `lib/ash_surface/compiler/aria.ex` |
| IR codec (serialization + content addressing) | `exp/v09` | `lib/ash_surface/ir/codec.ex` |
| Delegation correction (four facts) | `exp/v10` (`c6744cb`) | `lib/ash_surface/ir.ex`, `lib/ash_surface.ex`, `priv/static/ash_surface_runtime.mjs` |
| Default section adapters (`Section.*`, build/2) | `exp/gapfix-adapters-001` | `lib/ash_surface/compiler/section/{ash,semantic,capability,presentation,schema}.ex` |
| Capability section conformed to build/2; `Compiler.Ash` rival retired (`AshTruth` = one canon); normalize carries `custom` + type kind | `exp/gapfix-adapters-001` | `lib/ash_surface/compiler/capability.ex`, `lib/ash_surface/compiler/ash_truth.ex`, `lib/ash_surface/compiler.ex` |

Already on base: `lib/ash_surface.ex`, `lib/ash_surface/projector/expo.ex`,
`priv/static/ash_surface_runtime.mjs`, `lib/ash_surface/{event,observation,planning_episode,transport,health}.ex`,
`lib/ash_surface/resource/validator.ex`.

## 8. Gates

`mix test` (Elixir truth, includes tmp/ projector re-projection), `npm test` (JS
consumer truth), `mix format --check-formatted`, `mix compile --warnings-as-errors`,
`node --check` on every emitted `.mjs`. No element of this document is ALIVE evidence;
aliveness is per-element execution against the exact admitted subject.
