# chicago-digest-parity-051: cross-language digest parity tables
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
One parity suite covering EVERY digest-bearing contract (contract, event, observation, episode [after 036], receipt [after 038], IR): JS twin recomputes each from canonical JSON; table per contract. Subject: test/js/digest_cross_language*.test.mjs + elixir fixtures.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- parity table per contract (>=5); falsifier: diverge the JS canonicalizer -> parity RED; gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g51 + exp/chicago-digest-parity-51 | dispatched by coordinator (chicago wave)
2026-09-17T06:49:55Z | REAPED: cluster death at ~30min (sustained-load grind; 5 simultaneous); branch preserved — successor reviews git log first
2026-09-17T08:09:08Z | IN_PROGRESS | successor re-dispatch (final cohort 4; branch preserved — review git log first; 045's lesson: long-runners are alive)
2026-09-17T08:16:54Z | DONE | exp/chicago-digest-parity-51 @ 9c6c753(style) + 617b138(test/digest) | predecessor left 4 untracked files (fixtures module, guard test, fixture JSON, JS twin v3) — reviewed, verified against real laws, one guard-logic defect fixed (order-twin assertion demanded all 3 rows share one digest, contradicting its own moduledoc; now twins-equal AND distinct-differs); episode (036) + receiptHash pin (038) NOT ancestors of base f0d3577 — parity built for the 5 digests that exist here (contract/event/observation/ir/receipt), siblings exp/chicago-episode-digest-36 + exp/chicago-receipthash-38 noted in both file moduledocs as the merge-time extension point; gates: MIX_ENV=test mix compile --warnings-as-errors=0, mix test=0 (846/841+doctests, rerun after format repair), npm test=0 (268/0, v3 suite 10/10, all 5 tables MATCH), mix format --check-formatted=0 after mechanical repair (9c6c753) of 2 files left unformatted at base by 3954d86; falsifier EXECUTED: reverse both JS canonicalizer sorts in digest_cross_language_v3.test.mjs -> node --test exit 1, 6 fail (T1-T5 parity + permutation law), restore -> exit 0, 10 pass | remaining: none — merge; on merge with 036 add episode table rows to the fixture document |