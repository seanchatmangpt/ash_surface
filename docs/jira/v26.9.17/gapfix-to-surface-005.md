# gapfix-to-surface-005: to_surface/1 mixed-node law
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
Projector.IR.to_surface/1 (ir.ex:177) silently discards the non-surface remainder on success, contradicting PROJECTORS.md:44-47 ("foreign nodes refused"); mixed case untested. Either implement documented refusal ({:error, typed}) or correct the doc to honest pruning — whichever the wave law favors — and add the mixed-case test either way.
## Acceptance
- code and doc state the same law; mixed-input test pins it; mix test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g05 + exp/gapfix-to-surface-005 | dispatched by rider (run1, target_n=9)
2026-09-16T23:40:22Z | REAPED: agent dead (worktree silent >20min), reopened; cause unknown (no [1302] receipt visible); 1 commit(s) preserved on exp/gapfix-to-surface-005 — successor agent: review branch git log + status before redoing
2026-09-16T23:41:27Z | RECONCILED: run3's REAP was a false positive — agent completed post-reap (worktree silent in pruned dirs + thinking time only); branch copy @022429e is authoritative: DONE, gates mix 727/0 + npm 217/0 + format/compile 0, refusal law {:foreign_ir, nodes} + 2 mixed-case tests
