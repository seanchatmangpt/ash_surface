# gapfix-blob-purge-016: purge 65MB erl_crash.dump from history + gitignore (OPERATOR-GATED)
status: OPEN — BLOCKED on operator authority (history rewrite before first push)
created: 2026-09-17T05:30:00Z
## Mission
65MB erl_crash.dump tracked at HEAD (blob c0510a0f, entered d57ed66, dominates object store; uncovered by .gitignore; every fresh clone ships it). Branch is UNPUSHED (origin 207 behind) — purge is cheap NOW, permanent after first push. PREPARE only: .gitignore entry + the exact filter-repo/refile command sequence in this ticket; EXECUTE only on explicit operator authority (history rewrite = consequential DO). Soft-order: execute before any push ticket.
## Acceptance
- .gitignore covers *.dump/erl_crash.dump; purge command sequence reviewed and ready; execution awaits operator cut (record it here when given).
## History
