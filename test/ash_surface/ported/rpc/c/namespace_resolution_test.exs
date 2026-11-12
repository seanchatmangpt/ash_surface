defmodule AshSurface.Ported.Rpc.C.NamespaceResolutionTest do
  @moduledoc """
  Port of `describe "namespace resolution"` from ash_typescript `rpc/namespace_test.exs`.
  `RpcConfigCollector.resolve_namespace/3` becomes the real precedence chain
  projection `namespace` > resource `surface namespace` > `AshSurface.Domain` namespace,
  exercised on real Spark-compiled domains and resources (no doubles).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Resource.Info, as: ResInfo
  alias AshSurface.Resource.Projections

  defmodule NsDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

    surface do
      namespace("second")
    end

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule PlainDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule Base do
    defmacro __using__(opts) do
      quote do
        use Ash.Resource,
          domain: unquote(opts[:domain]),
          data_layer: Ash.DataLayer.Ets,
          primary_read_warning?: false,
          extensions: [AshSurface.Resource]

        attributes do
          uuid_primary_key(:id)
        end

        actions do
          defaults([:read])
        end
      end
    end
  end

  defmodule ActionNs do
    use Base, domain: PlainDomain

    surface do
      namespace("resource_ns")
      projection(:read, namespace: "action_ns")
    end
  end

  defmodule ResourceNs do
    use Base, domain: PlainDomain

    surface do
      namespace("resource_ns")
      projection(:read)
    end
  end

  defmodule NoNs do
    use Base, domain: PlainDomain

    surface do
      projection(:read)
    end
  end

  defmodule DomainNsOnly do
    use Base, domain: NsDomain

    surface do
      projection(:read)
    end
  end

  defmodule DomainNsOverridden do
    use Base, domain: NsDomain

    surface do
      namespace("resource_ns")
      projection(:read)
    end
  end

  defp resolve(resource, action) do
    projection = Projections.for_action(resource, action)
    (projection && projection.namespace) || ResInfo.effective_namespace(resource)
  end

  describe "namespace resolution" do
    test "resolve returns action namespace when set (highest precedence)" do
      assert resolve(ActionNs, :read) == "action_ns"
    end

    test "resolve returns resource namespace when action has none" do
      assert resolve(ResourceNs, :read) == "resource_ns"
    end

    test "resolve returns nil when no namespace configured at any level" do
      assert resolve(NoNs, :read) == nil
    end

    test "domain namespace is resolved via the resolution chain" do
      assert resolve(NoNs, :read) == nil
      assert AshSurface.Domain.Info.namespace(PlainDomain) == nil
      assert AshSurface.Domain.Info.namespace(NsDomain) == "second"
      assert resolve(DomainNsOnly, :read) == "second"
    end

    test "namespace precedence: action > resource > domain" do
      assert resolve(ActionNs, :read) == "action_ns"
      assert resolve(ResourceNs, :read) == "resource_ns"
      assert resolve(DomainNsOverridden, :read) == "resource_ns"
      assert resolve(DomainNsOnly, :read) == "second"
      assert resolve(NoNs, :read) == nil
    end

    test "domain-level namespace applies to all actions in that domain's resources" do
      assert resolve(DomainNsOnly, :read) == "second"
      refute resolve(NoNs, :read) == "second"
    end

    test "resource-level namespace applies to every projection of the resource" do
      assert ResInfo.effective_namespace(ResourceNs) == "resource_ns"

      assert Enum.all?(
               Projections.all(ResourceNs),
               &(resolve(ResourceNs, &1.action) == "resource_ns")
             )
    end

    test "action-level namespace overrides resource-level namespace" do
      assert resolve(ActionNs, :read) == "action_ns"
      refute resolve(ActionNs, :read) == ResInfo.effective_namespace(ActionNs)
    end
  end

  describe "namespace accessors are layer-exact (mutation-killing)" do
    test "resource-level accessor never leaks the domain namespace" do
      assert ResInfo.namespace(DomainNsOnly) == nil
      assert ResInfo.namespace(NoNs) == nil
      assert ResInfo.namespace(ResourceNs) == "resource_ns"
      assert ResInfo.namespace(DomainNsOverridden) == "resource_ns"
    end

    test "effective_namespace is exact for every layer combination" do
      assert ResInfo.effective_namespace(NoNs) == nil
      assert ResInfo.effective_namespace(DomainNsOnly) == "second"
      assert ResInfo.effective_namespace(DomainNsOverridden) == "resource_ns"
      assert ResInfo.effective_namespace(ResourceNs) == "resource_ns"
      assert ResInfo.effective_namespace(ActionNs) == "resource_ns"
    end

    test "domain accessor reads only the domain option" do
      assert AshSurface.Domain.Info.namespace(NsDomain) == "second"
      assert AshSurface.Domain.Info.namespace(PlainDomain) == nil
    end

    test "projection carries only its own action-level namespace" do
      assert Projections.for_action(ActionNs, :read).namespace == "action_ns"
      assert Projections.for_action(ResourceNs, :read).namespace == nil
      assert Projections.for_action(DomainNsOnly, :read).namespace == nil
      assert Projections.for_action(NoNs, :read).namespace == nil
    end

    test "each resource has exactly one projection, for :read" do
      for r <- [ActionNs, ResourceNs, NoNs, DomainNsOnly, DomainNsOverridden] do
        assert Enum.map(Projections.all(r), & &1.action) == [:read]
      end
    end

    test "resolved namespaces over the whole fixture set are an exact map" do
      all = [ActionNs, ResourceNs, NoNs, DomainNsOnly, DomainNsOverridden]

      assert Map.new(all, &{&1 |> Module.split() |> List.last(), resolve(&1, :read)}) == %{
               "ActionNs" => "action_ns",
               "ResourceNs" => "resource_ns",
               "NoNs" => nil,
               "DomainNsOnly" => "second",
               "DomainNsOverridden" => "resource_ns"
             }
    end
  end
end
