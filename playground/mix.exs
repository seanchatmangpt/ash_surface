defmodule Playground.MixProject do
  use Mix.Project

  def project do
    [
      app: :playground,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [mod: {Playground.Application, []}, extra_applications: [:logger]]
  end

  # The fixture Ash domain is REUSED by SYMLINK (shared/zod_fixtures.ex -> test/support)
  # (not copied): ../test/support/zod_fixtures.ex defines AshSurface.ZodFixtures.*
  defp elixirc_paths(_), do: ["lib", "shared"]

  defp deps do
    [
      {:ash_surface, path: ".."},
      {:phoenix, "~> 1.7"},
      {:phoenix_html, "~> 4.0"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.4"},
      {:phoenix_react_server, "~> 0.7"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", &bun_install/1, &bun_bundle/1],
      "assets.build": [&bun_bundle/1],
      test: [&bun_bundle/1, "test"]
    ]
  end

  defp bun_install(_), do: run!("bun", ["install"])
  # Browser bundles (client + zod) and the react SSR server bundle.
  defp bun_bundle(_) do
    run!("bun", ["run", "build"])
    Mix.Task.rerun("phx.react.bun.bundle", ~w(--component-base assets/component
      --output priv/react/server.js --cd .))
    unless File.exists?("priv/react/server.js"), do: Mix.raise("react server bundle missing")
  end

  defp run!(cmd, args) do
    {_, 0} = System.cmd(cmd, args, into: IO.stream(), stderr_to_stdout: true)
  end
end
