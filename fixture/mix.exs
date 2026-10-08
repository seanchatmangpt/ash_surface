defmodule PipelineProbe.MixProject do
  use Mix.Project

  # Consumer fixture for packs/ash-extension-pack. ASH_PACK_GENERATED holds every
  # lib/**/*.ex a real `ggen sync run` projected (all specs of the union graph,
  # including the Reactor step modules), ASH_PACK_GENERATED_TEST every generated
  # composition test; both are written by scripts/ash_pack_live_fixture.sh. lib/ holds
  # only consumer-owned code the pack does not generate (the Ash domain + resource a
  # receipted action wraps).
  def project do
    [
      app: :pipeline_probe,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: false,
      # The generated composition tests compile Ash resources at test time, which
      # define Inspect impls; consolidated protocols would ignore them.
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: ["lib", generated_path()],
      test_paths: ["test" | generated_test_paths()],
      deps: deps()
    ]
  end

  # scripts/ash_pack_live_fixture.sh points ASH_PACK_GENERATED (and MIX_BUILD_ROOT /
  # MIX_DEPS_PATH) into its capsule so no build output, dependency tree, or generated
  # copy ever lands inside the pack directory (marketplace.py archives every visible
  # file under a pack and refuses symlinks, which _build/ is full of).
  defp generated_path, do: System.get_env("ASH_PACK_GENERATED", "lib/generated")

  defp generated_test_paths do
    case System.get_env("ASH_PACK_GENERATED_TEST") do
      nil -> []
      path -> [path]
    end
  end

  def application, do: [extra_applications: [:logger, :crypto]]

  defp deps do
    [
      {:ash, "~> 3.33"},
      {:reactor, "~> 1.0"},
      # igniter_court deps: the generated igniter idempotence court's scratch
      # consumer apps (copies of spark-closure-consumer) resolve {:igniter, "~> 0.6"}
      # and {:sourceror, "~> 1.7"} against THIS fixture's shared MIX_DEPS_PATH;
      # without them the scratch install subprocess refuses with
      # "the dependency is not available, run mix deps.get".
      {:igniter, "~> 0.6", only: :test},
      {:sourceror, "~> 1.7", only: :test},
      # aex:installerRuntimeDep for NotificationExtensionSpec ("a2a ~> 0.2"): the
      # generated notification install task adds {:a2a, "~> 0.2"} to the scratch's
      # mix.exs, whose NEXT `mix <task>` run dep-checks it. Fetched here so the
      # shared MIX_DEPS_PATH + copied mix.lock satisfy the scratch's check.
      {:a2a, "~> 0.2", only: :test},
      # aex:CompositionTarget libraries (ontology.ttl's AuditTrailSpec composes with
      # both); only the generated composition tests load them.
      {:ash_graphql, "~> 1.0", only: :test},
      {:ash_json_api, "~> 1.0", only: :test}
    ]
  end
end
