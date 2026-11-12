# AshSurface playground

Separate Phoenix mix project (own `mix.exs`, `mix.lock`, `package.json`). It depends on the
parent as `{:ash_surface, path: ".."}` and is not referenced by the root `mix.exs`, root
`package.json` or any root test glob.

Compile-and-validate only: ash_surface never actuates and emits no `.ts`/`.d.ts`. No Ash
action is executed and no backend is called.

## What it shows

1. Resource/action list from the reused fixture domain `AshSurface.ZodFixtures.*`
   (`shared/zod_fixtures.ex` is a symlink to `../test/support/zod_fixtures.ex`).
2. Compiled IR contract JSON (`AshSurface.Compiler` + `AshSurface.IR.Codec.to_map/1`).
3. Emitted Zod schema source (`AshSurface.Projectors.JS`, the `.mjs` text).
4. Payload editor: validates against the emitted schemas in the browser with real zod
   (bundled by bun), showing typed issues (path, code, message).

UI stack: `phoenix_react_server` (SSR via `renderToString`, bun runtime) plus
`hydrateRoot` in `assets/client.jsx`.

## Run

Requires Elixir, bun on PATH.

```sh
cd playground
mix setup        # deps.get, bun install, bundle browser + react SSR assets
mix phx.server   # http://127.0.0.1:4100
mix test         # bundles assets, then ExUnit (+ bun test with real zod)
```

Use `MIX_BUILD_ROOT=_build-pg` to keep the build out of the default `_build`.

## Layout

- `lib/playground/surface.ex` compile pipeline (pure, memoised)
- `lib/playground_web/` endpoint, router, `PageController` (SSR + document)
- `assets/component/surface_playground.jsx` shared SSR/hydrate component
- `assets/validate.mjs` loads the emitted artifact as a module bound to bundled zod
- `assets/test/` bun tests and a browser-less live check (`live_check.mjs <base-url>`)

## See Also

[AGENTS.md](AGENTS.md) - [../AGENTS.md](../AGENTS.md)
