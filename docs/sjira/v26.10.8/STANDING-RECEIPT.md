# Standing Receipt — doc-hit certification coverage (v26.10.8)

# STANDING-RECEIPT

Standing: **CERTIFIED** (as of 2026-10-09)

## Subject

- Git subject: `07f8d7154e2157c083e5f87c99574710c73aa07b` (current `main` HEAD at issuance)
- Recorded gate evidence: doc-hdit ACCEPTED receipt in `doc-hdit.receipts.jsonl`,
  subject digest `5ab9a0c874b17f639828814c7436cd73597a9269ff037028d8705cbea3fdb487`

## Honest disclosure: digest-bound vs git-bound

The original certify run's receipt `subject` field is a **content digest**
(`5ab9a0c8…`), not a git object. Git-bound coverage of the same documentation
surface came via the falsifier runs recorded in the receipts chain and the
certify-meta `repo_head_at_certify` (`dc214d7b5`), not from a git-bound subject
field. This receipt binds standing to the git subject at issuance (HEAD above)
while accepting the digest-bound certify receipt as the recorded gate evidence;
the digest-bound history is disclosed, not erased.

## Gate evidence (doc-hdit.receipts.jsonl, verdict ACCEPTED)

| Gate | Value | Threshold |
|---|---|---|
| S_coverage | 0.9995866060355518 | >= 0.9 |
| Phi_halluc | 0.0 | <= 0.001 |
| Q_density | 1.0 | >= 0.65 |

- Receipt hash: `488a29bf638068d7b0bbb9a2b9336c82d1ba013f4ccb75b6c2279fcff3d5db9e`
- Timestamp: 1791555175

## Extractor pin

- `extractor_pin_sha256`: `4c862576ab63595f9cd0417b35341af3ec1001f49450e79bf2e4c291a4a4246f`
  (verified 2026-10-09 against `/Users/sac/ggen-marketplace/scripts/gen_doc_surface.py`)
- The receipt's `extractor` field (`a579e210…`) is the BLAKE3 identity of the
  same file bytes (src/certify.rs extractor_identity), retained as historical
  subject identity; current fleet pin tracked in
  `ggen-marketplace docs/sjira/v26.10.8/PIN-ROTATION-LEDGER.md`.

## Denominator law

Coverage figures are gated under the module-level denominator law
(`ggen-marketplace docs/sjira/v26.10.8/DENOMINATOR-SCOPE-DECISION.md` @`0f3d840ff`);
per-function coverage figures are the report-only layer.

## WO-2 (ASHSURF-26108-2) — ALIVE

WO-2 in `candidates.jsonl` carries `standing: ALIVE` with
`evidence_ceiling: EXECUTED_VERIFIED`:
- regen command `mix run scripts/agent_card_regen.exs` exit 0, byte-identical
  regeneration of `priv/generated/agent_card.json` (sha256 `6f36b48f…fcc0`)
- both falsifiers (regen differs / hand-edited card) recorded `false`
- `mix test test/ash_surface/agent_card_artifact_test.exs`: 2 tests, 0 failures
- base_sha `68f77041b885619dc65cc9b5fecd521f4667ad97`

## Tag coverage

- `v26.10.8-2` = `dc214d7b5bea46e160afcb247e1af09d96525c27`
- `v26.10.8` = `061b1e9a6dfc83f3a3fdb0899cec898111ce9a3a`
- The certify evidence chain (receipts jsonl + certify-meta, committed in
  `757060450`) and subsequent doc-only lands (`3d9ec9941`, `d60fdb630`, R34/R43,
  R61, R89 denominator-scope law citation) are **post-tag lands on top of
  `v26.10.8-2`**, docs-pathspec only; this receipt's git subject (HEAD
  `07f8d7154`) is covered by the same digest-bound evidence plus the falsifier
  runs, as disclosed above.

## Replay

- Receipts chain: `docs/sjira/v26.10.8/doc-hdit.receipts.jsonl`
- Certify meta: `docs/sjira/v26.10.8/doc-hdit-certify-meta.json`
- Work order: `docs/sjira/v26.10.8/candidates.jsonl` (ASHSURF-26108-2)
- Certify command (from meta): `doc-hdit certify /tmp/hdit/ash_surface.inputs.json courts/doc_quality.court --docs docs/reference/generated --chain docs/sjira/v26.10.8/doc-hdit.receipts.jsonl --extractor scripts/gen_doc_surface.py`
