defmodule AshSurface.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/seanchatmangpt/ash_surface"

  def project do
    [
      app: :ash_surface,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Manifest-first consumer surfaces for Ash applications",
      source_url: @source_url,
      homepage_url: @source_url,
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [extra_applications: [:logger, :crypto]]
  end

  defp deps do
    [
      {:ash, "~> 3.33.1"},
      {:spark, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md AGENTS.md)
    ]
  end
end
