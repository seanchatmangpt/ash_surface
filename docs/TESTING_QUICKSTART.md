# Testing quickstart

```console
mix deps.get && mix test.all
```

That is the whole story: `mix test.all` runs the Elixir suite, then the JS suite (`npm test`), and fails if either fails.

- `mix test.zero` — `mix test.all` re-run under `env -i` (only `PATH`/`HOME` survive) to prove zero-config.
