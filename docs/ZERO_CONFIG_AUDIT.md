# Zero-config audit — ash_surface

Receipt for the `env -i` zero-config proof on this tree.

- Repo/worktree: `/Users/sac/ash-surface-wt/v24`
- Branch: `exp/v24` (base `282f3ca`, tree clean before this doc)
- Date: 2026-09-15
- Method: each battery command run under `env -i HOME="$HOME" PATH="$PATH" <cmd>` — no other
  environment variables (no `MIX_ENV`, no secrets, no API keys, no `DATABASE_URL`).

## Battery (mission order, every exit recorded)

| # | Command (under `env -i`, PATH/HOME only) | Exit | Evidence |
|---|---|---|---|
| 1 | `mix deps.get` | **0** | `All dependencies have been fetched` |
| 2 | `mix test` | **0** | `308 passed`, 0 failures, `Finished in 3.0 seconds` |
| 3 | `npm install` | **0** | `found 0 vulnerabilities` |
| 4 | `npm test` | **0** | `# tests 175 / # pass 175 / # fail 0` |
| 5 | `mix compile --warnings-as-errors` | **0** | clean compile, no warnings |

Gate: battery all 0 — met. No blockers to receipt.

## Env-coupling audit — `config/` and `test/`

Searched `config/` and `test/` (recursive) for `System.get_env`, `File.mkdir`, `File.cd`,
`DATABASE_URL`, `API_KEY`, `CODEX`, `OPENAI`, `ANTHROPIC`:

- `config/config.exs` — 3 lines, `import Config` + one `config :ash` entry. **Zero env reads.**
- `test/` — **zero** `System.get_env` / API-key / DB-URL references. Only filesystem coupling is
  five scratch dirs, all guarded and repo-relative:
  - `test/ash_surface/mx_closed_loop_episode_test.exs:22` — `Path.expand("../../_build/test/mx_closed_loop", __DIR__)`; `File.rm_rf!` + `File.mkdir_p!` in setup.
  - `test/ash_surface/mx_closed_loop_deep_test.exs:26` — `Path.join(@repo_root, "_build/test/mx_closed_loop_deep")`; `rm_rf!` + `mkdir_p!`.
  - `test/ash_surface/consumer_fixture_test.exs:10`, `test/ash_surface/projector/expo_test.exs:12`, `test/ash_surface/projector/expo_client_test.exs:26` — same pattern (`mkdir_p!` guards).
- No `MIX_ENV` coupling observed: `mix test` passes bare under `env -i`.
- `lib/` spot-check: no `get_env` hits — env-free core.

Conclusion: no missing-dir or env-var defects found; all scratch paths are created before use and
live under the repo's `_build/test/`, which the run itself creates.

## Test-infrastructure fixes

None required — the battery was already fully green under `env -i` on the current tree.
Smallest diff honored: zero product-code changes; this doc (+ its ledger row) is the only diff.

## Receipt (DfCM)

- Commands and exits: battery table above; pre-step `mix deps.get && npm install` in ambient env also 0/0.
- Ratio: this change delivers documentation only; 0 manufactured lines, 2 hand-written lines of
  ledger. No production/test code touched, so the code ratio is vacuously 1.0 (no delivered code lines).
- Ledger delta: +1 row in `HANDWRITTEN.md` (this audit doc; intended owner `ash-extension-core`
  doc-template emission, same paydown as `TESTING_QUICKSTART.md` — audit/receipt doc template).
- Standing deltas: none (no refusals, no blockers).
- Falsifiers attempted: `env -i` strip (would fail on any env coupling — it did not); warnings-as-errors
  compile (would fail on any latent warning — it did not); grep sweep for env/secret/dir coupling.
- Operator did not have to write: the battery runs, exit capture, env-coupling sweep, this audit
  receipt, and the commit — keystrokes confined to reviewing this receipt.
