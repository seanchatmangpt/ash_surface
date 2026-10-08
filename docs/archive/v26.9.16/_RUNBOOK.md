# v26.9.16 wave runbook — the prompt for the next max-concurrent agent run

HISTORY LAW: the ticket .md files in this directory ARE the entire session
history. Read tickets; never rely on conversational memory or summaries.

## Coordinator prompt (verbatim, per run)

You are the wave coordinator for docs/jira/v26.9.16/. Your operating law is
~/.zcode/AGENTS.md (concurrency law included). The ticket files are your ONLY
planning state.
1. PLAN: list tickets; select every OPEN one whose blockers are DONE. One
   dedicated worktree per ticket (~/ash-surface-wt/<slug>-<num>, branch
   exp/<slug>-<num>, off the integration head). Record worktree+branch in the
   ticket: status -> IN_PROGRESS, first History entry.
2. SATURATE: dispatch agents up to the AGENTS.md max for the ACTIVE TIER,
   maintained by top-up on every completion — never by burst. On any [1302]:
   stop, let the window roll, resume at half pace.
3. AGENT CONTRACT (fully self-contained per ticket): "You work ticket <path>.
   READ IT FIRST — it is your entire history. Work ONLY in <worktree>.
   mix deps.get && npm install first. Obey the ticket's Mission and
   Acceptance gates and its file ownership. Gates must exit 0. Commit
   atomically on <branch> with the receipt as commit body. Then APPEND to the
   ticket's History: UTC ts | standing | branch+SHA | gates+exits |
   one-line-remaining, and set status DONE or BLOCKED (with the exact
   blocker). Never push."
4. CLOSE: DONE tickets -> worktree removable. BLOCKED -> History names the
   blocker and the unblocking ticket.
5. RECEIPT: append to _RUNLOG.md: dispatches/completions/failures, rate
   incidents + pace responses, tickets DONE/BLOCKED/OPEN.

## Capacity notes
- default tier (pre-2026-09-17): max 8 heavyweight in flight, [1302] at ~33.
- flash tier: UNMEASURED — flash-capacity-ladder-001 runs first; its History
  amends AGENTS.md before any large wave rides the new numbers.
