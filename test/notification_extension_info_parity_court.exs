
defmodule NotificationExtension.ResourceInfoParityCourt do
  use ExUnit.Case, async: false

  @extension_source """
  defmodule NotificationExtension.Resource.InfoParity.ProbeEntity do
    @moduledoc false
    defstruct [:name, :events, :__identifier__, :__spark_metadata__]
  end

  defmodule NotificationExtension.Resource.InfoParity.Persist do
    @moduledoc false
    use Spark.Dsl.Transformer

    @impl true
    def transform(dsl_state) do
      probe_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:probe])
      compiled = %{probe: probe_entities}

      {:ok, Spark.Dsl.Transformer.persist(dsl_state, :notification_extension_info_parity_compiled, compiled)}
    end
  end

  defmodule NotificationExtension.Resource.InfoParity do
    @moduledoc "Specimen extension."

    @probe_entity %Spark.Dsl.Entity{
      name: :probe_entity,
      target: NotificationExtension.Resource.InfoParity.ProbeEntity,
      args: [:name],
      identifier: :name,
      schema: [
        name: [type: :string, required: true, doc: "Entity name."],
        events: [type: {:list, :atom}, default: [:read], doc: "Audited events."]
      ]
    }

    @probe %Spark.Dsl.Section{
      name: :probe,
      describe: "Probe section",
      schema: [
        level: [type: :atom, default: :full, doc: "Probe level."],
        mode: [type: :atom, default: :sync, doc: "Probe mode."]
      ],
      entities: [@probe_entity]
    }

    use Spark.Dsl.Extension,
      sections: [@probe],
      transformers: [NotificationExtension.Resource.InfoParity.Persist],
      verifiers: []
  end

  defmodule NotificationExtension.Resource.InfoParity.Info do
    @moduledoc "Specimen Info module."

    def probes(resource) do
      Spark.Dsl.Extension.get_entities(resource, [:probe])
    end

    def level(resource) do
      Spark.Dsl.Extension.get_opt(resource, [:probe], :level, nil)
    end

    def mode(resource) do
      Spark.Dsl.Extension.get_opt(resource, [:probe], :mode, nil)
    end

    def compiled_result(resource) do
      case Spark.Dsl.Extension.get_persisted(resource, :notification_extension_info_parity_compiled, nil) do
        nil -> {:error, :not_compiled}
        compiled -> {:ok, compiled}
      end
    end

    def declared_events(resource) do
      case compiled_result(resource) do
        {:ok, %{probe: entities}} -> Enum.flat_map(entities, & &1.events)
        {:error, _} -> []
      end
    end
  end
  """

  @fixture_source """
  defmodule NotificationExtension.Resource.InfoParity.Dsl do
    use Spark.Dsl, default_extensions: [extensions: [NotificationExtension.Resource.InfoParity]]
  end

  defmodule NotificationExtension.Resource.InfoParityFixture do
    use NotificationExtension.Resource.InfoParity.Dsl

    probe do
      level :full
      mode :sync

      probe_entity "orders" do
        events [:read, :update]
      end
    end
  end
  """

  @mutant_relative "packs/ash-extension-pack/fixture/info_mutants/info_mutant.exs"

  setup_all do
    Code.compile_string(@extension_source <> @fixture_source)

    mutated =
      (@extension_source <> @fixture_source)
      |> String.replace("InfoParity", "MutatedInfoParity")
      |> String.replace("level :full", "level :minimal")
      |> String.replace("events [:read, :update]", "events [:read, :update, :destroy]")

    Code.compile_string(mutated)

    %{
      fixture: NotificationExtension.Resource.InfoParityFixture,
      mutated_fixture: NotificationExtension.Resource.MutatedInfoParityFixture
    }
  end

  test "PARITY: every Info getter EQUALS the Spark-declared value, field-by-field", ctx do
    resource = ctx.fixture

    # Entity parity, field-by-field (not just presence).
    assert [entity] = NotificationExtension.Resource.InfoParity.Info.probes(resource)
    assert entity.name == "orders"
    assert entity.events == [:read, :update]
    assert entity.__identifier__ == "orders"

    # Section option parity.
    assert NotificationExtension.Resource.InfoParity.Info.level(resource) == :full
    assert NotificationExtension.Resource.InfoParity.Info.mode(resource) == :sync

    # Persisted-compiled-map getter parity (info.ex.tmpl compiled_result idiom).
    assert {:ok, %{probe: [^entity]}} = NotificationExtension.Resource.InfoParity.Info.compiled_result(resource)
    assert NotificationExtension.Resource.InfoParity.Info.declared_events(resource) == [:read, :update]
  end

  test "MUTATION: introspection tracks the Spark source -- no hardcoded copy", ctx do
    mutated_resource = ctx.mutated_fixture

    # Declared level changed :full -> :minimal: the getter MUST change.
    refute NotificationExtension.Resource.InfoParity.Info.level(mutated_resource) == :full
    assert NotificationExtension.Resource.InfoParity.Info.level(mutated_resource) == :minimal

    # Declared events changed [:read, :update] -> [:read, :update, :destroy].
    assert NotificationExtension.Resource.InfoParity.Info.declared_events(mutated_resource) ==
             [:read, :update, :destroy]

    refute NotificationExtension.Resource.InfoParity.Info.declared_events(mutated_resource) == [:read, :update]
  end

  test "ANTI-VACUITY: the constant-Info mutant FAILS the mutation leg (captured)", ctx do
    Code.compile_string(File.read!(mutant_path()))

    mutated_resource = ctx.mutated_fixture

    # The mutant's getters are constants; run the same assertions the mutation leg
    # runs and capture their failure instead of letting it abort the court.
    results =
      for {getter, expected} <- [
            {&InfoParityMutant.Info.level/1, :minimal},
            {&InfoParityMutant.Info.declared_events/1, [:read, :update, :destroy]}
          ] do
        try do
          assert getter.(mutated_resource) == expected
          :passed
        rescue
          e in ExUnit.AssertionError -> {:failed, Exception.message(e)}
        end
      end

    assert results != []
    assert Enum.all?(results, &match?({:failed, _}, &1)),
           "the constant Info mutant PASSED the mutation leg -- the court is vacuous: #{inspect(results)}"
  end

  defp mutant_path do
    System.get_env("INFO_PARITY_MUTANT_PATH") || discovered_mutant_path()
  end

  defp discovered_mutant_path do
    # cwd-dependent: standalone fixture runs (mix test in
    # packs/ash-extension-pack/fixture) find info_mutants/ directly; repo-root runs
    # and the live-fixture capsule need the packs/-prefixed path.
    # ASH_PACK_FIXTURE_DIR overrides (the live chain exports it).
    env_dir = System.get_env("ASH_PACK_FIXTURE_DIR")

    candidates =
      [
        env_dir && Path.join(env_dir, "info_mutants/info_mutant.exs"),
        Path.expand("info_mutants/info_mutant.exs"),
        Path.expand("fixture/info_mutants/info_mutant.exs"),
        Path.expand(@mutant_relative)
      ]
      |> Enum.reject(&is_nil/1)

    Enum.find(candidates, &File.exists?/1) ||
      raise ArgumentError,
            "info parity court: mutant not found; tried #{inspect(candidates)} " <>
              "(set INFO_PARITY_MUTANT_PATH or ASH_PACK_FIXTURE_DIR)"
  end
end
