# gapfix-aria-calver-002: aria projector CalVer + projector-header version coverage
status: IN_PROGRESS
created: 2026-09-17T05:30:00Z
## Mission
lib/ash_surface/projectors/aria.ex:45 carries @calver "26.9.15" (one release behind, emitted at :108, frozen at aria_projector_test.exs:18,109; invisible to bump mechanisms — not in TEXT_FILES, value ≠ OLD). Fix through the bump mechanism only: extend TEXT_FILES with aria.ex, re-freeze goldens through the real pipeline, and add projector-CalVer coverage to version_sync_test.exs + a drift-scan rule so any projector header diverging from @version fails closed.
## Acceptance
- aria.ex @calver == mix.exs @version; goldens regenerated via real pipeline; version_sync + drift scan prove no projector header can diverge silently; mix test 0; npm test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g02 + exp/gapfix-aria-calver-002 | dispatched by rider (run1, target_n=9)
