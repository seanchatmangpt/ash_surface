# finish-experience-023: F4 — admit the experience hook (MXEpisode.compose/1)
status: IN_PROGRESS
created: 2026-09-17T04:30:00Z
## Mission
Per _SYNTHESIS.md F4: lib-level AshSurface.MXEpisode.compose/1 binding the already-content-addressed parts (observation digest, PlanningEpisode, MX receipt hash, Event, surface.digest, repo/head+CalVer) into the episode shape frozen at mx_closed_loop_episode_test.exs:151-177; vendor the mx-episode-schema verifier in-repo so the external check cannot fail-open-skip.
## Acceptance
- compose/1 produces schema-valid episodes; verifier runs in-repo (no external dep, no skip); round-trip test green; mix test 0.
## History
2026-09-17T03:10:00Z | IN_PROGRESS | ~/ash-surface-wt/g23 + exp/finish-experience-023 | dispatched by rider (F-wave, target_n=11)
