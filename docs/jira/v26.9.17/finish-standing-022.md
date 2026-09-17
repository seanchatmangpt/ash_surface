# finish-standing-022: F3 — one canonical standing vocabulary + constructor validation
status: OPEN
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F3: single lib owner of {ALIVE, PARTIAL_ALIVE, BLOCKED, BUILD_BROKEN, UNSUPPORTED}; runtime-validate Observation standing (caller-asserted :ALIVE today), PlanningEpisode standing AND ceiling (reject outside :SELECT|:CONSTRUCT, not just :DO), Event subject/type; JS z.string()→z.enum() for standing + REFUSED_-prefix guard.
## Acceptance
- one vocabulary owner; constructors refuse unvalidated standing/ceiling; zod enum; mix test 0; npm test 0.
## History
