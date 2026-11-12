import Config

config :ash, default_string_length_count: :codepoints

config :playground, PlaygroundWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4100],
  server: false,
  secret_key_base: String.duplicate("playground-local-dev-only-", 4),
  render_errors: [formats: [html: PlaygroundWeb.ErrorHTML], layout: false]

config :phoenix, :json_library, Jason

config :phoenix_react_server, Phoenix.React,
  runtime: Phoenix.React.Runtime.Bun,
  component_base: Path.expand("../assets/component", __DIR__),
  cache_ttl: 60

config :phoenix_react_server, Phoenix.React.Runtime.Bun,
  cd: Path.expand("..", __DIR__),
  cmd: System.find_executable("bun"),
  server_js: Path.expand("../priv/react/server.js", __DIR__),
  port: 5225,
  env: :prod

import_config "#{config_env()}.exs"
