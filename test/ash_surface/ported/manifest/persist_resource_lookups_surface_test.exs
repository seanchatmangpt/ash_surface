defmodule AshSurface.Ported.Manifest.PersistResourceLookupsSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/persist_resource_lookups_test`.

  ash_typescript persists `:resource_lookup` / `:action_lookup` on a Spark manifest module.
  ash_surface ingests the real `Ash.Info.Manifest` (`Manifest.generate/1`) and wraps it in
  `AshSurface.from_manifest/2`; the lookups are read through `Ash.Info.Manifest` accessors
  on both the raw and the surface-decorated manifest.

  Changes: persisted-attribute reads -> `Manifest.resource_lookup/1`, `action_lookup/1`,
  `type_lookup/1`; "BOTH Domain and SecondDomain" -> two actions of one resource (the ported
  fixture set has one domain); embedded resources are enumerated from `type_lookup`
  (`kind: :embedded_resource`), where Ash records them; the app-wide persistent_term read ->
  the decorated manifest preserving the lookup.
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest

  @todo AshSurface.Ported.Todo
  @user AshSurface.Ported.User
  @comment AshSurface.Ported.TodoComment

  setup_all do
    {:ok, manifest} =
      Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: [
          {@todo, :read},
          {@user, :read},
          {@user, :get_by_id},
          {@comment, :read}
        ]
      )

    {:ok, surface} = AshSurface.from_manifest(manifest)
    {:ok, manifest: manifest, surface: surface}
  end

  describe "surface persists the manifest lookups" do
    test "action_ids are the exact sorted entrypoint identities", %{surface: s} do
      assert s.action_ids == [
               "AshSurface.Ported.Todo#read",
               "AshSurface.Ported.TodoComment#read",
               "AshSurface.Ported.User#get_by_id",
               "AshSurface.Ported.User#read"
             ]
    end

    test "every entrypoint of one resource is decorated with its own id", %{surface: s} do
      by_id =
        Map.new(s.manifest.entrypoints, fn ep ->
          {AshSurface.action_id(ep), ep.action.custom[:ash_surface]}
        end)

      assert Map.keys(by_id) |> Enum.sort() == s.action_ids

      for {id, custom} <- by_id do
        assert custom["id"] == id
        assert custom["profile"] == %{}
      end
    end

    test "the decorated manifest keeps the resource and action lookups intact",
         %{manifest: m, surface: s} do
      assert Manifest.resource_lookup(s.manifest) == Manifest.resource_lookup(m)
      assert Map.keys(Manifest.action_lookup(s.manifest)) == Map.keys(Manifest.action_lookup(m))
      assert Manifest.type_lookup(s.manifest) == Manifest.type_lookup(m)
      assert Map.has_key?(Manifest.resource_lookup(s.manifest), @todo)
      assert Map.has_key?(Manifest.action_lookup(s.manifest), {@user, :get_by_id})
    end

    test "the root custom.ash_surface section carries schema version and dsl facts",
         %{surface: s} do
      root = s.manifest.custom[:ash_surface]
      assert root["schemaVersion"] == AshSurface.schema_version()
      assert root["profile"] == %{}
      assert root["dsl"][inspect(@todo)]["type_name"] == "Todo"
      assert root["dsl"][inspect(@user)]["field_names"]["is_active?"] == "isActive"
    end

    test "a profile lands on its action's custom section and the root", %{manifest: m} do
      profile = %{"tier" => "gold", "actions" => %{"#{inspect(@user)}#get_by_id" => %{"a" => 1}}}
      {:ok, s} = AshSurface.from_manifest(m, profile: profile)

      assert s.manifest.custom[:ash_surface]["profile"] == %{"tier" => "gold"}

      profiles =
        Map.new(s.manifest.entrypoints, fn ep ->
          {AshSurface.action_id(ep), ep.action.custom[:ash_surface]["profile"]}
        end)

      assert profiles["#{inspect(@user)}#get_by_id"] == %{"a" => 1}
      assert profiles["#{inspect(@todo)}#read"] == %{}
    end

    test "the digest is stable per input and moves with the profile", %{manifest: m, surface: s} do
      {:ok, again} = AshSurface.from_manifest(m)
      {:ok, other} = AshSurface.from_manifest(m, profile: %{"tier" => "gold"})
      assert again.digest == s.digest
      assert other.digest != s.digest
    end
  end
end
