# MIGRATION_26_9_16.md — ash_surface 26.9.14 -> 26.9.16 breaking changes

- **Base:** `282f3ca` (chicago zero-config convergence), repo version `26.9.13` at base; the 26.9.16 bump itself is `version-bump-011` (blocked by integration).
- **Wave:** docs/jira/v26.9.16/ — one ticket per worktree, standing ledger `V_WAVE.md` (owner: `exp/v50`).
- **Canon:** consumer-side receipt index follows zoela's `MIGRATION.md` canon
  (`/Users/sac/zoela/MIGRATION.md`): per-change scope, owning files, gates as
  observed exit codes, standing `UNKNOWN` until integration re-runs the gates on
  the merged tree. Nothing here claims ALIVE at integration scope.
- **Date:** 2026-09-15.

Sections 1–4 describe the four breaking surfaces. Every interface below is
sibling-canonical: it is manufactured on its owning `exp/v*` branch and lands on
the integrated tree per the `V_WAVE.md` merge order (v01 -> v02 -> v16 -> sections
-> v10 AFTER sections -> v23 (its `mix.exs` kept) -> rest). The pins in section 2
are the exception: they are landed on this branch verbatim from `exp/v23`
(cherry-pick of `57278d7`), because this document must not cite pins that the
tree it ships on does not carry.

## 1. Envelope slimming — the four facts are delegated, not derived

**Owner:** `exp/v10` — `lib/ash_surface.ex`, `lib/ash_surface/ir.ex`,
`priv/static/ash_surface_runtime.mjs`,
`test/ash_surface/{action_id,digest}_test.exs`.

Before 26.9.16 the profile-envelope read path (`lib/ash_surface.ex`) derived four
facts locally when the action profile was silent. In 26.9.16 all four are
**delegated facts**: each is read from the manifest entrypoint's
`custom.ash_surface.profile` IR section by `AshSurface.IR.delegated/2` (exposed
as `AshSurface.delegated/2`), and is `nil` when not delegated. **No re-derivation
logic exists anywhere on the read path.** Accessors tolerate atom and string keys,
so the in-memory decorated manifest and a serialized round-trip feed the same
read path.

### Per-field before/after

| field (profile key) | 26.9.14 — local derivation (before) | 26.9.16 — IR delegation (after) |
|---|---|---|
| `semanticId` | `Map.get(act_prof, "semanticId", "ash:#{id}")` — local default minted the IRI `ash:<action_id>` when the profile was silent | `AshSurface.IR.delegated(entrypoint, "semanticId")` — value only when the delegating authority stored one; `nil` otherwise; AshSurface never mints an IRI |
| `authorityBoundary` | inferred from action type: `:read -> "OBSERVE"`, everything else `"DO"` (`Map.get(act_prof, "authorityBoundary", default_boundary)`) | `AshSurface.IR.delegated(entrypoint, "authorityBoundary")` — `nil` when not delegated; action type determines nothing about boundary |
| `doAuthority` | `Map.get(act_prof, "doAuthority", authority_boundary == "DO")` — coupled to the boundary default, so every non-read action silently carried DO authority | `AshSurface.IR.delegated(entrypoint, "doAuthority")` — `nil` when not delegated; decoupled from boundary and from action type |
| `receiptRequired` | `Map.get(act_prof, "receiptRequired", true)` — defaulted to `true` | `AshSurface.IR.delegated(entrypoint, "receiptRequired")` — `nil` when not delegated; no default |

Canonical delegated section shape (per manifest entrypoint action):

```elixir
custom.ash_surface = %{
  "id" => action_id,
  "profile" => %{
    "semanticId" => term() | absent,        # atom OR string keys tolerated
    "authorityBoundary" => term() | absent,
    "doAuthority" => term() | absent,
    "receiptRequired" => term() | absent,
    ...                                   # free projection metadata
  }
}
```

`AshSurface.IR.delegated_facts/0` returns the canonical key list
(`["semanticId", "authorityBoundary", "doAuthority", "receiptRequired"]`).

**Mechanism untouched:** `digest`, `action_id`, `evidenceRequired`,
`possibleRefusals`, `profile` pass-through and the runtime source are unchanged
by this slimming; golden values were lawfully re-frozen only through real
pipelines.

### Client-side mirror (breaking for JS consumers)

`priv/static/ash_surface_runtime.mjs` — `surfaceActionSchema` mirrors the
delegated-or-null law: the four facts are **nullable**, an **absent key means
"not delegated"** and normalizes to `null`. There are no client-side defaults
and no client-side re-derivation. A JS consumer that branched on
`authorityBoundary === "DO"` defaults or truthy `receiptRequired` must now
handle `null` explicitly and route authority questions to the delegating
authority.

## 2. New deps — canonical v26.9.16 pins

**Owner:** `exp/v23` (commit `57278d7`; its `mix.exs` lines win at integration
over v04/v05 local lines). Landed verbatim on this branch; pin parity verified
(`git diff exp/v23 exp/v49 -- mix.exs mix.lock` is empty).

| dep | pin (git SHA) | notes |
|---|---|---|
| `ash_r2rml` | `7d958a8c47a5a3459a515ac6f81a4d2d2d84dd16` (github.com/seanchatmangpt/ash_r2rml.git) | `runtime: false`, `override: true` — git pin overrides `ash_a2a`'s hex `~> 26.8` requirement; pinned git version 26.9.12 satisfies it numerically |
| `ash_a2a` | `e25ed6e3252291fd9816747a1b904303cc35c315` (github.com/seanchatmangpt/ash_a2a.git) | `runtime: false`; requires `igniter` in all envs, so `igniter` drops `only: [:dev, :test]` (kept `runtime: false` — no boot-path change) |

