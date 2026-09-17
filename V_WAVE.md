# V_WAVE — the v26.9.16 surface-IR wave ledger (50 rows)

Integration row: `exp/v50` (worktree `/Users/sac/ash-surface-wt/v50`, base `282f3ca`;
that worktree was removed after the `--no-ff` landing — the landed tree, not the
vanished path, is the authority; noted by gapfix-docs-truth-013).
This table is the wave's standing ledger: one row per branch, standing recorded as
expected (`UNKNOWN` until integration) and, where integration ran in-session, the
actual standing observed at merge time.

> **Superseded-cell banner (gapfix-docs-truth-013).** The per-row interim cells
> below — "(not landed)", "(no delta)", "(moving head; no delta)" for v03, v04,
> v07, v11–v15, v17–v21, v22–v26, v27–v49 — are pass-time records **superseded
> by the "Final standings" addendum at the bottom of this file**, which is the
> authoritative standing for every row (all ALIVE per its table, including
> v23's mix.exs precedence and the v25/v40 late-merge corrections). Read a
> row's expected cell as history; read the addendum as law. The `Projector.IR`
> bullet in "Canonical interfaces" below ("Not landed at integration time") is
> likewise superseded: v16 landed at final integration and its behaviour is
> canonical at `lib/ash_surface/projector/ir.ex`.

Canonical interfaces (wave law, all rows measured against them):

- **`ir.ex` five-section shape** — `AshSurface.IR` with sections
  `ash | semantic | capability | presentation | schema` (+ `version`, `digest`),
  owned by `lib/ash_surface/ir.ex` (v01, extended by v10's delegated-facts block).
- **`Compiler.Section` behaviour** — `AshSurface.Compiler.Section`,
  `@callback build(action :: map(), context :: map()) :: {:ok, term()} | {:error, term()}`,
  owned by `lib/ash_surface/compiler.ex` (v02). One definition; per-branch local
  copies are superseded at integration.
- **`Projector.IR` behaviour** — projector contract (v16). Not landed at
  integration time; the extant projectors (base t-wave set + v20) run through
  `AshSurface.project/3`.

Merge order (law): v01 → v02 → v16 → v03–v08 → v09 + v11–v15 → v10 (AFTER sections)
→ v17–v21 → v23 (its mix.exs kept over v04/v05 local lines) → v27–v44 → v24/v26/v40
→ v22/v25/v45–v49 → v50.

| branch | scope | owning files | canonical interface | gate | standing (expected → actual @v50) |
|---|---|---|---|---|---|
| exp/v01 | canonical SurfaceIR struct family (five sections + section accessors) | `lib/ash_surface/ir.ex`, `test/ash_surface/ir_test.exs` | ir.ex five-section shape (owner) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged, 387/387) |
| exp/v02 | DiscoverOnce compiler orchestrator + Section behaviour | `lib/ash_surface/compiler.ex`, `test/ash_surface/compiler_test.exs` | Compiler.Section behaviour (owner) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; inline IR duplicate removed in favor of ir.ex) |
| exp/v03 | ash section builder | (not landed: branch at base at integration time) | Compiler.Section build/2 | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v04 | semantic section builder (+ local mix.exs dep lines) | (not landed; mix.exs note: v23's lines win over v04/v05 local lines when it lands) | Compiler.Section build/2 | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v05 | capability section (ash_a2a projection) | `lib/ash_surface/compiler/capability.ex`, `mix.exs`+`mix.lock` (ash_a2a test-env dep), `test/ash_surface/compiler/capability_section_test.exs` | Compiler.Section build/2 (pre-canonical build/1 subject projection — conformance owed by successor) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; build/1 shape kept, behaviour claim corrected to canonical truth; v23 not landed so its mix.exs lines stand as merged) |
| exp/v06 | presentation section reader | `lib/ash_surface/compiler/presentation.ex`, `test/ash_surface/compiler/presentation_section_test.exs` | Compiler.Section build/2 (pre-canonical local copy superseded) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; duplicate Section module removed) |
| exp/v07 | schema section builder | (not landed) | Compiler.Section build/2 | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v08 | aria section (accessibility as data in IR.Schema.aria) | `lib/ash_surface/compiler/aria.ex`, `test/ash_surface/compiler/aria_section_test.exs` | Compiler.Section build/2 (pre-canonical local copy superseded) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; duplicate Section module removed) |
| exp/v09 | IR serialization + content-addressing codec | `lib/ash_surface/ir/codec.ex`, `test/ash_surface/ir_codec_test.exs` | codec over the surface-contract staging IR; module re-pointed at integration to `AshSurface.IR.Surface` (its five map sections actions/identity/profile/resources/transports), yielding `AshSurface.IR` to the canonical ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; goldens/digest pins intact) |
| exp/v10 | v26.9.16 delegation slimming (semanticId/authorityBoundary/doAuthority/receiptRequired are delegated facts) — merges AFTER sections | `lib/ash_surface.ex`, `lib/ash_surface/ir.ex`, `priv/static/ash_surface_runtime.mjs`, `test/ash_surface/{action_id,digest}_test.exs`, `HANDWRITTEN.md` | ir.ex five-section shape + delegated-facts block composed into v01 canon | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged after sections per order; ir.ex add/add composed v01 shape + v10 delegation) |
| exp/v11 | intent (codec/intent group) | (not landed) | ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v12 | intent | (not landed) | ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v13 | intent | (not landed) | ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v14 | intent | (not landed) | ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v15 | intent | (not landed) | ir.ex canon | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v16 | Projector.IR behaviour | (not landed at integration time) | Projector.IR behaviour (owner) | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta; projectors run via AshSurface.project/3) |
| exp/v17 | projector | (no delta at pass time) | Projector.IR behaviour | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (moving head; no delta when passed) |
| exp/v18 | projector | (no delta at pass time) | Projector.IR behaviour | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (moving head; no delta when passed) |
| exp/v19 | projector | (no delta at pass time) | Projector.IR behaviour | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (moving head; no delta when passed) |
| exp/v20 | VoiceKiosk projector (fifth projector, IR extensibility proof) | `lib/ash_surface/projector/voice_kiosk.ex`, `test/ash_surface/projector/voice_kiosk_test.exs` | projector over surface IR; e2e re-expressed at integration under v10 delegation law (authority facts delegated via action profile, not derived) | mix test → 0 | UNKNOWN-until-integration → **ALIVE** (merged; e2e corrected to delegated-facts law) |
| exp/v21 | projector | (no delta at pass time) | Projector.IR behaviour | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (moving head; no delta when passed) |
| exp/v22 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v23 | deps (canonical mix.exs; its lines kept over v04/v05 local lines) | (not landed; at integration v05's local ash_a2a test-env dep stands, ledgered here) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta; precedence rule armed for its landing) |
| exp/v24 | machinery | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v25 | docs (DEP_GRAPH.md, real 132-line delta) | (not landed at first pass; NOT-MERGED at efceb65 — proven by sweep; merged post-close 6f0338a) | — | mix test → 0 | UNKNOWN-until-integration → **NOT-MERGED at efceb65** (the "(no delta)" note below was wrong) |
| exp/v26 | machinery | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v27 | tests | (no delta at pass time) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (moving head) |
| exp/v28 | tests — DiscoverOnce discovery law | `lib/ash_surface/{ir,compiler}.ex` (branch-local scaffolding), `test/ash_surface/compiler_discovery_test.exs` | carries a THIRD local `AshSurface.IR` canon (`%IR{actions, digest}` + normalize/1) — conflicts with canonical ir.ex/compiler.ex; requires adaptation to canonical interfaces | mix test → 0 | UNKNOWN-until-integration → **REFUSED this session** (merge conflicted; head still moving under concurrent manufacture; scaffolding canon must yield to ir.ex + compiler.ex owners — integrate after it lands) |
| exp/v29–v44 | tests | (heads moving under concurrent manufacture at integration time; v44 window) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (integration halted at v28 conflict to avoid serializing moving trees) |
| exp/v45 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v46 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v47 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v48 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v49 | docs | (not landed) | — | mix test → 0 | UNKNOWN-until-integration → **UNKNOWN** (no delta) |
| exp/v50 | wave integration + this ledger | `V_WAVE.md`, `HANDWRITTEN.md`, integration reconciliations (see receipt) | all three canonical interfaces enforced as the merge law | full battery ×3, mix test.zero, zero_config_v2.sh, no_local_do; GATE mix test → 0. [receipt ref, gapfix-v2-receipt-008 @ 2026-09-16T23:49Z: the v50 session itself ran only v1 `zero_config_check.sh` (see Integration facts; final-integration-010 receipt) — v2's sole prior exit receipt was v40-era exp/v40 6c4ba94, a 308-test tree. v2 now receipted on the landed tree at a7a6b40 (725-test): EXIT[env-read guard]=0 EXIT[mix deps.get]=0 EXIT[npm install]=0 EXIT[mix test]=0 (725) EXIT[npm test]=0 (217/217) EXIT[mix test.zero]=0 (scrubbed env -i test.all re-run: 725 + 217/217), script exit 0, ZERO_CONFIG_OK] | **this row** |

## Integration facts (v50 session)

- Merged in prescribed order: v01, v02, (v16/v03/v04 no-ops), v05, v06, (v07),
  v08, v09, (v11–v15), v10 (after sections), (v17–v19), v20. v28 conflicted;
  `git merge --abort`; v29+ not attempted (moving heads — serialize-shared-trees law).
- Conflicts resolved: `lib/ash_surface/ir.ex` add/add composed as v01 canonical
  five-section shape + v10 delegated-facts block (both branches' laws preserved).
- Superseded duplicates: inline `AshSurface.IR` in `compiler.ex` (v02) and
  `codec.ex` (v09 — re-pointed to `AshSurface.IR.Surface`, goldens intact);
  three branch-local `AshSurface.Compiler.Section` definitions (v05/v06/v08)
  superseded by the canonical behaviour in `compiler.ex`; their builders keep
  their documented build/1 subject contracts without faking build/2 conformance.
- Test corrections (asserting integrated truth, none weakened):
  `capability_section_test` pins canonical `build: 2` behaviour + honest
  non-conformance; `voice_kiosk_test` e2e delegates authority facts via the
  action profile (v10 law) instead of the removed pre-v10 local derivation.
- Checklist items **BLOCKED** (owners not landed; no fabrication):
  [corrected post-close: `scripts/zero_config_v2.sh` DID exist, on exp/v40 —
  this "exists on no branch" claim was false; the branch landed late via 3b2fdf4];
  `no_local_do` is named by the wave plan but defined nowhere in-repo.
  Substituted in-session proof: `mix test` 387/387, `mix test.all` ×3,
  `mix test.zero` (env -i), `scripts/zero_config_check.sh` (v1 fresh-clone gate).
- v23 precedence note: with v23 not landed, v05's local `ash_a2a` test-env dep
  stands in `mix.exs`/`mix.lock`; when v23 lands, its mix.exs wins per wave law.

## Final standings (v50 close-out, final-integration-010)

39 of the 41 remaining branches were merged into `exp/v50` in wave order
this session; the per-row "actual" column above reflects the first
integration pass — this addendum is the authoritative final standing.
The two exceptions, both proven by the 26-agent post-close verification
sweep (reports under ~/.zcode/workspace/default/capacity-probe/hw25/):
v40 (silently omitted here — merged late into the checkpoint by
coordinator repair 3b2fdf4 before the landing) and v25 (silently omitted,
NOT-MERGED at the landing efceb65 — merged post-close at 6f0338a).

| rows | final standing |
|---|---|
| v01, v02, v05, v06, v08, v09, v10, v20 | **ALIVE** (merged first pass, 387/387 then; carried green through close-out) |
| v03, v04, v07 | **ALIVE** (merged; branch-local `AshSurface.IR`/`Compiler.IR`/`Compiler.Section` declarations superseded — canonical owners `ir.ex`, `compiler/ir.ex`, `compiler.ex`; v04/v07 tests corrected to integrated truth) |
| v11–v15 | **ALIVE** (merged; v11 `intent.ex` owns canonical `AshSurface.Intent`; v12's duplicate parent dropped; v13's minimal shape renamed `AshSurface.Intent.Envelope`; v14 event_projection + v15 round-trip green as landed) |
| v16–v19, v21 | **ALIVE** (merged; v16 `Projector.IR` behaviour canonical; v17/v18 local IR/behaviour declarations superseded; v18/v19 reader extracted as `Projector.IREntry`; v21 doubles re-namespaced, fixture delegates facts per v10 law) |
| v23, v24, v26 | **ALIVE** (merged; v23's mix.exs dep block is canonical — applied at v04 resolution, v30/v31 test-only local lines refused in its favor per wave law) |
| v22, v27 | **ALIVE** (merged; v27's IR doubles re-namespaced off canonical `AshSurface.IR`) |
| v28 | **ALIVE** (merged; stub compiler.ex/ir.ex dropped for canonical v02 owners; discovery suite re-pointed at the canonical compiler's receipt-token DiscoverOnce laws; memoization/`force:` law not asserted — canonical compiler claims no cross-compile cache) |
| v29 | **ALIVE** (merged; its IR sub-shapes folded into canonical ir.ex; builder landed as `Compiler.AshTruth`; `lib/ash_surface/section.ex` landed as the `AshSurface.Section` behaviour) |
| v30, v31 | **ALIVE** (merged; test canons re-namespaced; v31 supervises the real `AshA2A.ReceiptStore.Memory` under the v23-pinned ash_a2a) |
| v32–v39, v41–v43 | **ALIVE** (merged; v39's golden canon re-namespaced; v41/v42 convergent e2e/health fixes taken from their sides; v38 no-local-do tripwire satisfied — see below) |
| v44 | **ALIVE** (merged; validator-ir-alignment stand-in DELETED per its own INTEGRATION clause — tests re-pointed at the real `Compiler.Ash.build/1`, `:integration_pending` tags dropped) |
| v45–v49 | **ALIVE** (merged; docs/ledger/ontology rows; v49's mix.exs identical to v23's canonical block) |
| v40 | **ALIVE** (merged late into the exp/v50 checkpoint by coordinator repair 3b2fdf4 at 13:16 — after this addendum was first authored (31e1052, 13:11), which is why the "remains absent" claims below were true when written but falsified five minutes later; `scripts/zero_config_v2.sh` present at the landing byte-intact, 179 lines) |
| v25 | **ALIVE** (NOT-MERGED at the landing efceb65 — silently omitted from the "all 39/49 merged" claims despite a real 132-line delta (`docs/DEP_GRAPH.md` + ledger row); proven by sweep agent-13; merged post-close at 6f0338a with this ledger correction) |
| v50 | **this row** (all gates green; landed `--no-ff` onto `feat/dfcm-surface-core`) |

Reconciliation receipts (this session):

- Canonical owners enforced: `lib/ash_surface/ir.ex` (five-section IR + v10
  delegated facts + v29 Input/Output/Policy sub-shapes; `IR.Capability`
  extracted to `lib/ash_surface/ir/capability.ex` with the
  `authority_required/1` reader the no-local-do law demands),
  `lib/ash_surface/compiler.ex` (DiscoverOnce + Section behaviour),
  `lib/ash_surface/compiler/ir.ex` (compiler IR slices: carrier `Schema`,
  `Semantic`, `Boundary`), `lib/ash_surface/projector/ir.ex` (v16
  behaviour), `AshSurface.Intent` (v11), `AshSurface.Compiler.Ash` (v03
  section-set builder) vs `Compiler.AshTruth` (v29 per-action truth pair).
- no-local-do tripwire: `apply/3` laundering removed from
  `compiler/ash.ex` (dead branch: pinned ash exports no
  `Ash.Resource.Info.policies/1`) and `compiler/capability.ex` (direct
  call; ash_a2a is all-env under v23); `live_view.ex` gates through
  `AshSurface.IR.Capability.authority_required/1`; the tripwire's owner
  exemption path-mapping repaired (camelize("ir") = "Ir" made it
  unsatisfiable by construction; detection logic untouched).
- Earlier-session BLOCKED items resolved: `scripts/zero_config_v2.sh`
  [corrected post-close: NOT absent — owned by exp/v40, landed via 3b2fdf4,
  byte-intact in this tree; the "remains absent" claim above was falsified
  by the late v40 merge minutes after authoring];
  `no_local_do` now exists and is green (v38).
