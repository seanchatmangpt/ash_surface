# Wave 3 CAC: skeptic audit of TestIndex tags and CourtMap excludes

Standing: PARTIAL

Subject: lib/ash_surface/parity/test_index.ex + court_map.ex (excluded_tags/1, excluded_test?/3).
Method: real ExUnit-shaped files under /tmp/cac run through `TestIndex.analyze/2` and
`CourtMap.excluded_tags/1` via `MIX_BUILD_ROOT=_build-cac mix run` (exit 0).

## False-pass (excluded court reads as pass)

- `ExUnit.start(exclude: Application.get_env(:x, :ex, [:slow]))` -> excluded_tags = [].
- `exclude: ~w(slow)a` -> [].
- `--only`/`--exclude` CLI flags: never read. mix.exs has no such alias today (latent).

## False-broken (hard EXCLUDED on a runnable court)

- `configure(exclude: [:slow], include: [:slow])` -> ["slow"] (include ignored).
- `exclude: [slow: false]` -> ["slow"]; `exclude: [slow: true]` also hits `@tag slow: "x"`.
- `# exclude: [:ghost]` comment -> "ghost" (regex on raw text).
- Nested `defmodule Inner` with `@moduletag :nested`: outer test tags [slow, nested];
  Inner's tests inherit outer's `slow` (module_tags never scoped).
- `@tag :slow` before `describe`: applied to every test in the describe.
- Generated tests: `for n <- 1..2` yields ONE entry titled "gen \0"; macro `mk("macro one")`
  yields none -> court not found (miss).

## Clean

`@tag :skip`, `skip: "x"`, `skip: false`, `slow: false`, `@tag timeout: 100` with context,
`@describetag` (no leak past describe), kw `exclude: [slow: true]`, multi `exclude:` correct.
