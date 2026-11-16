import Config

config :ash, default_string_length_count: :codepoints

config :playground, PlaygroundWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4100],
  server: false,
  pubsub_server: Playground.PubSub,
  secret_key_base: String.duplicate("playground-local-dev-only-", 4),
  render_errors: [formats: [html: PlaygroundWeb.ErrorHTML], layout: false]

config :playground, ash_domains: [Playground.Blog],
  actor_resource: Playground.Blog.Author
config :playground, :ash_shadcn,
  domains: [Playground.Blog],
  actor_resource: Playground.Blog.Author

config :phoenix, :json_library, Jason

config :phoenix_react_server, Phoenix.React,
  runtime: Phoenix.React.Runtime.Bun,
  component_base: Path.expand("../assets/component", __DIR__),
  cache_ttl: 60

config :phoenix_react_server, Phoenix.React.Runtime.Bun,
  cd: Path.expand("..", __DIR__),
  cmd: System.find_executable("bun"),
  server_js: Path.expand("../priv/react/server.js", __DIR__),
  port: String.to_integer(System.get_env("REACT_PORT", "5225")),
  env: :prod

# lane:auth -- AshAuthentication accounts domain + dev-only JWT signing secret
config :playground, ash_domains: [Playground.Blog, Playground.Accounts]
config :playground, :token_signing_secret, "playground-dev-only-jwt-signing-secret-do-not-use-in-prod"

# lane:history -- Editorial domain (paper trail / archival / state machine demo)
config :playground,
  ash_domains: [Playground.Blog, Playground.Accounts, Playground.Editorial, Playground.Jobs]
config :playground, :ash_shadcn,
  domains: [Playground.Blog, Playground.Editorial, Playground.Jobs],
  actor_resource: Playground.Blog.Author

# lane:jobs -- SQLite-backed Oban (Lite engine) for AshOban triggers; db file lives under tmp/ (git-ignored).
config :playground, ecto_repos: [Playground.Repo]
config :playground, Playground.Repo,
  database:
    Path.expand(
      if(config_env() == :test,
        do: "../tmp/jobs_test_#{System.os_time(:millisecond)}_#{System.unique_integer([:positive])}.db",
        else: "../tmp/jobs_#{config_env()}.db"
      ),
      __DIR__
    ),
  pool_size: 5,
  busy_timeout: 5000,
  log: false

config :playground, Oban,
  engine: Oban.Engines.Lite,
  repo: Playground.Repo,
  queues: [default: 5],
  plugins: [{Oban.Plugins.Cron, []}],
  peer: Oban.Peers.Isolated,
  testing: if(config_env() == :test, do: :manual, else: :disabled)

# lane:workflow -- Ash.Reactor modules browsable/runnable in /admin/workflows
config :playground, :workflows, [
  Playground.Workflows.PublishPostWorkflow,
  Playground.Workflows.ModeratePostWorkflow
]

import_config "#{config_env()}.exs"
