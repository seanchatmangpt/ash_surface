defmodule AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest do
  @moduledoc """
  Adaptation of ash_typescript `codegen/embedded_entrypoint_discovery_test.exs`.

  Reference claim: embedded-resource discovery is scoped to entrypoints, so an embedded
  resource referenced only by an action that is never exposed must not leak into the
  generated client. ash_typescript exposes actions through `rpc_action` entries, so its test
  separates a public-and-exposed action from a public-but-unexposed one. ash_surface has no
  `rpc_action` registry: its admission law is "exactly the public Ash action set"
  (README: projection metadata validates against the exact public action set), so the
  unexposed analogue is a NON-public action. The port keeps the same fixture shape
  (Holder with two embedded-returning actions, inline domain, dedicated otp_app) with the
  second action `public?: false`.

  Reference test -> port:

    * `find_embedded_resources/1` finds embedded resources behind exposed entrypoints ->
      the manifest entrypoints and `TypeFacts.embedded_resources/1` reach ExposedEmbedded
    * ignores embedded resources behind unexposed actions -> UnexposedEmbedded is absent from
      the entrypoints, the compiled IR and the generated artifact
    * "defines the schema for the embedded resource behind an entrypoint" -> the generated
      artifact embeds the exposed resource's field schema
    * "emits nothing for the embedded resource behind an unexposed action" -> the generated
      artifact never mentions it
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Projectors.JS

  defmodule ExposedEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule UnexposedEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil

    attributes do
      uuid_primary_key(:id)
      attribute(:secret_marker_field, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule Holder do
    use Ash.Resource,
      domain: AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      defaults([:read])

      # Public: an entrypoint; its embedded return must be found.
      action :build_exposed, :struct do
        public?(true)

        constraints(
          instance_of: AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.ExposedEmbedded
        )

        run(fn _input, _ctx ->
          {:ok, %AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.ExposedEmbedded{}}
        end)
      end

      # Public: the embedded resource is reachable as an INPUT of an exposed entrypoint.
      action :take_exposed do
        public?(true)

        argument :payload,
                 AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.ExposedEmbedded do
          allow_nil?(false)
        end

        run(fn _input, _ctx -> :ok end)
      end

      # Not public: the input-side reference to UnexposedEmbedded.
      action :take_unexposed do
        public?(false)

        argument :payload,
                 AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.UnexposedEmbedded do
          allow_nil?(false)
        end

        run(fn _input, _ctx -> :ok end)
      end

      # Not public: the only return-side reference to UnexposedEmbedded.
      action :build_unexposed, :struct do
        public?(false)

        constraints(
          instance_of: AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.UnexposedEmbedded
        )

        run(fn _input, _ctx ->
          {:ok, %AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.UnexposedEmbedded{}}
        end)
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.Ported.Codegen.EmbeddedEntrypointDiscoveryTest.Holder)
    end
  end

  @otp_app :embedded_entrypoint_discovery_t3_app

  setup do
    Application.put_env(@otp_app, :ash_domains, [Domain])
    on_exit(fn -> Application.delete_env(@otp_app, :ash_domains) end)

    {:ok, %AshSurface.Surface{manifest: manifest}} = AshSurface.from_app(@otp_app)
    {:ok, irs} = AshSurface.Compiler.compile(manifest)
    {:ok, artifacts, _meta} = JS.project_ir(irs)
    %{manifest: manifest, irs: irs, artifacts: artifacts}
  end

  describe "embedded resource discovery" do
    test "finds embedded resources reachable through exposed entrypoints", %{manifest: m} do
      actions = Enum.map(m.entrypoints, & &1.action.name)
      assert :build_exposed in actions

      exposed = Enum.find(m.entrypoints, &(&1.action.name == :build_exposed))
      assert exposed.action.returns |> inspect() =~ "ExposedEmbedded"

      # the entrypoint's return type resolves to the embedded resource closure
      analysis = TypeFacts.analyze_type(exposed.action.returns)
      assert analysis.definition["type"]["instance_of"] =~ "ExposedEmbedded"
    end

    test "ignores embedded resources reachable only through unexposed actions", %{
      manifest: m,
      irs: irs
    } do
      names = Enum.map(m.entrypoints, & &1.action.name)
      refute :build_unexposed in names
      refute :take_unexposed in names
      refute inspect(irs) =~ "UnexposedEmbedded"
    end
  end

  describe "generated output" do
    test "defines the schema for the embedded resource behind an entrypoint", %{
      irs: irs,
      artifacts: artifacts
    } do
      # Adaptation: ash_surface renders the embedded resource's field schema where the
      # resource is an action INPUT (generic-action return types carry no output schema
      # yet, so the return-side `build_exposed` has no embedded schema to assert).
      exposed = Enum.find(irs, &(&1.ash.action == :take_exposed))
      assert inspect(exposed.ash.resource) =~ "Holder"
      assert exposed.schema.zod =~ "label: z.string()"

      all = artifacts |> Map.values() |> Enum.join("\n")
      assert all =~ "label: z.string()"
    end

    test "emits nothing for the embedded resource behind an unexposed action", %{
      artifacts: artifacts
    } do
      all = artifacts |> Map.values() |> Enum.join("\n")

      assert all =~ "take_exposed" or all =~ "takeExposed"
      refute all =~ "UnexposedEmbedded"
      refute all =~ "secret_marker_field"
      refute all =~ "build_unexposed"
      refute all =~ "take_unexposed"
    end
  end
end
