# gapfix-aria-calver-002: aria projector CalVer + projector-header version coverage
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
lib/ash_surface/projectors/aria.ex:45 carries @calver "26.9.15" (one release behind, emitted at :108, frozen at aria_projector_test.exs:18,109; invisible to bump mechanisms — not in TEXT_FILES, value ≠ OLD). Fix through the bump mechanism only: extend TEXT_FILES with aria.ex, re-freeze goldens through the real pipeline, and add projector-CalVer coverage to version_sync_test.exs + a drift-scan rule so any projector header diverging from @version fails closed.
## Acceptance
- aria.ex @calver == mix.exs @version; goldens regenerated via real pipeline; version_sync + drift scan prove no projector header can diverge silently; mix test 0; npm test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g02 + exp/gapfix-aria-calver-002 | dispatched by rider (run1, target_n=9) [canonical copy; replayed here by successor so the branch carries the record]
2026-09-16T23:40:22Z | REAPED: agent dead (worktree silent >20min), reopened; 0 commit(s) preserved — successor reviewed branch git log + status before redoing, per canonical note
2026-09-17T00:15:32Z | DONE | exp/gapfix-aria-calver-002 @ c810199 (base 1f57000, worktree g02) | falsifiers: projector_calver_law stale-tree exit 1 / post-repair 0, embedded generator 26.9.16->26.9.17 exit 0 (21 BUMPGEN lines incl. ARIA_GOLDEN, self-proofs byte-exact vs real Projectors.ARIA), diverged+removed header fail new tests, restored green; gates: mix format 0, mix compile --warnings-as-errors 0, mix test 729 passed exit 0, npm test 217 pass exit 0 | remaining: none — acceptance met; full bump --check run stays blocked by pre-existing 38-file handled-set drift owned by gapfix-bump-mech-007 (OPEN); fixture-input 26.9.15 in live_view/determinism tests out of header-law scope by design