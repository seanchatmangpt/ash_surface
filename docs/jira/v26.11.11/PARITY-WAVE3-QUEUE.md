# PARITY-WAVE3-QUEUE

Standing: UNVERIFIED

Dispatch queue for the goal: every ash_typescript capability mechanically validated in
ash_surface. Lane IDs are session-local; this file is the durable index. A slot frees when a
lane receipt lands; the next READY item dispatches in the same turn (never trickle, never
make-work).

## Stop condition (mechanical)

`mix ash_surface.parity` (gate lane Q1) exits 0: every capability in the ash_typescript
inventory maps to a passing court, a registered divergence (`KNOWN_DIVERGENCES.md` row with
receipt), or a NON-GOAL row with reason. Any unmapped capability exits 1 as loudly MISSING.

## Divergence law (operator, 2026-11-11)

A divergence from ash_typescript is acceptable ONLY if ash_surface implements something
better, with the better behavior witnessed by an executed court. Otherwise the capability is
implemented to parity. "UNSUPPORTED"/"registered divergence" without a better-implementation
receipt is a MISSING cell for the Q1 gate. NON-GOAL remains lawful only for README-declared
non-goals (no `.ts`/`.d.ts` emission, no execution path in `js.ex`).

Open parity debts created before this law (must be implemented or upgraded):
- w3-09: resource-level `type_name`/`field_names`/`argument_names`, domain `namespace`,
  embedded/union/typed-struct nested selection in typed_query `fields` (F1-typedq).
- S1-F: `uuid`/`naive_datetime` strictness, `limit_entry` required-limit.
- S1-A: M5 per-calculation arg binding.
- S1-H: path/query arg coercion.
- w3-07: `show_metadata`/`metadata_field_names` validation; nine `verify_action_types/*` files.
- w3-12: `apply_field_names/3` wiring; `zod_object_mode` consumer.
- w3-15: `FieldName` wiring into the compiler; per-action mapped-name consts.

## Running (wave 3, 20 slots)

b1a-successor, w3-01 IR wiring, w3-03 codegen runtime copy, w3-04 conformance, w3-05 fixtures,
w3-06 TS tree, w3-07 manifest/validator tests, w3-08 metadata+inference, w3-09 typed_query DSL,
w3-10 formatter/golden/cleanup, w3-11 docs, w3-12 errors Config, w3-13 FieldName, w3-14
constraint validator, w3-15 declaration order, w3-16 idempotence fixture, w3-17 runtime vocab,
w3-18 digest/classify, w3-19 TESTING floor, w3-20 skeptic. (w3-02 js.ex landed PARTIAL_ALIVE.)

## Q1 gate result (lane Q1 receipt `wave3-q1.md`, reference ash_typescript @ 5d6e80ae)

`mix ash_surface.parity` exits 1: 403 capabilities; pass 144, divergence 0, non_goal 72
(59 tstype + 13 TS-emitting codegen, via verbatim README quote), broken 0, MISSING 187.
MISSING by section: config 58, dsl 35, runtime 33, codegen 25, verifier 9, installer 6,
transformer 5, tstype 5, error 4, type 4, task 3. Full id list in the receipt. Each G-lane
below owns one slice; its done condition is that every id in the slice maps to a pass court
(real executed test), a better-witnessed KD row, or a README-quoted non_goal (propose README
non-goal wording in the receipt as an operator decision; do NOT edit README.md).

- G1 config keys (58). G2 dsl entities/options (35). G3 verifiers (9) + transformers (5).
- G4 runtime modules (33). G5 codegen modules (25) + tstype (5). G6 installer (6) + tasks (3)
  + error (4) + type (4).

## Test-port slice (operator request, 2026-11-11): ALL ash_typescript tests ported and adapted

Reference: `~/ash_typescript/test` (180 test files, 754 describe blocks, 2754 tests as counted
by Q1; advisory only). The capability gate does not cover tests; this slice does.
- T0 (first): coordinator-owned PORT LEDGER `parity/test_ledger.json` (one row per reference
  test file: disposition ported | adapted(changes, why) | skipped-gap(missing capability, owner,
  loud tagged skip) | non-goal(README verbatim quote)) + mechanical test-inventory gate
  `mix ash_surface.parity.tests` (file and describe titles from the reference; exit 1 on an
  unaccounted file, a ported/adapted row whose ash_surface test is absent, skipped, or does not
  run, or a skipped-gap row without a loud tagged skip). New files only; does not edit the
  capability gate.
- T1..Tn (after T0): porting lanes partitioned by reference test directory; each lane owns
  only its ledger rows via small targeted Edits (re-read before each Edit; never rewrite the
  file) and writes adapted tests under `test/ash_surface/ported/<dir>/`.
- Adaptation rules: replace generated-`.ts` text assertions with Zod/`.mjs` assertions run under
  node with real zod (ash_surface emits no `.ts`/`.d.ts`: such tests are ADAPTED, never
  verbatim, and some become non-goals with a README quote); Chicago style, no mocks; no silent
  skips: a skipped reference test must be a loud tagged skip tied to a ledger row; counterpart
  gaps are implemented under the divergence law, not accepted.
- Done condition: `mix ash_surface.parity.tests` exits 0.

## READY queue (dispatch order)

