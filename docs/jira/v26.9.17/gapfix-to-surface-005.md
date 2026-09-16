# gapfix-to-surface-005: to_surface/1 mixed-node law
status: OPEN
created: 2026-09-17T05:30:00Z
## Mission
Projector.IR.to_surface/1 (ir.ex:177) silently discards the non-surface remainder on success, contradicting PROJECTORS.md:44-47 ("foreign nodes refused"); mixed case untested. Either implement documented refusal ({:error, typed}) or correct the doc to honest pruning — whichever the wave law favors — and add the mixed-case test either way.
## Acceptance
- code and doc state the same law; mixed-input test pins it; mix test 0.
## History
