# gapfix-do-tripwire-006: no-local-DO tripwire scope repair
status: OPEN
created: 2026-09-17T05:30:00Z
## Mission
no_local_do_test.exs:27-30 excludes lib/ash_surface.ex claiming its fix "travels on branch c6744cb" — false: c6744cb is an ancestor of HEAD and the envelope reads delegated facts (lib/ash_surface.ex:154-164). Remove the stale exclusion; bring the root envelope under the tripwire; keep the suite green. Also extend refactor_safety_net canary coverage to the ~30 post-merge law suites it currently omits (add paths that exist at HEAD).
## Acceptance
- tripwire walks lib/ash_surface.ex; no false scope notes remain; canary pins the post-merge suites; mix test 0.
## History
