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

## zero_config_v2.sh — the v2 full battery (ticket zero-config-battery-002)

`bash scripts/zero_config_v2.sh` is the v1 proof plus two additions, same
hermetic re-exec (`env -i PATH HOME`), same local-clone subject, same
no-false-OK failure semantics:

1. **env-read guard** (runs first, inside the clone) — fails if any file
   under `test/` reads an environment variable outside the documented
   allowlist. The allowlist is parsed from the clone's `mix.exs`
   (`@zero_env_allowlist`, currently `HOME PATH`) so the guard and the
   `mix test.zero` scrubber share one source of truth. Reads are
   `System.get_env` / `System.fetch_env!` with a **literal** variable
   name; a read whose variable name is not a literal (opaque read) fails
   closed. An unparsable allowlist also fails closed.
2. **`mix test.zero` if present** — detected by the `"test.zero":` alias
   definition in the clone's `mix.exs`; re-runs `mix test.all` (`mix test`
   then `npm test`) under literal `env -i` with only the allowlist
   surviving. If the alias is absent the step is skipped with exit 0.

Battery order: env-read guard, `mix deps.get`, `npm install --no-audit`
(before `mix test`, per v1's bootstrap-order discovery), `mix test`,
`npm test`, `mix test.zero`. Every step prints `EXIT[<label>]=<code>`
before the next one starts, so a run log records **every exit code**;
the final line is `ZERO_CONFIG_OK` only when all of them were 0.
