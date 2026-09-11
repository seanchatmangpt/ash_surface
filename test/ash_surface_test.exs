defmodule AshSurfaceTest.RealPost do
  use Ash.Resource, data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true, allow_nil?: false
  end

  actions do
    defaults [:read, create: [:title]]
  end
end

defmodule AshSurfaceTest do
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.Transport

  defp manifest do
    %Manifest{
      entrypoints: [
        %Entrypoint{
          resource: AshSurfaceTest.Post,
          action: %Action{name: :read, type: :read, custom: %{}}
        },
        %Entrypoint{
          resource: AshSurfaceTest.Post,
          action: %Action{name: :create, type: :create, custom: %{}}
        }
      ]
    }
  end

  test "surface decorates the canonical manifest instead of replacing it" do
    profile = %{
      actions: %{
        "AshSurfaceTest.Post#read" => %{consumer: :web}
      },
      audience: :public
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest(), profile: profile)

    assert surface.action_ids == ["AshSurfaceTest.Post#create", "AshSurfaceTest.Post#read"]
    assert is_binary(surface.digest)
    assert byte_size(surface.digest) == 64

    [read, create] = surface.manifest.entrypoints

    assert read.action.custom.ash_surface == %{
             "id" => "AshSurfaceTest.Post#read",
             "profile" => %{"consumer" => "web"}
           }

    assert create.action.custom.ash_surface == %{
             "id" => "AshSurfaceTest.Post#create",
             "profile" => %{}
           }

    assert surface.manifest.custom.ash_surface == %{
             "schemaVersion" => AshSurface.schema_version(),
             "profile" => %{"audience" => "public"}
           }

    assert surface.contract["ashManifestSchemaVersion"] == Manifest.schema_version()
  end

  test "consumes a real Ash.Info.Manifest generated from an Ash resource" do
    assert {:ok, generated} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {AshSurfaceTest.RealPost, :read},
                 {AshSurfaceTest.RealPost, :create}
               ]
             )

    assert Enum.map(generated.entrypoints, &{&1.resource, &1.action.name}) == [
             {AshSurfaceTest.RealPost, :create},
             {AshSurfaceTest.RealPost, :read}
           ]

    assert {:ok, surface} = AshSurface.from_manifest(generated)

    assert surface.action_ids == [
             "AshSurfaceTest.RealPost#create",
             "AshSurfaceTest.RealPost#read"
           ]

    assert [%{name: "RealPost"}] = generated.resources
  end

  test "unknown action profile is refused" do
    assert {:error, {:unknown_action_profile, ["Missing#action"]}} =
             AshSurface.from_manifest(manifest(),
               profile: %{actions: %{"Missing#action" => %{consumer: :web}}}
             )
  end

  test "digest is stable across equivalent map insertion order" do
    profile_a = %{audience: :public, flags: %{b: 2, a: 1}}
    profile_b = %{flags: %{a: 1, b: 2}, audience: :public}

    assert {:ok, a} = AshSurface.from_manifest(manifest(), profile: profile_a)
    assert {:ok, b} = AshSurface.from_manifest(manifest(), profile: profile_b)
    assert a.digest == b.digest
  end

  test "transport selection preserves alternatives and forbids post-dispatch fallback" do
    assert {:ok, decision} =
             Transport.select([:http, :phoenix_channel], [:http],
               preferred: :phoenix_channel,
               action_id: "Post#create"
             )

    assert decision.selected == :http
    assert decision.reason == :preferred_unavailable
    assert decision.declared == [:http, :phoenix_channel]
    assert Transport.fallback_allowed?(decision)

    dispatched = Transport.mark_dispatched(decision)
    refute Transport.fallback_allowed?(dispatched)
  end

  test "unadmitted available transport is refused" do
    assert {:error, {:unadmitted_transport, [:phoenix_channel]}} =
             Transport.select([:http], [:http, :phoenix_channel])
  end
end