0000. GAP-UPGRADE lanes (after T6b lands `docs/zod-port/RPC-PIPELINE-CORE.md`): convert loud-skip
   `*_gap_test.exs` files to real surface tests using the non-actuating pipeline core: T6 (160),
   T7, T8, T9, T10, T11 (210 skipped), T12. One lane per T-dir; re-read receipts for each
   gap list; tests that truly need action execution stay skipped_gap or become non-goal only
   after operator decision D18 (README.md:55 "it never actuates" reading).

000. FINAL-REGEN (at drain, coordinator-run after F1-kindiv, F1-cfgkeys, T-lanes land): re-run
   `scripts/conformance_regen.exs`, both runners, diff-explain moved vectors; F1-confregen's
   regen (wave3-f1cr.md) predates F1-refwire/F1-divmap/F1-kindiv. Also re-pin the IR digest
   golden if it moved, re-run idempotence court `idempotence_court_wave3_test.exs`.

00. F1-nodo (FIRST on next free slot): `no_local_do_test.exs:259` red because
   `lib/ash_surface/runtime_parity/requested_fields/field_selector.ex:787` calls
   `Ash.Query.for_read` (G4 file). Fix without widening the allowlist; receipt
   `wave3-f1nd.md`. Then T7..T12 (rpc ports; T5 fixtures ready), T16, T17.

0. DOCS-v26.11.12 (operator request, top priority, dispatch on next free slot): write-only
   lane creating `~/<project>/docs/jira/v26.11.12/TODO-FIX-AND-FINISH.md` per Elixir project
   (fix / finish / commit hygiene / decide / reuse), starting with ash_surface, ash_a2a,
   ash_a2a_head, ash_affidavit, ash_atlassian from `PROJECT-REVIEWS.md` + receipts; repeat for
   the remaining projects as reviewers R3-R12 land.

1. Q1 coverage gate: derive the capability inventory mechanically from `~/ash_typescript/lib`
   (DSL entities+options, type_mapper kinds, error types, config keys, mix tasks, codegen
   modules, verifiers); map each cell to a court; `KNOWN_DIVERGENCES.md` register; exit 1 on
   unmapped. Owns `lib/mix/tasks/ash_surface.parity.ex`, `scripts/parity_inventory.exs`,
   `docs/KNOWN_DIVERGENCES.md`, tests. Prior art: smalt `scripts/sdk_coverage.py`.
2. Q2 shim-court non-vacuity: prove each new gate can fail (mutate a renderer, gate must flip,
   restore byte-exact). Canonical: smalt `scripts/shim_court/lib.sh`.
3. R1-R12 read-only reviewers of the other Elixir projects (pairs; xaas alone):
   ash_a2a+ash_a2a_head, ash_affidavit+ash_atlassian, ash_autofde+ash_dspy,
   ash_ex4pm+ex4pm, ash_expo+zoela_phx, ash_graphlaw+ash_kudzu,
   ash_planning_center+ash_pplan, ash_r2rml+ggen_igniter, beam4pm+pm4exunit,
   ex_noun_verb_cli+gno, kanban+smalt, xaas.
4. S1 skeptic follow-ups: write lanes for each HIGH/MED finding from w3-20.
5. S2 adversarial executed courts: for each Phase-A renderer, run the skeptic's concrete
   inputs under node with real zod; any disagreement is a defect lane.
6. F1 wave-3 fix lanes: defects surfaced by receipts of w3-01..w3-20 (named, registered only).

## S1 register (w3-20 skeptic findings, dispatch in order as slots free)

- S1-A (dispatched): H1 calc envelope exhaustive record, M5, M6, L7 in
  `calculation_schema.ex` + `relationship_schema.ex`.
- S1-B READY: H2 + M14 + M12 errors leak/serialize/Config tenant default (`errors.ex`,
  `error_formatter.ex`, `error_schema.ex`, `config.ex`; coordinate with w3-12 receipt).
- S1-C READY: H3 + L5 filter relationship union size cap (`filter_schema.ex`).
- S1-D READY: H4 + L9 + L10 channel discovery duplicate-event/payload-name scoping
  (`channel_discovery.ex`, `section/channel.ex`, channel transport).
- S1-E READY: H5 + M13 HTTP transport error-body classification (`ash_surface_http_transport.mjs`).
- S1-F READY: M1 + M2 + M3 + M4 + L3 + L4 regex/guard hardening (`zod_type.ex`,
  `query_schema.ex`, `zod_guard.ex`; member allow-list, empty-regex refusal).
- S1-G READY: M7 + M8 + L2 union/embedded boundary, tag uniqueness, ref admission
  (`union_schema.ex`, `embedded_schema.ex`, `validation_error_schema.ex`).
- S1-H READY: M9 + M10 + M11 + L11 Expo/route identifier collisions and quoting
  (`projector/expo.ex`, `route_schema.ex`).
- S1-I READY: L1 + L6 + L8 identity/selection/field_name silent drops.

## Saturation

Two consecutive waves below threshold (LOW doc drift only, zero regressions) stop the fleet;
a landed fix, open item, or MEDIUM+ finding resets the count. Idle slots with an empty READY
queue are correct, not failure.

## See Also

`PARITY-WAVE2-BACKLOG.md` · `docs/zod-port/CONTRACT.md` · `docs/zod-port/receipts/`
