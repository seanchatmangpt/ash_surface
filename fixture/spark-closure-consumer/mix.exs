defmodule SparkClosureConsumer.MixProject do
  use Mix.Project

  # Minimal, generic consumer fixture for the packs/ash-extension-pack igniter
  # idempotence court (templates/igniter_idempotence_court.exs.tmpl). One Ash resource
  # + one Ash domain, no extensions pre-installed -- the Igniter installer under court
  # is what patches them. Generated pack output (the Mix.Tasks.<X>.Install task and the
  # rendered court) is projected here by `ggen sync run` into lib/ and test/ at court
  # run time; never committed. The court itself copies this app to a scratch dir per
  # scenario, so this committed tree stays pristine.
  def project do
    [
      app: :spark_closure_consumer,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      # The court test defines modules at test time; consolidated protocols would
      # ignore them.
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps()
    ]
  end

  def application, do: [extra_applications: [:logger]]

  # Only ash/spark/igniter/sourceror, per the lane contract -- the minimal set the
  # generated Igniter installer needs to compile and run.
  defp deps do
    [
      {:ash, "~> 3.33"},
      {:spark, "~> 2.2"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:sourceror, "~> 1.7", only: [:dev, :test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib"]
  defp elixirc_paths(_), do: ["lib"]
end
