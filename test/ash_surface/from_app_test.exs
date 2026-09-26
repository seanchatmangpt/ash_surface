defmodule AshSurface.FromAppTest.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.FromAppTest.Toll)
  end
end

defmodule AshSurface.FromAppTest.Toll do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.FromAppTest.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:lane, :string, public?: true, allow_nil?: false)
    attribute(:fare, :integer, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])

    create :record do
      accept([:lane, :fare])
    end

    # Private bookkeeping actions: must never be admitted to the surface.
    update(:reprice, public?: false)
    destroy(:void, public?: false)
  end
end

defmodule AshSurface.FromAppTest do
  @moduledoc """
  State-based (Chicago school) verification of `AshSurface.from_app/2`.

  A real minimal Ash application — domain plus one ETS-backed resource, both
  defined inline — is registered under a dedicated `:otp_app` key. Assertions
  target the projected state returned by `from_app/2`: the admitted public
  action set, the `custom.ash_surface` projection metadata, and the read-only
  guarantee over the live application. No mock, no database, no network.
  """

  use ExUnit.Case, async: false

  alias AshSurface.FromAppTest.{Domain, Toll}

  @otp_app :ash_surface_from_app_test
  @toll "AshSurface.FromAppTest.Toll"

  setup do
    Application.put_env(@otp_app, :ash_domains, [Domain])
    on_exit(fn -> Application.delete_env(@otp_app, :ash_domains) end)
    :ok
  end

  test "admits exactly the domain's public action set" do
    assert {:ok, %AshSurface.Surface{} = surface} = AshSurface.from_app(@otp_app)

    assert surface.action_ids == [@toll <> "#read", @toll <> "#record"]

    admitted =
      surface.manifest.entrypoints |> Enum.map(&{&1.resource, &1.action.name}) |> Enum.sort()

    assert admitted == [{Toll, :read}, {Toll, :record}]

    # Private actions are excluded from every projection of the app.
    for id <- surface.action_ids do
      refute id in [@toll <> "#reprice", @toll <> "#void"]
    end

    contract_action_ids =
      surface.contract["surface"]["actions"] |> Enum.map(& &1["id"])

    assert contract_action_ids == surface.action_ids
  end

  test "returns the documented surface struct shape" do
    assert {:ok, surface} = AshSurface.from_app(@otp_app, profile: %{audience: :public})

    assert %AshSurface.Surface{} = surface
    assert %Ash.Info.Manifest{} = surface.manifest
    assert surface.manifest.resources |> Enum.map(& &1.module) == [Toll]
    assert is_binary(surface.digest)
    assert Regex.match?(~r/^[0-9a-f]{64}$/, surface.digest)

    assert Map.keys(surface.contract) |> Enum.sort() == [
             "ashManifestSchemaVersion",
             "generatorIdentity",
             "manifest",
             "manifestDigest",
             "marketplaceIdentity",
             "surface",
             "surfaceSchemaVersion"
           ]

    assert surface.contract["surfaceSchemaVersion"] == AshSurface.schema_version()
    assert surface.contract["ashManifestSchemaVersion"] == Ash.Info.Manifest.schema_version()
    assert Regex.match?(~r/^[0-9a-f]{64}$/, surface.contract["manifestDigest"])

    # v26.9.16 delegation: authorityBoundary/doAuthority are delegated facts,
    # not inferred from action type. The profile delegates neither, so both
    # surface as nil.
    actions = Enum.sort_by(surface.contract["surface"]["actions"], & &1["action"])

    assert Enum.map(actions, &{&1["action"], &1["authorityBoundary"], &1["doAuthority"]}) == [
             {"read", nil, nil},
             {"record", nil, nil}
           ]
  end

  test "stores projection metadata under custom.ash_surface" do
    profile = %{
      audience: :public,
      actions: %{(@toll <> "#record") => %{consumer: :mobile}}
    }

    assert {:ok, surface} = AshSurface.from_app(@otp_app, profile: profile)

    assert surface.manifest.custom.ash_surface == %{
             "schemaVersion" => AshSurface.schema_version(),
             "profile" => %{"audience" => "public"}
           }

    by_id = Map.new(surface.manifest.entrypoints, &{&1.action.name, &1})

    assert by_id.record.action.custom.ash_surface == %{
             "id" => @toll <> "#record",
             "profile" => %{"consumer" => "mobile"}
           }

    assert by_id.read.action.custom.ash_surface == %{
             "id" => @toll <> "#read",
             "profile" => %{}
           }
  end

  test "projection is read-only: the live app is not mutated" do
    assert {:ok, raw_before} = Ash.Info.Manifest.generate(otp_app: @otp_app)

    assert {:ok, surface} = AshSurface.from_app(@otp_app, profile: %{audience: :public})
    assert {:ok, again} = AshSurface.from_app(@otp_app, profile: %{audience: :public})
    assert again.digest == surface.digest

    # Domain registration and resource list are unchanged.
    assert Ash.Info.domains(@otp_app) == [Domain]
    assert Ash.Domain.Info.resources(Domain) == [Toll]

    # A fresh manifest carries no ash_surface decoration: the projection
    # metadata lives only in the returned surface envelope, never in the app.
    assert {:ok, raw_after} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    assert raw_after == raw_before
    refute Map.has_key?(raw_after.custom, :ash_surface)
    refute Enum.any?(raw_after.entrypoints, &Map.has_key?(&1.action.custom, :ash_surface))
  end
end
