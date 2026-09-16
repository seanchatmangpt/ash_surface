# scripts/

## zero_config_check.sh — the fresh-clone proof

`bash scripts/zero_config_check.sh` proves the **zero-config** property of this
repository: a brand-new clone of the worktree's current HEAD, given nothing but
`PATH` and `HOME`, installs its own dependencies and passes its full gate.

### What it does

1. **Hermetic guard** — re-execs itself through
   `env -i PATH="$PATH" HOME="$HOME" ZERO_CONFIG_SANITIZED=1`, so no caller
   configuration (`MIX_ENV`, `HEX_*`, `NPM_CONFIG_*`, `ASDF_*`, ...) can leak
   into the proof. The only extra variable is the recursion sentinel itself.
2. **Local clone** — `git clone <worktree-path>` into a `mktemp -d` temp dir.
   Git never touches the network; the cloned HEAD is asserted equal to the
   worktree HEAD (the clone must be *this* tree, not the default branch).
3. **Gate, in order** — inside the clone:
   - `mix deps.get`
   - `npm install --no-audit` — **must precede `mix test`**: two mix e2e
     tests (`consumer_fixture_test.exs`, `mx_closed_loop_episode_test.exs`)
     shell out to node and import `zod` from `node_modules`; on a fresh
     clone without it, `mix test` fails. This dependency was discovered by
     this script's first hermetic run and is the documented bootstrap order.
   - `mix test`
   - `npm test`
4. **Verdict** — on the sole condition that every step exited 0, it prints a
   final line `ZERO_CONFIG_OK` and exits 0. Any failing command trips
   `set -Eeuo pipefail` + an ERR trap, prints `ZERO_CONFIG_FAIL: ...` with the
   command and exit code, and exits non-zero **before** the OK line can be
   printed — the line is unfalsifiable by construction.
5. **Cleanup** — an EXIT trap removes the temp dir.

### Offline policy

Zero-config ≠ offline. The git clone is local. `mix deps.get` and
`npm install` consult Hex/npm, which may use the network unless the user-level
caches under `$HOME` (`~/.hex`, `~/.npm`) are warm. In a genuinely offline
environment those two steps may fail with network errors; that is a *network
blocker*, not a zero-config failure. The script intentionally does **not**
auto-skip on network errors — it cannot print a false `ZERO_CONFIG_OK`. Record
the exact blocker in the session receipt and rerun with network access or warm
caches.

### Exit codes

| Exit | Meaning                                              |
|------|------------------------------------------------------|
| 0    | Proof holds; `ZERO_CONFIG_OK` printed                |
| other| A gate step failed (or the clone-HEAD assertion failed); `ZERO_CONFIG_FAIL: command failed (exit N): <cmd>` printed |
