# finish-classify-021: F2 — classify intent KNOWN-ness pre-bus
status: OPEN
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F2: Intent.Dispatch.submit/3 refuses action_id outside the admitted action set, typed, BEFORE the bus hand-off (Elixir mirror of generated JS REFUSED_UNKNOWN_ACTION); tripwire tests. Owner: lib/ash_surface/intent/dispatch.ex.
## Acceptance
- typed refusal fires pre-bus for out-of-set action_id; admitted set unchanged; mix test 0; npm test 0.
## History
