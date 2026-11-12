defmodule AshSurface.Ported.Rpc.Rbo.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

  surface do
    namespace("dom_ns")
  end

  resources do
    allow_unregistered?(true)
  end
end

defmodule AshSurface.Ported.Rpc.Rbo.DomRes do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbo.Domain,
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
    projection :read
  end
end

defmodule AshSurface.Ported.Rpc.Rbo.OwnRes do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbo.Domain,
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
    namespace("res_ns")
    projection :read
  end
end

defmodule AshSurface.Ported.Rpc.Rbo.BareRes do
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
    projection :read
  end
end

defmodule AshSurface.Ported.Rpc.Rbo.ManifestNamespacesTest do
  @moduledoc """
  Lane RBO (G4-G8): manifest `namespaces` list and per-action `namespace` over a real compiled
  manifest with three namespace levels: entry > resource > domain; sorted, unique, non-nil.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.ActionManifest
  alias AshSurface.Ported.Rpc.Rbo.{BareRes, DomRes, OwnRes}
  alias AshSurface.RuntimeParity.Rpc.Pipeline, as: E

  setup_all do
    {:ok, m} =
      Ash.Info.Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: [{DomRes, :read}, {OwnRes, :read}, {BareRes, :read}]
      )

    %{m: m}
  end

  defp ns_by_name(out), do: Map.new(out["actions"], &{&1["name"], &1["namespace"]})

  test "three levels resolve entry > resource > domain, bare resource is nil", %{m: m} do
    out =
      ActionManifest.build(m, [
        E.entry(:entry_over_res, OwnRes, :read, namespace: "entry_ns"),
        E.entry(:entry_over_dom, DomRes, :read, namespace: "entry_ns2"),
        E.entry(:res_wins, OwnRes, :read),
        E.entry(:dom_fallback, DomRes, :read),
        E.entry(:bare, BareRes, :read)
      ])

    assert ns_by_name(out) == %{
             "entry_over_res" => "entry_ns",
             "entry_over_dom" => "entry_ns2",
             "res_wins" => "res_ns",
             "dom_fallback" => "dom_ns",
             "bare" => nil
           }
  end

  test "namespaces list is sorted, unique and nil-free", %{m: m} do
    out =
      ActionManifest.build(m, [
        E.entry(:a, BareRes, :read, namespace: "zeta"),
        E.entry(:b, DomRes, :read),
        E.entry(:c, BareRes, :read),
        E.entry(:d, OwnRes, :read),
        E.entry(:e, BareRes, :read, namespace: "zeta"),
        E.entry(:f, DomRes, :read),
        E.entry(:g, BareRes, :read, namespace: "alpha")
      ])

    assert out["namespaces"] == ["alpha", "dom_ns", "res_ns", "zeta"]
  end

  test "all-nil namespaces yield an empty list", %{m: m} do
    out = ActionManifest.build(m, [E.entry(:c, BareRes, :read)])
    assert out["namespaces"] == []
    assert [%{"namespace" => nil}] = out["actions"]
  end

  test "atom entry namespace renders as a string", %{m: m} do
    out = ActionManifest.build(m, [E.entry(:c, BareRes, :read, namespace: :atom_ns)])
    assert [%{"namespace" => "atom_ns"}] = out["actions"]
    assert out["namespaces"] == ["atom_ns"]
  end
end
