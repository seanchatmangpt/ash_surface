defmodule AshSurface.Ported.Rpc.Rbg.NsRes do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    validate_domain_inclusion?: false,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    defaults([:read])
  end

  surface do
    type_name("RbgNs")
    namespace("billing")
    projection :read
  end
end

defmodule AshSurface.Ported.Rpc.Rbg.NamespaceManifestTest do
  @moduledoc """
  Lane RBG: namespace observable through the real manifest.
  (1) Dsl.serialize/1 `"namespace"` key; (2) route entry `"namespace"` from RouteSchema.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.{ActionManifest, Dsl}
  alias AshSurface.Ported.Rpc.Rbg.NsRes
  alias AshSurface.RuntimeParity.Rpc.Pipeline, as: E

  test "Dsl.serialize carries the declared resource namespace" do
    assert %{"namespace" => "billing", "type_name" => "RbgNs"} = Dsl.serialize(NsRes)
  end

  test "Dsl.serialize_all keys it by module and exposes it through a real manifest" do
    {:ok, m} = Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: [{NsRes, :read}])
    assert Dsl.serialize_all(m.entrypoints)[inspect(NsRes)]["namespace"] == "billing"
  end

  test "resource namespace flows to the action entry and namespaces list" do
    {:ok, m} = Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: [{NsRes, :read}])
    out = ActionManifest.build(m, [E.entry(:ls, NsRes, :read)])
    assert [%{"namespace" => "billing"}] = out["actions"]
    assert out["namespaces"] == ["billing"]
  end

  test "route entry namespace is carried exactly; absent stays nil" do
    {:ok, m} = Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: [{NsRes, :read}])

    routes = [
      %{"name" => "a", "method" => "get", "path" => "/a", "arguments" => [], "namespace" => "ns_a"},
      %{"name" => "b", "method" => "get", "path" => "/b", "arguments" => []}
    ]

    out = ActionManifest.build(m, [E.entry(:ls, NsRes, :read)], routes: routes)
    by = Map.new(out["routes"], &{&1["name"], &1})
    assert by["a"]["namespace"] == "ns_a"
    assert by["b"]["namespace"] == nil
  end
end
