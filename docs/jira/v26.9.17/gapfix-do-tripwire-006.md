# gapfix-do-tripwire-006: no-local-DO tripwire scope repair
status: DONE
created: 2026-09-17T05:30:00Z
## Mission
no_local_do_test.exs:27-30 excludes lib/ash_surface.ex claiming its fix "travels on branch c6744cb" — false: c6744cb is an ancestor of HEAD and the envelope reads delegated facts (lib/ash_surface.ex:154-164). Remove the stale exclusion; bring the root envelope under the tripwire; keep the suite green. Also extend refactor_safety_net canary coverage to the ~30 post-merge law suites it currently omits (add paths that exist at HEAD).
## Acceptance
- tripwire walks lib/ash_surface.ex; no false scope notes remain; canary pins the post-merge suites; mix test 0.
## History
2026-09-16T22:29:52Z | IN_PROGRESS | ~/ash-surface-wt/g06 + exp/gapfix-do-tripwire-006 | dispatched by rider (run1, target_n=9)
2026-09-16T23:48:36Z | DONE | exp/gapfix-do-tripwire-006 @ 3fa7918 (fix) + 3de43e9 (this ledger, branch copy) | premise verified (c6744cb ancestor of HEAD, envelope reads delegated facts via IR.delegated/2); tripwire walks lib/ash_surface.ex (stale SCOPE NOTE removed, envelope pinned explicitly, walk-is-real guard added); canary canon 8→41 pins (33 post-merge law suites, all exist at HEAD); falsifiers ALIVE: injected doAuthority default in envelope → tripwire 4/5 firing on lib/ash_surface.ex, restored → 5/5; renamed ir_codec_golden away → canary "integration dropped ir_codec_golden", restored → 42/42; gates exit 0: mix compile --warnings-as-errors, mix test 758/758, npm test 217/217, mix format --check-formatted | none — ticket complete
