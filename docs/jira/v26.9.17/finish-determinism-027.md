# finish-determinism-027: F8 — re-point determinism suite at canonical IR
status: DONE
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F8 (falsified-claim correction): projector_ir_determinism_test.exs drives stale test-local IR/Projector doubles while lib/ash_surface/ir.ex and projector/ir.ex exist canonically; re-point the suite at the canonical modules (doubles only where injection is the law); retire the stale "ir.ex does not exist yet" moduledoc at event_projection.ex:16 en route.
## Acceptance
- suite exercises canonical modules; no stale existence claims; mix test 0.
## History
2026-09-17T03:42:41Z | ALIVE | exp/finish-determinism-027 @ aa2ddc4 | mix compile --warnings-as-errors=0; mix test=0 (793 passed/0 failed, 5 doctests); npm test=0 (245/0) | none — suite re-pointed at canonical IR modules, shadow doubles retired, stale existence claim retired at event_projection.ex; F1 follow-up: promote the sorted-key canonical-JSON encoder (test-local CanonicalJson) into lib.
