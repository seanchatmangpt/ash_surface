defmodule AshSurface.MetadataProjectionTest.Doc do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true)
  end

  actions do
    for name <- [:read_all, :read_off, :read_empty, :read_one, :read_two, :read_mapped] do
      read name do
        metadata(:some_string, :string)
        metadata(:some_number, :integer)
      end
    end
  end

  surface do
    projection :read_all
    projection :read_off, do: show_metadata(false)
    projection :read_empty, do: show_metadata([])
    projection :read_one, do: show_metadata([:some_string])
    projection :read_two, do: show_metadata([:some_string, :some_number])

    projection :read_mapped do
      show_metadata([:some_string, :some_number])
      metadata_field_names(some_string: "someStr", some_number: "someNum")
    end
  end
end

defmodule AshSurface.MetadataProjectionTest do
  @moduledoc """
  Register row `Metadata` (PARITY-REGISTER): projection metadata is validated and stored
  under `custom.ash_surface`. Two real code paths carry it:

    * DSL projection options `show_metadata` / `metadata_field_names`
      (`lib/ash_surface/resource.ex`) stored on the entity and persisted compiled state;
    * the manifest profile (`AshSurface.from_manifest/2`, `lib/ash_surface.ex`
      `validate_profile/1` + `decorate_manifest/2`) stored under `custom.ash_surface`.

  Ports the DSL-observable half of the reference `rpc_metadata_test` (show_metadata
  nil/false/[]/[one]/[two], metadata_field_names). The reference's runtime RPC result shaping
  has no ash_surface analog (ash_surface projects, it does not execute actions).
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias AshSurface.Resource.{Info, Projections, Validator}

  @doc_resource AshSurface.MetadataProjectionTest.Doc

  defp projection(action), do: Projections.for_action(@doc_resource, action)

  describe "DSL show_metadata matrix (stored verbatim on the entity)" do
    test "unset means all metadata (nil)" do
      assert projection(:read_all).show_metadata == nil
    end

    test "false disables" do
      assert projection(:read_off).show_metadata == false
    end

    test "empty list exposes none" do
      assert projection(:read_empty).show_metadata == []
    end

    test "one and two fields" do
      assert projection(:read_one).show_metadata == [:some_string]
      assert projection(:read_two).show_metadata == [:some_string, :some_number]
    end

    test "metadata_field_names maps original name to wire name" do
      p = projection(:read_mapped)
      assert p.metadata_field_names == [some_string: "someStr", some_number: "someNum"]
      assert projection(:read_all).metadata_field_names == nil
    end
  end

  describe "persisted compiled state" do
    test "compiled state carries the same projections the DSL declared" do
      compiled = Info.compiled!(@doc_resource)
      by_action = Map.new(compiled.surface, &{&1.action, &1})
      assert by_action[:read_off].show_metadata == false
      assert by_action[:read_two].show_metadata == [:some_string, :some_number]
      assert by_action[:read_mapped].metadata_field_names[:some_string] == "someStr"
    end

    test "every declared projection passes the validator" do
      assert :ok == Validator.validate(Info.compiled!(@doc_resource))
    end

    test "the live resource really declares the metadata the options name" do
      names =
        @doc_resource
        |> Ash.Resource.Info.action(:read_two)
        |> Map.fetch!(:metadata)
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert names == [:some_number, :some_string]
    end
  end

  describe "manifest profile stored under custom.ash_surface" do
    defp manifest do
      assert {:ok, m} =
               Manifest.generate(
                 otp_app: :ash_surface,
                 action_entrypoints: [{@doc_resource, :read_one}, {@doc_resource, :read_mapped}]
               )

      m
    end

    @id "AshSurface.MetadataProjectionTest.Doc#read_one"

    test "metadata-bearing action outputs surface in the manifest" do
      ep = Enum.find(manifest().entrypoints, &(&1.action.name == :read_one))

      assert ep.action.metadata |> Enum.map(& &1.name) |> Enum.sort() == [
               :some_number,
               :some_string
             ]
    end

    test "profile metadata is stored under custom.ash_surface beside foreign custom" do
      m = manifest()

      assert {:ok, surface} =
               AshSurface.from_manifest(m,
                 profile: %{
                   "actions" => %{@id => %{"showMetadata" => ["some_string"], "tier" => "gold"}}
                 }
               )

      ep = Enum.find(surface.manifest.entrypoints, &(&1.action.name == :read_one))
      env = ep.action.custom[:ash_surface]
      assert env["id"] == @id
      assert env["profile"] == %{"showMetadata" => ["some_string"], "tier" => "gold"}

      other = Enum.find(surface.manifest.entrypoints, &(&1.action.name == :read_mapped))
      assert other.action.custom[:ash_surface]["profile"] == %{}
    end

    test "profile metadata survives into the contract surface envelope" do
      {:ok, surface} =
        AshSurface.from_manifest(manifest(),
          profile: %{
            "actions" => %{@id => %{"metadataFieldNames" => %{"some_string" => "someStr"}}}
          }
        )

      act = Enum.find(surface.contract["surface"]["actions"], &(&1["id"] == @id))
      assert act["profile"] == %{"metadataFieldNames" => %{"some_string" => "someStr"}}
    end

    test "unserializable profile metadata is refused, never stored" do
      assert {:error, {:profile_value_not_serializable, _}} =
               AshSurface.from_manifest(manifest(),
                 profile: %{"actions" => %{@id => %{"showMetadata" => DateTime.utc_now()}}}
               )

      assert {:error, :profile_must_be_a_map} = AshSurface.from_manifest(manifest(), profile: [1])
    end

    test "profile for an action outside the exact entrypoint set is refused" do
      assert {:error, {:unknown_action_profile, ["Nope#x"]}} =
               AshSurface.from_manifest(manifest(), profile: %{"actions" => %{"Nope#x" => %{}}})
    end
  end

  describe "validator refusals (real Spark verifier path)" do
    test "unknown metadata name in show_metadata is refused" do
      bad = %{action: :read_one, show_metadata: [:nope]}
      assert {:error, _} = Validator.validate(%{resource: @doc_resource, surface: [bad]})
    end

    test "non-list show_metadata and non-keyword metadata_field_names are refused" do
      assert {:error, _} =
               Validator.validate(%{
                 resource: @doc_resource,
                 surface: [%{action: :read_one, show_metadata: :bad}]
               })

      assert {:error, _} =
               Validator.validate(%{
                 resource: @doc_resource,
                 surface: [%{action: :read_one, metadata_field_names: :bad}]
               })
    end

    test "unknown mapped name, invalid identifier and collision are refused" do
      for names <- [
            [nope: "x"],
            [some_string: "1bad"],
            [some_string: "same", some_number: "same"]
          ] do
        assert {:error, _} =
                 Validator.validate(%{
                   resource: @doc_resource,
                   surface: [%{action: :read_mapped, metadata_field_names: names}]
                 })
      end
    end

    test "valid options are admitted" do
      assert :ok ==
               Validator.validate(%{
                 resource: @doc_resource,
                 surface: [
                   %{
                     action: :read_mapped,
                     show_metadata: [:some_string],
                     metadata_field_names: [some_string: "someStr"]
                   }
                 ]
               })
    end
  end

  describe "DSL metadata options in custom.ash_surface" do
    test "DSL show_metadata and metadata_field_names appear in the envelope" do
      m = manifest()
      {:ok, surface} = AshSurface.from_manifest(m)
      one = Enum.find(surface.manifest.entrypoints, &(&1.action.name == :read_one))
      assert one.action.custom[:ash_surface]["show_metadata"] == ["some_string"]

      mapped = Enum.find(surface.manifest.entrypoints, &(&1.action.name == :read_mapped))
      env = mapped.action.custom[:ash_surface]
      assert env["show_metadata"] == ["some_string", "some_number"]

      assert env["metadata_field_names"] == %{
               "some_string" => "someStr",
               "some_number" => "someNum"
             }

      assert env["id"] == "AshSurface.MetadataProjectionTest.Doc#read_mapped"
    end
  end
end