Consumers upgrading from 26.9.14 (no git deps) should copy the block verbatim —
including the `override: true` and the `igniter` `only:` removal — then
`mix deps.get` and verify both SHAs appear in `mix.lock`.

## 3. Compiler entry — `compile/1` (DiscoverOnce)

**Owner:** `exp/v02` — `lib/ash_surface/compiler.ex`,
`test/ash_surface/compiler_test.exs`. Canonical IR owner at integration:
`lib/ash_surface/ir.ex` (v01 five-section canon + v10 delegated-facts block;
v02's inline IR duplicate is superseded at integration).

`AshSurface.Compiler.compile/1` is the single compilation entry: manifest or
`Ash.Domain` in, one **single discovery pass** (DiscoverOnce — discovery never
re-runs per section), a normalized action map, then per-action section builders,
yielding one `%AshSurface.IR{}` per public action with the digest computed via
the frozen AshSurface canon over the normalized map.

```elixir
# canonical section behaviour (one definition; branch-local copies superseded)
defmodule AshSurface.Compiler.Section do
  @callback build(action :: map(), context :: map()) ::
              {:ok, term()} | {:error, term()}
end
```

The IR is a five-section record — every field except `version` and `digest` is
owned by one `Section` implementation (`ash | semantic | capability |
presentation | schema`); the compiler itself owns only orchestration, the single
discovery pass, and the digest. Section bindings are overridable via
`compile/2` (`sections:`). Default section modules resolve at call time and
fail closed while sibling branches land.

**Breaking for consumers:** bespoke per-section discovery loops are replaced by
`compile/1`; new sections implement the `Section` behaviour rather than
extending the compiler.

## 4. Projector behaviour v2 + legacy adapter

**Owner:** `exp/v16` (behaviour + adapter; at v50-integration time not landed —
extant projectors, base t-wave set + `exp/v20` VoiceKiosk, run through
`AshSurface.project/3` unchanged).

```elixir
defmodule AshSurface.Projector.IR do
  # IR-era projector behaviour (v2)
  @callback project_ir(irs :: ir() | [ir()], opts :: keyword()) ::
              {:ok, term(), map()} | {:error, term()}
end
```

The canonical IR node is declared locally (no upstream owner yet):
`kind: "ash_surface.surface"` with the `ash` fact section carrying **exactly the
four verified-surface facts** (`manifest`, `contract`, `digest`, `action_ids`).
Re-extraction is fact assembly, never re-derivation — Ash ships no manifest
deserializer and none is invented here.

**Legacy adapter — zero-change migration:** `from_manifest_projector/1` wraps
any existing `AshSurface.Projector`-behaviour module (anything exporting
`project/2`) in the `ManifestProjector` adapter; the wrapped projector observes
the identical surface it received before the IR era. Dispatch through
`AshSurface.Projector.IR.project/3`. Refusals are typed, never silent:
`{:unknown_projector_kind, _}`, `{:invalid_irs, _}`, `{:invalid_ir, _}`,
`{:missing_surface_ir, n}`, `{:duplicate_surface_irs, n}`,
`{:invalid_surface_facts, keys}`.

**Breaking for consumers:** nothing, if projectors keep the legacy behaviour and
are wrapped; new projectors implement `project_ir/2` and must refuse unknown
node kinds instead of silently pruning them.

## 5. Consumer upgrade checklist

Format per zoela's `MIGRATION.md` canon: each step records scope, owning files,
and the gate whose exit code you observed. Standing stays `UNKNOWN` until you
re-run the gates on your integrated tree; no step is claimed ALIVE by
inspection.

1. **Pins.** Copy the section-2 deps block verbatim; `mix deps.get` -> exit 0;
   verify both SHAs in `mix.lock`. Gate: graph resolves with `override: true`.
2. **Stop deriving the four facts.** Delete every local default for
   `semanticId` / `authorityBoundary` / `doAuthority` / `receiptRequired`;
   treat `nil` as "not delegated" — never as `OBSERVE`/`true`/an `ash:` IRI.
   Gate: the delegation tests run against real `ash_r2rml`/`ash_a2a`, never
   mocks (no-local-DO tripwire stays green).
3. **JS runtime.** Re-point at the shipped `ash_surface_runtime.mjs`;
   branch on `null` explicitly. Gate: `npm test`.
4. **Adopt `compile/1`.** Replace bespoke discovery with the single entry;
   express new sections as `Compiler.Section` `build/2` implementations.
5. **Projectors.** Wrap legacy modules with `from_manifest_projector/1` and
   dispatch via `Projector.IR.project/3`; write new projectors against
   `project_ir/2`. Gate: legacy e2e output byte-identical pre/post wrap.
6. **Battery.** `mix test` (x3 for flake), `npm test`, `mix test.zero` /
   `mix test.all` where present. Re-freeze goldens only through real pipelines.
7. **Ledger.** Every artifact you hand-write that a pack/generator could own
   gets a `HANDWRITTEN.md` row (path | semantic element | missing capability |
   intended owner pack | date); the ledger must shrink per milestone.

## Standing

| surface | owning branch | standing |
|---|---|---|
| envelope slimming (IR delegation) | `exp/v10` | ALIVE at v50 integration (387/387) — UNKNOWN here (sibling) |
| deps pins | `exp/v23` | landed verbatim here (cherry-pick `57278d7`); ALIVE at integration per wave law |
| `Compiler.compile/1` + `Section` behaviour | `exp/v02` | ALIVE at v50 integration — UNKNOWN here (sibling) |
| `Projector.IR` v2 + legacy adapter | `exp/v16` | not landed at v50 integration time; projectors run via `AshSurface.project/3` |
| this document | `exp/v49` | gates in the commit receipt; `mix test` -> 0 on this tree |
