# gapfix-intent-canon-004: single SurfaceIntent canon
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
Two self-declared canons: lib/ash_surface/intent.ex (id = full-hex sha256 over Jason.encode!([said, input, subject_ref]), intent.ex:54-57) vs the test-inline copy in intent_path_test.exs:18-66 (prefixed 16-hex over term_to_binary) which promised retirement once lib admitted the family. Retire the inline canon; re-point intent_path_test at the lib canon; if the prefixed-id shape is load-bearing anywhere, reconcile honestly (one identity law, ledgered).
## Acceptance
- exactly one intent_id law repo-wide (grep proves no second scheme); intent_path_test green against lib; mix test 0; npm test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g04 + exp/gapfix-intent-canon-004 | dispatched by rider (run1, target_n=9)
2026-09-16T23:40:22Z | REAPED: agent dead (worktree silent >20min), reopened; cause unknown (no [1302] receipt visible); 0 commit(s) preserved on exp/gapfix-intent-canon-004 — successor agent: review branch git log + status before redoing
2026-09-16T23:50:24Z | REAP-REVERTED: original agent still actively writing its worktree (freshness 6-15s at 23:50:24Z observation); run3's reap was a false positive; no successor dispatched — original retains ownership
2026-09-16T23:52:02Z | DONE | ~/ash-surface-wt/g04 + exp/gapfix-intent-canon-004 @ b4f6b3a | mix compile --warnings-as-errors EXIT 0; mix test EXIT 0 (725 passed, 0 failed); npm test EXIT 0 (217 pass, 0 fail); grep '"intent_"' repo-wide 0 hits, sole intent_id law = lib/ash_surface/intent.ex:54 | none — acceptance met (inline canon retired, path test green against lib, round-trip id derived through the lib law, ledgered in HANDWRITTEN.md)
