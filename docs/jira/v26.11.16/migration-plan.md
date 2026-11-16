# ash_surface migration plan v26.11.16

Standing: UNVERIFIED

## Identity
- path: /Users/sac/ash_surface
- remote: https://github.com/seanchatmangpt/ash_surface.git
- branch@sha: main@e483e4f32, last commit 2026-11-12, 678 commits, 6116 MB
- languages/build: Elixir (mix.exs, mix.lock), JS/TS (package.json, playground/bun.lock),
  Justfile, ggen.toml/ontology.ttl (ggen-generated surfaces)
- nested repos: none

## Observed state
- dirty=10 `M`, all under playground/ (build.mjs, bun.lock, config/*.exs, mix.exs,
  mix.lock, package.json, lib/playground/application.ex, lib/playground_web/{endpoint,
  router}.ex)
- untracked=158: playground/lib (14), playground/test (11), playground/assets (7, incl.
  assets/admin/), playground/bin (1), 304_trial.mjs (root)
- ahead 0 / behind 0 on origin/main; stash 0
- 151 local branches; census says 146 unpushed (docs/*, exp/chicago-* lane branches)
- build dirs: _build/deps not present at root; tmp/ 1.1M. 6.1 GB size is NOT explained by
  visible build dirs -- likely .git objects or playground/node_modules; DECISION below
- erl_crash.dump present at root (should be deleted, not migrated)
- submodules: none

## What it is
Manifest-first consumer projection/runtime layer for Ash applications: turns
Ash.Info.Manifest into consumer-facing surfaces (TypeScript parity with ash_typescript,
Zod 4 port, A2A). Very active in November 2026.

## Classification
ACTIVE (census agrees; commits 4 days ago).

## Migration risk
HIGH. 158 untracked playground files + 10 modified playground files are uncommitted work.
146 local branches are unpushed (though many `exp/chicago-*` are tracked -- see
`git branch -vv`; the 146 figure is from census). No secrets observed at root.

## Recommended action
COMMIT-PUSH
1. `cd /Users/sac/ash_surface && git add playground 304_trial.mjs && \
   git commit -m "wip(playground): admin assets, router/endpoint changes (pre-migration)"`
2. `git push origin main`
3. Push every local branch: `git push --all origin` (DECISION: prune dead `exp/chicago-*`
   branches first, or push all and prune later -- recommend push all, it is cheap).
4. Find the 6 GB: `du -sh .git playground/node_modules playground/_build playground/deps`.
   Remove build dirs: `rm -rf playground/node_modules playground/_build playground/deps`
   `_build deps node_modules`. If .git is the bulk, `git gc --prune=now` is acceptable.
5. `rm erl_crash.dump`
6. Re-clone on the new machine; do not rsync the 6 GB tree.

## First commands on the new machine
`mix deps.get && mix compile --warnings-as-errors && mix test`; then
`cd playground && bun install && mix deps.get && mix test`

## See Also
- ../v26.11.12/
- /Users/sac/docs/jira/v26.11.16/README.md
