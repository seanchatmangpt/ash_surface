# gapfix-to-surface-005: to_surface/1 mixed-node law
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
Projector.IR.to_surface/1 (ir.ex:177) silently discards the non-surface remainder on success, contradicting PROJECTORS.md:44-47 ("foreign nodes refused"); mixed case untested. Either implement documented refusal ({:error, typed}) or correct the doc to honest pruning — whichever the wave law favors — and add the mixed-case test either way.
## Acceptance
- code and doc state the same law; mixed-input test pins it; mix test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g05 + exp/gapfix-to-surface-005 | dispatched by rider (run1, target_n=9) — dispatch row reconciled from main-checkout copy; this branch's copy was empty at open
2026-09-16T23:41:10Z | DONE | exp/gapfix-to-surface-005 @ e447ff4 | mix format --check-formatted 0; mix compile --warnings-as-errors 0; mix test 727 passed/0 fail, exit 0 (incl. 2 new mixed-case tests); npm test 217 passed/0 fail, exit 0 | none
