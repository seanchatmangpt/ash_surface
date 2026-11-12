# Wave 3 playground receipt (lane PLAYGROUND)

Standing: PARTIAL_ALIVE

Subject: `playground/` (separate Phoenix project, `ash_surface` as `path: ".."`). Root
`mix.exs`, root `package.json`, `lib/` untouched. SHA not recorded (no git state commands run).

## Versions (observed)

- Phoenix 1.8.16, phoenix_react_server 0.7.3 (hex), Elixir 1.19.5 / OTP 28
- bun 1.4.2, React 19.2.0 + react-dom 19.2.0 (pinned in playground/package.json), zod 4.6.5
- React 19.x renders SSR through Phoenix.React under bun: yes (renderToString).

## Spike results

1. SSR: ALIVE. `Phoenix.React.render_to_string/2` against `priv/react/server.js` built by
   `mix phx.react.bun.bundle`. Note: README config key `Phoenix.ReactServer` is stale; the
   0.7.3 source uses `Phoenix.React` / `Phoenix.React.Runtime.Bun`, and hex ships no
   prebuilt server.js (bundle step required; the bundle task swallows errors, so mix.exs
   asserts the file exists).
2. Hydration (browser-less): ALIVE. `bun assets/test/live_check.mjs` against running
   `mix phx.server`: output `OK ssr markup + client.js(534195B) + zod.mjs`, rc=0.
   Real-browser hydration NOT verified (Chrome extension site permission blocked localhost).

## Commands and results

- `mix compile`, `mix phx.server` (MIX_BUILD_ROOT=_build-pg): rc 0 after retries; the shared
  checkout had a transient syntax error in another lane's
  `lib/ash_surface/runtime_parity/rpc/pipeline.ex` (compile-freeze, not ours).
- `mix test` (playground, final run): `5 tests, 0 failures` (SSR markup, artifact route,
  asset serving, contract route per action, bun test with real zod: 4 pass / 0 fail).
- Direct `bun test assets/test` without `ARTIFACT` env fails by design (refuses to skip).

## Reuse

Fixture domain `AshSurface.ZodFixtures.*` reused via symlink
`playground/shared/zod_fixtures.ex -> ../../test/support/zod_fixtures.ex`. Playground config
sets `config :ash, default_string_length_count: :codepoints` as the root config does.

## NOT verified

- In-browser execution of hydrateRoot and the Blob-module zod loader in a real browser (the
  same loader code is exercised under bun by `zod.test.mjs`; DOM hydration is not).
- Root `mix test` behavior unchanged: not re-run (no root files touched; playground is
  outside every root test glob).
- Standing line of each run is not SHA-bound. `_build-pg` deleted at end.
