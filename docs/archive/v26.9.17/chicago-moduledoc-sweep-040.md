# chicago-moduledoc-sweep-040: stale-claim comment sweep + tripwire
status: DONE
created: 2026-09-17T06:30:00Z
## Mission
Mappers 05/14 residuals: lib/ carries transition/existence claims (pattern: 'does not exist yet', 'until X lands', 'on no branch'). Sweep every hit in lib/ — correct or prove-current; add a lightweight tripwire test grepping lib/ for the stale-claim patterns with an explicit allowlist of proven-current mentions.
## Definition of Done (Chicago school)
- State-based tests exercise the REAL subject — no test doubles for the unit under test (injected seams only where the law itself demands injection).
- Assertions on observable outcomes only: returned values, emitted artifacts, on-disk bytes, typed refusals — never internals (mock-call bookkeeping allowed solely where the law IS the boundary, e.g. bus-untouched proofs).
- EXECUTED falsifier in the ticket History: mutate the subject behavior, run the new tests, show RED, restore, show GREEN — commands + exits recorded.
- Gates exit 0: mix compile --warnings-as-errors; mix test; npm test (if JS touched); mix format --check-formatted.
## Acceptance
- sweep clean + tripwire green with allowlist; falsifier: add a stale claim -> tripwire RED (executed); gates 0.
## History
2026-09-17T05:49:05Z | IN_PROGRESS | ~/ash-surface-wt/g40 + exp/chicago-moduledoc-sweep-40 | dispatched by coordinator (chicago wave)
2026-09-17T05:56:53Z | REAPED: agent rate-killed [1302] (storm window); worktree g40 + branch preserved — successor reviews git log first
2026-09-17T06:24:09Z | IN_PROGRESS | successor re-dispatch (predecessor rate-killed; branch preserved — review git log first) | rider, operator cut, staggered cohorts
2026-09-17T06:58:00Z | DONE | ~/ash-surface-wt/g40 + exp/chicago-moduledoc-sweep-40 @ 98ee222 | gates: mix compile --warnings-as-errors exit 0; mix test exit 0 (845 passed: 5 doctests, 840 tests); mix format --check-formatted exit 0 (incl. HEAD-red repair of 2 pre-existing unformatted files, 3954d86/aa2ddc4); npm test n/a | falsifier executed: inject "does not exist yet" into lib/ash_surface/formatter.ex -> tripwire exit 2 RED (offender formatter.ex:25 named) -> git checkout restore -> exit 0 GREEN 3/3 | sweep: 3 stale claims corrected (intent.ex "ir.ex not yet admitted" -> admitted per gapfix-docs-truth-013; capability.ex x2 "ash_a2a test-env-only" -> all-env runtime:false per mix.exs:75-78); allowlist: projector/ir.ex:8 correction record (proven-current); tripwire greps real lib/ tree, self-probe per pattern, allowlist shrink-monotonic | remaining: none — merged-pending rider (not pushed, per ticket law)
2026-09-17T06:42:11Z | MERGED 412a0ea  (rider): --no-ff exp/chicago-moduledoc-sweep-40; stale-claim tripwire w/ self-probe + shrink-monotonic allowlist; falsifier named the exact offender
