defmodule AshSurfaceZoe.MixProject do
  use Mix.Project

  # Versioned independently of ash_surface core (see README "Versioning").
  @version "0.1.0"
  @source_url "https://github.com/seanchatmangpt/ash_surface"

  def project do
    [
      app: :ash_surface_zoe,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "ZOE / DfCM devotional human-surface family for ash_surface",
      source_url: @source_url,
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger]]
  end

  # The core dependency is a path dependency while the package lives in the
  # ash_surface monorepo. Its transitive deps (ash, spark, ash_a2a, ...) come
  # from core's own mix.exs and mix.lock is regenerated here; ash/spark/jason
  # are restated at core's constraints so this package compiles on its own.
  defp deps do
    [
      {:ash_surface, path: "../.."},
      {:ash, "~> 3.33.1"},
      {:spark, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:stream_data, "~> 1.4", runtime: false},
      {:ash_r2rml,
       git: "https://github.com/seanchatmangpt/ash_r2rml.git",
       ref: "7d958a8c47a5a3459a515ac6f81a4d2d2d84dd16",
       runtime: false,
       override: true},
      {:ash_a2a,
       git: "https://github.com/seanchatmangpt/ash_a2a.git", tag: "v26.9.22", runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md CHANGELOG.md),
      maintainers: ["Sean Chatman"]
    ]
  end
end
