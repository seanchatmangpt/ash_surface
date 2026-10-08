# finish-standing-022: F3 — one canonical standing vocabulary + constructor validation
status: DONE
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F3: single lib owner of {ALIVE, PARTIAL_ALIVE, BLOCKED, BUILD_BROKEN, UNSUPPORTED}; runtime-validate Observation standing (caller-asserted :ALIVE today), PlanningEpisode standing AND ceiling (reject outside :SELECT|:CONSTRUCT, not just :DO), Event subject/type; JS z.string()→z.enum() for standing + REFUSED_-prefix guard.
## Acceptance
- one vocabulary owner; constructors refuse unvalidated standing/ceiling; zod enum; mix test 0; npm test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g22 + exp/finish-standing-022 | dispatched by rider (F-wave, target_n=11)
2026-09-17T03:43:15Z | DONE | exp/finish-standing-022 @ 832b345 (parent ebd38ff) | compile --warnings-as-errors=0; mix test=0 (807 passed, 5 doctests; baseline 794); npm test=0 (253; baseline 245); mix format --check-formatted=0; node --check=0; mix dialyzer=0 (0 errors); capacity_gate=0; zero_config_check=0 | remaining: merge via rider; F4-F8 open; no standing-vocab debt remains (AshSurface.Standing owns {ALIVE,PARTIAL_ALIVE,BLOCKED,BUILD_BROKEN,UNSUPPORTED}+REFUSED class; Observation/PlanningEpisode/Event constructors validate; JS z.enum(STANDING_VALUES)+REFUSED_ prefix guard; fixtures re-vocabularied; runtime golden re-frozen @ 79bfdc03)
2026-09-17T03:49:08Z | MERGED 5e7663c + repair (rider): --no-ff exp/finish-standing-022 (F3); union repair (from_receipt closure); golden union-re-frozen 8373790c (F3+F6 runtime); landed mix 842/0, npm 258/0
2026-09-17T04:01:10Z | status-corrected by rider (5 artifacts); INCIDENT recorded: F3-merge repair was formatted post-commit and left uncommitted — HEAD was briefly red while the working tree gated 842/0; fixed+committed, lesson: gates run against committed state
