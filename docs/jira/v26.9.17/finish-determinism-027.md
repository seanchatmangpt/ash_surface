# finish-determinism-027: F8 — re-point determinism suite at canonical IR
status: IN_PROGRESS
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F8 (falsified-claim correction): projector_ir_determinism_test.exs drives stale test-local IR/Projector doubles while lib/ash_surface/ir.ex and projector/ir.ex exist canonically; re-point the suite at the canonical modules (doubles only where injection is the law); retire the stale "ir.ex does not exist yet" moduledoc at event_projection.ex:16 en route.
## Acceptance
- suite exercises canonical modules; no stale existence claims; mix test 0.
## History
2026-09-17T03:19:35Z | IN_PROGRESS | ~/ash-surface-wt/g27 + exp/finish-determinism-027 | dispatched by rider (F-wave run2, target_n=12)
