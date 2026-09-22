# Cleanup and Merge Plan: ash_surface

## Current State (as observed 2026-09-17)

Evidence gathered via real git/du commands against `/Users/sac/ash_surface` and every worktree under `/Users/sac/ash-surface-wt/`. `/Users/sac/ash-surface-wt` is **not** an independent repo or clone — `git -C /Users/sac/ash-surface-wt rev-parse --is-inside-work-tree` returns `fatal: not a git repository`. It is a plain container directory holding 30 `git worktree`-registered checkouts of the single canonical repo `/Users/sac/ash_surface` (confirmed by `git worktree list` from inside `ash_surface`, which enumerates all 31 paths including itself).

| Path | Type | Branch | Git status | Last commit (date) | Size |
|---|---|---|---|---|---|
| `/Users/sac/ash_surface` | **canonical repo** | `feat/dfcm-surface-core` | clean (`git status --short` empty) | `158d028` 2026-09-17 "docs(jira): 7 status artifacts corrected — wave ledger now truthful" | 195M |
| `/Users/sac/ash-surface-wt/g07` | worktree | `exp/gapfix-bump-mech-007` | clean | `aba5636` 2026-09-16 | 151M |
| `/Users/sac/ash-surface-wt/g13` | worktree | `exp/gapfix-docs-truth-013` | clean | `61f0024` 2026-09-16 | 151M |
| `/Users/sac/ash-surface-wt/g15` | worktree | `exp/gapfix-test-surface-015` | clean | `f6b143e` 2026-09-16 | 151M |
| `/Users/sac/ash-surface-wt/g17` | worktree | `exp/gapfix-ontology-promo-017` | clean | `69e57df` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g18` | worktree | `exp/gapfix-integration-018` | clean | `08a4fa1` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g26` | worktree | `exp/finish-paydown-026` | clean | `6e79bc4` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g28` | worktree | `exp/chicago-replay-state-28` | clean | `45f2a06` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g29` | worktree | `exp/chicago-standing-table-29` | clean | `ba184bc` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g30` | worktree | `exp/chicago-select-frontier-30` | clean | `71a642c` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g31` | worktree | `exp/chicago-episode-compose-31` | clean | `6f436e5` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g32` | worktree | `exp/chicago-intent-gate-32` | clean | `7b77e48` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g33` | worktree | `exp/chicago-formatter-retire-33` | clean | `d582fbb` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g34` | worktree | `exp/chicago-codec-canon-34` | clean | `7d6151c` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g35` | worktree | `exp/chicago-pathtruth-anchor-35` | clean | `6bfd2d1` 2026-09-17 | 102M |
| `/Users/sac/ash-surface-wt/g36` | worktree | `exp/chicago-episode-digest-36` | clean | `5859ada` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g37` | worktree | `exp/chicago-runtime-ledger-37` | clean | `611258d` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g38` | worktree | `exp/chicago-receipthash-38` | clean | `50b4010` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g39` | worktree | `exp/chicago-ontology-producer-39` | clean | `481d8e0` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g40` | worktree | `exp/chicago-moduledoc-sweep-40` | clean | `98ee222` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g41` | worktree | `exp/chicago-golden-mutation-41` | clean | `3857997` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g42` | worktree | `exp/chicago-props-codec-42` | clean | `9bee0e6` 2026-09-17 | 102M |
| `/Users/sac/ash-surface-wt/g43` | worktree | `exp/chicago-props-transport-43` | clean | `1934012` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g44` | worktree | `exp/chicago-e2e-loop-44` | clean | `4242fb2` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g45` | worktree | `exp/chicago-liveview-states-45` | clean | `2a2002e` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g46` | worktree | `exp/chicago-aria-states-46` | clean | `09e4326` 2026-09-17 | 102M |
| `/Users/sac/ash-surface-wt/g47` | worktree | `exp/chicago-voicekiosk-states-47` | clean | `4fd4635` 2026-09-16 | 102M |
| `/Users/sac/ash-surface-wt/g48` | worktree | `exp/chicago-zeroconfig-census-48` | clean | `21f6a9d` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g49` | worktree | `exp/chicago-ci-falsifier-49` | clean | `f311974` 2026-09-16 | 90M |
| `/Users/sac/ash-surface-wt/g50` | worktree | `exp/chicago-ledger-shrink2-50` | clean | `959f07b` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g51` | worktree | `exp/chicago-digest-parity-51` | clean | `e1f6e0d` 2026-09-17 | 90M |
| `/Users/sac/ash-surface-wt/g52` | worktree | `exp/chicago-doctest-sweep-52` | clean | `0cc2509` 2026-09-16 | 90M |

Totals: `du -sh` reports `/Users/sac/ash_surface` = 195M, `/Users/sac/ash-surface-wt` (all 30 worktrees combined) = 2.9G. Every worktree's `git status --short` returned zero lines — **no worktree in this family has uncommitted changes**.

The "deleted gemma manually" item is confirmed clear: `ls -d /Users/sac/*gemma*` returns no matches, so there is nothing left to reconcile there.

Other `ash_*` directories exist at `~/` (`ash_a2a`, `ash_a2a-wt`, `ash_autofde`, `ash_ex4pm`, `ash_expo`, `ash_kudzu`, `ash_planning_center`, `ash_pplan`, `ash_r2rml`) — these are **separate projects**, not part of the `ash_surface` family, and are out of scope for this plan (see Open Questions).

## What "merged" should look like

**Canonical path going forward: `/Users/sac/ash_surface` on branch `feat/dfcm-surface-core`.** Evidence:
- It is the repo every worktree in `ash-surface-wt/` was created from (`git worktree list` run from here lists all 31 paths as worktrees of this one `.git`).
- It has a remote configured: `origin https://github.com/seanchatmangpt/ash_surface.git` (fetch+push). None of the individual worktree checkouts are separate clones with their own remotes — they share this same `.git` via the worktree mechanism.
- Its branch `feat/dfcm-surface-core` is 479 commits ahead of `origin/feat/dfcm-surface-core` (`git rev-list --left-right --count origin/feat/dfcm-surface-core...feat/dfcm-surface-core` → `0 479`) and 0 commits behind — it is the most advanced copy of this branch anywhere, local or remote.
- Its working tree is clean and its last commit (`158d028`, 2026-09-17) is the most recent activity in the family.
- 27 of the 30 worktree branches are confirmed **already merged** into `feat/dfcm-surface-core` via `git merge-base --is-ancestor <branch> feat/dfcm-surface-core` (exit 0 = ancestor = merged): g13, g15, g17, g18, g28, g29, g30, g31, g32, g33, g34, g35, g36, g37, g38, g39, g40, g41, g42, g43, g44, g45, g46, g47, g48, g49, g51, g52.
- **3 worktree branches are NOT ancestors of `feat/dfcm-surface-core`** (`git merge-base --is-ancestor` exit 1) and each carries exactly the unique commit(s) shown below, per `git log <main>..<branch> --oneline`:
  - `exp/gapfix-bump-mech-007` (g07) — 2 unique commits: `25a4f25` "fix(bump): carrier/citation split + IR_GOLDEN regen family; execute 26.9.16 -> 26.9.17 bump" and `aba5636` "docs(jira): gapfix-bump-mech-007 DONE — carrier/citation split ALIVE at 25a4f25".
  - `exp/finish-paydown-026` (g26) — 1 unique commit: `6e79bc4` "docs(jira): finish-paydown-026 BLOCKED — pack-side paydown capability prepared + verified on marketplace branch; admission is the operator cut".
  - `exp/chicago-ledger-shrink2-50` (g50) — 1 unique commit: `959f07b` "style(test): mix format repair — formatter-version drift on two committed test files (chicago-ledger-shrink2-050 gate repair)".

For every OTHER path in the family:

- **27 fully-merged worktrees (g13, g15, g17, g18, g28–g49 minus g26, g50, plus g51, g52)** — no merge needed. Each is a clean `git worktree` of the canonical repo whose branch is already an ancestor of `feat/dfcm-surface-core`. Safe to run `git worktree remove` directly, then delete the now-orphaned local branch. No cherry-pick, no review gate.
- **g07 (`exp/gapfix-bump-mech-007`)** — has 2 unique commits not yet in `feat/dfcm-surface-core`. Before removal: cherry-pick (or verify already-superseded content of) `25a4f25` and `aba5636` into `feat/dfcm-surface-core`, or explicitly decide the version-bump work was abandoned/superseded and discard it. This is a MANUAL REVIEW step — do not auto-cherry-pick a version-bump commit without confirming it doesn't conflict with whatever bump state `feat/dfcm-surface-core` is already at.
- **g26 (`exp/finish-paydown-026`)** — has 1 unique commit, and that commit's own message says the work is **BLOCKED** ("admission is the operator cut"). MANUAL REVIEW required: confirm with the user whether this BLOCKED receipt should be merged as historical record or discarded, since it documents an unfinished/blocked capability rather than a landed change.
- **g50 (`exp/chicago-ledger-shrink2-50`)** — has 1 unique commit, a formatter/style-only repair to two already-committed test files. Lowest-risk of the three unmerged branches (pure formatting), but still MANUAL REVIEW before cherry-pick since it's not yet verified against current `feat/dfcm-surface-core` HEAD.

## Commands to run (in order), once approved

```bash
# 1. Remove the 27 already-merged worktrees (each verified: clean status + branch is
#    an ancestor of feat/dfcm-surface-core). Safe, no data loss -- run from the canonical repo.
cd /Users/sac/ash_surface
for wt in g13 g15 g17 g18 g28 g29 g30 g31 g32 g33 g34 g35 g36 g37 g38 g39 g40 g41 g42 g43 g44 g45 g46 g47 g48 g49 g51 g52; do
  git worktree remove "/Users/sac/ash-surface-wt/$wt"
done

# 2. Delete the now-orphaned local branches for those 27 (already merged, safe to delete with -d
#    which refuses if NOT actually merged -- this is itself a second safety check).
for b in exp/gapfix-docs-truth-013 exp/gapfix-test-surface-015 exp/gapfix-ontology-promo-017 \
         exp/gapfix-integration-018 exp/chicago-replay-state-28 exp/chicago-standing-table-29 \
         exp/chicago-select-frontier-30 exp/chicago-episode-compose-31 exp/chicago-intent-gate-32 \
         exp/chicago-formatter-retire-33 exp/chicago-codec-canon-34 exp/chicago-pathtruth-anchor-35 \
         exp/chicago-episode-digest-36 exp/chicago-runtime-ledger-37 exp/chicago-receipthash-38 \
         exp/chicago-ontology-producer-39 exp/chicago-moduledoc-sweep-40 exp/chicago-golden-mutation-41 \
         exp/chicago-props-codec-42 exp/chicago-props-transport-43 exp/chicago-e2e-loop-44 \
         exp/chicago-liveview-states-45 exp/chicago-aria-states-46 exp/chicago-voicekiosk-states-47 \
         exp/chicago-zeroconfig-census-48 exp/chicago-ci-falsifier-49 exp/chicago-digest-parity-51 \
         exp/chicago-doctest-sweep-52; do
  git branch -d "$b"
done

# 3. MANUAL REVIEW REQUIRED -- g07 (exp/gapfix-bump-mech-007): 2 unique commits not in
#    feat/dfcm-surface-core. Review whether 25a4f25 / aba5636 are still needed, then either:
#      cd /Users/sac/ash_surface && git checkout feat/dfcm-surface-core && \
#        git cherry-pick 25a4f25 aba5636
#    or decide to discard. Do NOT run git worktree remove on g07 until this is resolved.

# 4. MANUAL REVIEW REQUIRED -- g26 (exp/finish-paydown-026): 1 unique commit, self-described
#    as BLOCKED. Confirm with user whether to cherry-pick 6e79bc4 as historical record or
#    discard the branch entirely. Do NOT run git worktree remove on g26 until resolved.

# 5. MANUAL REVIEW REQUIRED -- g50 (exp/chicago-ledger-shrink2-50): 1 unique commit
#    (formatter-only fix). Review, then either:
#      cd /Users/sac/ash_surface && git checkout feat/dfcm-surface-core && \
#        git cherry-pick 959f07b
#    or discard. Do NOT run git worktree remove on g50 until resolved.

# 6. After g07/g26/g50 are each resolved (cherry-picked-and-verified, or explicitly discarded),
#    remove their worktrees and branches the same way as step 1/2:
#      git worktree remove /Users/sac/ash-surface-wt/g07   # after review
#      git worktree remove /Users/sac/ash-surface-wt/g26   # after review
#      git worktree remove /Users/sac/ash-surface-wt/g50   # after review
#      git branch -D exp/gapfix-bump-mech-007 exp/finish-paydown-026 exp/chicago-ledger-shrink2-50
#      # (-D not -d here since these branches, once cherry-picked rather than merged as-is,
#      #  will not show as ancestors even after their content is safely preserved elsewhere)

# 7. Once all 30 worktrees are removed, the container directory should be empty; confirm and
#    remove it.
rmdir /Users/sac/ash-surface-wt   # only succeeds if truly empty; safe no-op otherwise

# 8. Canonical repo is 479 commits ahead of origin -- push to bring the remote in sync
#    (separate, higher-stakes step; confirm branch name / force-with-lease policy before running).
cd /Users/sac/ash_surface
git push origin feat/dfcm-surface-core
```

## Open questions

- **g07, g26, g50 disposition**: cannot determine from git alone whether the 3 unique commits on these branches represent intentional work still wanted (cherry-pick) or abandoned/superseded experiments (discard). In particular g26's own commit message says "BLOCKED" — is a blocked-work receipt something that belongs in the canonical branch's history at all, or should it stay parked/discarded? Ask the user.
- **Remote is 479 commits behind local `feat/dfcm-surface-core`**: not clear from git alone whether that's expected (local-only work in progress, intentionally not pushed yet) or an oversight. Ask the user before running the `git push` in step 8.
- **`origin/main` vs `feat/dfcm-surface-core`**: this repo's default branch per `origin/HEAD -> origin/main` is `main`, but all real work observed lives on `feat/dfcm-surface-core`, which is checked out in the canonical working copy. Whether/when `feat/dfcm-surface-core` should be merged into `main` upstream is a project decision outside the scope of this cleanup, not determinable from local git state alone.
- **Sibling `ash_*` directories** (`ash_a2a`, `ash_a2a-wt`, `ash_autofde`, `ash_ex4pm`, `ash_expo`, `ash_kudzu`, `ash_planning_center`, `ash_pplan`, `ash_r2rml`) were noticed at `~/` during this investigation but were explicitly out of scope (the task named only `ash_surface` + `ash-surface-wt`). If the user's broader "~/ worktrees temps scratch etc" cleanup intent extends to these, each needs its own separate investigation of this same shape before a cleanup plan can be written for it.
- **Gemma**: user stated "deleted gemma manually" — confirmed via `ls -d /Users/sac/*gemma*` (no matches). No action needed; noted here only for completeness of the "what's already handled" record.

## Merge Execution Log (2026-09-17)

Content-level evaluation and merging only — no deletion performed (worktrees, branches,
and the container directory are all still present exactly as this doc originally found
them; deletion is a separate pass per user instruction).

### Re-verification of current state before acting

Re-ran the doc's own investigation commands. Everything matched the table above **except
one thing that had changed since the doc was written**: `origin/feat/dfcm-surface-core`
had moved. `git fetch origin feat/dfcm-surface-core` pulled `d6aab14..78cbb84`, and
`git rev-list --left-right --count origin/feat/dfcm-surface-core...feat/dfcm-surface-core`
now read `1 479` (previously `0 479` — origin was a strict ancestor when the doc was
written; by execution time origin had one new commit, `78cbb84` "feat(accessibility):
observe WAI-ARIA surfaces through Playwright", not present on local, so a `git push` as
step 8 originally described would have been a non-fast-forward push, not a clean
fast-forward). g07/g26/g50 status (worktree clean, branches not ancestors) matched the
doc exactly.

### Actions taken (real commits, on canonical repo `/Users/sac/ash_surface`, branch
`feat/dfcm-surface-core`)

1. **Merged `origin/feat/dfcm-surface-core` into local `feat/dfcm-surface-core`** (real
   merge commit, not a rebase) to fold in the one commit only origin had, before pushing.
   - Merge commit: `c8121676` (`git log -1` shows full form `c812167...`; recorded here
     as printed by `git log --oneline`).
   - One real content conflict, in `ontology.ttl`: both HEAD and origin had appended
     distinct, non-overlapping content at end-of-file (HEAD: v26.9.16/v26.9.17 law rows
     for gapfix-ontology-promo-017 etc.; origin: WAI-ARIA/accessibility-observer RDF
     vocabulary classes for the new Playwright observer). Resolved by keeping **both**
     blocks in full sequence and removing only the `<<<<<<<`/`=======`/`>>>>>>>` markers
     — zero lines from either side discarded. `.github/workflows/ci.yml` auto-merged
     clean (additive job only). Verified via `git diff --cached --stat` before
     committing: 271 insertions, 0 deletions across 4 files — exactly origin's own
     commit content, confirming nothing local was overwritten.
   - Post-merge: `git rev-list --left-right --count origin/...` → `0 479` (branches now
     diverge-free relative to each other, local ahead by 479 real commits).

2. **Cherry-picked g26's unique commit** (`exp/finish-paydown-026`, commit `6e79bc4`)
   into `feat/dfcm-surface-core`.
   - New commit: `386135c` "docs(jira): cherry-pick finish-paydown-026 BLOCKED receipt
     from exp/finish-paydown-026 (g26)".
   - Rationale: the doc's open question was whether a BLOCKED-status receipt belongs in
     canonical history at all. This repo's own convention (visible in its immediately
     preceding commits, e.g. `158d028` "7 status artifacts corrected ... 050 BLOCKED")
     already treats BLOCKED as a legitimate, honestly-recorded terminal status alongside
     DONE — so recording this one is consistent with existing practice, not a new
     judgment call invented here. It documents real, verified work (a pack-side change
     prepared and gate-verified on a `ggen-marketplace` branch) blocked only on an
     operator-authorized merge+push this session has no standing to perform.
   - One real conflict in `docs/jira/v26.9.17/finish-paydown-026.md`: HEAD's `History`
     section had no entry at that point (blank), the incoming commit added one BLOCKED
     history line. Resolved by taking the incoming line — purely additive (2 insertions,
     0 deletions per `git diff --cached --stat`); nothing on HEAD was touched or removed.
   - `exp/finish-paydown-026` branch itself, and the `g26` worktree, are untouched
     (still present, still on their original commit) — the content is now captured in
     canonical history in addition to living on the branch, not instead of it.

3. **Investigated g07's unique commits and explicitly declined to cherry-pick them.**
   - `git cherry-pick --no-commit -n 25a4f25` (the first of g07's two unique commits, the
     version-bump-mechanism fix) produced **6 real content conflicts**: `HANDWRITTEN.md`,
     `docs/DEP_GRAPH.md`, `scripts/bump_version.sh`, `test/ash_surface/ir_codec_test.exs`,
     `test/ash_surface/mx_closed_loop_deep_test.exs`,
     `test/ash_surface/runtime_source_test.exs`.
   - Further check: g07's own copy of `mix.exs` (pre-bump-fix state) lacks the dialyzer
     config block, the `stream_data` dep, and the `dialyxir` dep that current HEAD's
     `mix.exs` already has — i.e. g07's branch point predates later mainline work, so its
     version-bump commit is not a clean additive delta on top of current HEAD; it would
     regress several golden/version-pinned test fixtures back to an older shape.
   - Per the hard constraint (do not force a merge you're not fully confident is safe and
     purely additive), this cherry-pick was **not performed**. The failed no-commit
     attempt was cleanly backed out with `git reset --merge HEAD` (not `--hard`, not
     `checkout -- <path>`; this only undoes the just-attempted, never-committed cherry-pick
     apply and does not discard any real committed history) — confirmed via
     `git status --short` showing a clean tree (only the pre-existing untracked plan doc)
     immediately after.
   - `g07`'s second unique commit (`aba5636`, docs-only) was not attempted in isolation
     since it is a receipt *about* `25a4f25`'s effect and would be misleading recorded
     without the code change it describes.
   - `exp/gapfix-bump-mech-007` branch and the `g07` worktree are untouched — the 2 unique
     commits remain exactly where they were, fully intact and recoverable.

4. **Checked g50's unique commit for redundancy before attempting a cherry-pick.**
   - `git cherry-pick --no-commit -n 959f07b` (the formatter-only fix to
     `test/ash_surface/mx_episode_compose_test.exs` and
     `test/ash_surface/projector_ir_determinism_test.exs`) applied with **exit 0 and
     produced zero diff** against HEAD (`git diff HEAD --stat` empty). Confirmed directly
     with `git diff HEAD 959f07b -- <both files>` — also empty.
   - Conclusion: this content is **already present, byte-identical, on
     `feat/dfcm-surface-core`** (independently landed via a different, already-merged
     commit in the 479-commit history this branch accumulated). No commit was made
     (there was nothing to commit) and no content was lost — the same bytes exist in
     both places.
   - `exp/chicago-ledger-shrink2-50` branch and the `g50` worktree are untouched.

5. **Pushed the updated `feat/dfcm-surface-core` to `origin`** (same remote, same
   branch, ordinary fast-forward push — no force, no `--force-with-lease`):
   ```
   git push origin feat/dfcm-surface-core
   ```
   Result: `78cbb84..386135c  feat/dfcm-surface-core -> feat/dfcm-surface-core` — accepted
   as a fast-forward (possible only because step 1's merge had already folded in origin's
   one commit first). GitHub emitted an advisory (not an error) about a 62.18 MB
   `erl_crash.dump` file already tracked in history exceeding its recommended 50 MB
   size — informational only, push succeeded; flagged here for the separate cleanup pass
   since it's a large tracked binary crash-dump artifact, not something this task's scope
   covers removing.
   - Post-push verification: `git status --short` → only the pre-existing untracked plan
     doc; `git rev-list --left-right --count origin/feat/dfcm-surface-core...HEAD` → `0 0`
     (local and origin now identical).

### Real commit SHAs produced this session

- `c8121676...` (printed as `c812167` by `--oneline`) — merge of
  `origin/feat/dfcm-surface-core` (WAI-ARIA accessibility observer) into
  `feat/dfcm-surface-core`.
- `386135cbef8b1de78f19cca8095552aaab39a27c` — cherry-pick of g26's BLOCKED receipt
  (`6e79bc4`) onto `feat/dfcm-surface-core`.

No `git subtree add` was performed: nothing in this family is an independent-history
repo with no shared ancestry (every worktree here shares `ash_surface`'s single `.git`
via the native `git worktree` mechanism), so the subtree-import path in this task's hard
constraints does not apply to `ash_surface`/`ash-surface-wt`.

### What remains open

- **g07 (`exp/gapfix-bump-mech-007`, worktree `g07`)**: 2 unique commits
  (`25a4f25`, `aba5636`) NOT merged — real conflicts against current HEAD, and the
  branch's base state predates dialyzer/stream_data config already on mainline. A human
  needs to decide: (a) the version-bump-mechanism improvement in `25a4f25` was superseded
  by later mainline work and should be treated as abandoned (safe to leave un-merged,
  then safe to remove branch+worktree in the separate deletion pass), or (b) some part of
  its carrier/citation-classification logic in `scripts/bump_version.sh` is still wanted
  and needs a fresh, manually-reconciled cherry-pick against current HEAD (not a
  mechanical one — the 6 conflicting files need line-by-line reconciliation). Nothing
  was discarded; the branch and worktree are exactly as found.
- **origin/main vs feat/dfcm-surface-core**: unchanged from the original doc — still an
  open project decision outside this task's scope.
- **Sibling `ash_*` directories** (`ash_a2a`, `ash_a2a-wt`, `ash_autofde`, `ash_ex4pm`,
  `ash_expo`, `ash_kudzu`, `ash_planning_center`, `ash_pplan`, `ash_r2rml`): still
  unexamined, still out of scope per the original doc.
- **Now safe to delete, once a human confirms** (for the separate deletion pass — NOT
  performed here):
  - All 27 already-merged worktrees/branches listed in the original doc's step 1/2
    (g13, g15, g17, g18, g28–g49 except g26/g50, plus g51, g52) — unchanged, still safe
    exactly as the original doc assessed.
  - `g50` worktree + branch `exp/chicago-ledger-shrink2-50` — its one unique commit's
    content is confirmed byte-identical to what's already on `feat/dfcm-surface-core`;
    removing this worktree/branch would lose nothing.
  - `g26` worktree + branch `exp/finish-paydown-026` — its unique commit is now also
    captured on `feat/dfcm-surface-core` (commit `386135c`); removing this worktree/
    branch would lose nothing (the receipt survives in canonical history either way).
  - `g07` worktree + branch `exp/gapfix-bump-mech-007` — **NOT yet safe to delete**: its
    2 unique commits are not captured anywhere else. Deletion should wait for the human
    decision above.
  - The 62.18 MB `erl_crash.dump` file flagged by GitHub during the push (tracked in
    repo history) — a candidate for the separate cleanup pass to evaluate, not addressed
    here.
