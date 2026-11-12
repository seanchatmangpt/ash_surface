defmodule AshSurface.Ported.Manifest.DecoratorSurfaceTest.Comment do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]

  surface do
    projection(:read)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:body, :string, public?: true)
  end

  relationships do
    belongs_to(:deco, AshSurface.Ported.Manifest.DecoratorSurfaceTest.Deco, public?: true)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.Ported.Manifest.DecoratorSurfaceTest.Deco do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Ets, extensions: [AshSurface.Resource]

  surface do
    type_name("Deco")
    field_names(address_line_1: "addressLine1", is_active?: "isActive")
    argument_names(read_with_invalid_arg: [is_active?: "isActive"])

    projection(:read_with_invalid_meta,
      metadata_field_names: [meta_1: "meta1", is_valid?: "isValid", field_2: "field2"]
    )

    projection(:read_with_invalid_arg)
    projection(:meta_unset)
    projection(:meta_false, show_metadata: false)
    projection(:meta_empty, show_metadata: [])
    projection(:meta_two, show_metadata: [:some_string, :some_number])
    projection(:allow_user, allowed_loads: [:owner])
    projection(:allow_nested, allowed_loads: [:owner, comments: [:deco]])
    projection(:deny_user, denied_loads: [:owner])
    projection(:no_filter, enable_filter?: false)
    projection(:no_sort, enable_sort?: false)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string, public?: true)
    attribute(:is_active?, :boolean, public?: true)
    attribute(:address_line_1, :string, public?: true)
  end

  relationships do
    belongs_to(:owner, AshSurface.Ported.Manifest.DecoratorSurfaceTest.Comment, public?: true)

    has_many(:comments, AshSurface.Ported.Manifest.DecoratorSurfaceTest.Comment,
      public?: true,
      destination_attribute: :deco_id
    )
  end

  actions do
    read :read_with_invalid_arg do
      argument(:is_active?, :boolean)
    end

    read :read_with_invalid_meta do
      metadata(:meta_1, :string)
      metadata(:is_valid?, :boolean)
      metadata(:field_2, :string)
    end

    for name <- [:meta_unset, :meta_false, :meta_empty, :meta_two] do
      read name do
        metadata(:some_string, :string)
        metadata(:some_number, :integer)
        metadata(:other, :string)
      end
    end

    for name <- [:allow_user, :allow_nested, :deny_user, :no_filter, :no_sort] do
      read(name)
    end
  end
end

defmodule AshSurface.Ported.Manifest.DecoratorSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/decorator_test`.

  ash_surface decorates an `Ash.Info.Manifest` (via `AshSurface.from_manifest/2`) under
  `custom.ash_surface`; resource-level declarations are read back with
  `AshSurface.Manifest.Dsl`, per-action projection options ride the action custom entry,
  load restrictions and filter/sort flags are compiler facts (`ResourceFacts`). Fixtures
  are private real Ash resources (above); the manifest is real (`Manifest.generate/1`).

  Changes: `Custom.*` accessors -> their ash_surface sources named per test;
  `{:allow, list}` / `{:deny, list}` -> the sorted flattened `allowed_loads` /
  `denied_loads` fact lists; `Manifest.Resource.custom` -> `Dsl.read/1` (the Ash JSON
  serializer omits `custom`, so the surface envelope carries it).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ResourceFacts
  alias AshSurface.FieldName
  alias AshSurface.FieldName.Mapping
  alias AshSurface.Manifest.Dsl
  alias AshSurface.Ported.Manifest.DecoratorSurfaceTest.Deco

  @actions [
    :read_with_invalid_meta,
    :read_with_invalid_arg,
    :meta_unset,
    :meta_false,
    :meta_empty,
    :meta_two,
    :allow_user,
    :allow_nested,
    :deny_user,
    :no_filter,
    :no_sort
  ]

  setup_all do
    {:ok, manifest} =
      Ash.Info.Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: Enum.map(@actions, &{Deco, &1})
      )

    {:ok, surface} = AshSurface.from_manifest(manifest)
    {:ok, surface: surface}
  end

  defp entrypoint(surface, action),
    do: Enum.find(surface.manifest.entrypoints, &(&1.action.name == action))

  defp facts(action), do: ResourceFacts.build(Deco, Ash.Resource.Info.action(Deco, action))

  describe "resource decoration" do
    test "resources with the AshSurface.Resource extension carry declarations in custom.ash_surface",
         %{surface: surface} do
      assert %{"type_name" => "Deco"} = Dsl.read(surface.manifest)[inspect(Deco)]
      assert %{ash_surface: %{"dsl" => %{}}} = surface.manifest.custom
    end

    test "field_names round-trips the DSL", %{surface: surface} do
      dsl = Dsl.read(surface.manifest)[inspect(Deco)]

      assert dsl["field_names"] == %{
               "address_line_1" => "addressLine1",
               "is_active?" => "isActive"
             }
    end

    test "reverse mapping is the inverse" do
      {:ok, %{reverse: reverse}} =
        Mapping.build(
          fields: [:address_line_1, :is_active?, :name],
          field_names: Map.new(AshSurface.Resource.Info.field_names(Deco))
        )

      assert reverse["isActive"] == :is_active?
      assert reverse["addressLine1"] == :address_line_1
      assert reverse["doesNotExist"] == nil
    end

    test "mapped field name returns the explicit override, unmapped uses the formatter" do
      assert FieldName.format_field_for_client(:is_active?, Deco, :camel_case) == "isActive"
      assert FieldName.format_field_for_client(:name, Deco, :camel_case) == "name"
    end

    test "argument_names round-trips the DSL", %{surface: surface} do
      dsl = Dsl.read(surface.manifest)[inspect(Deco)]
      assert dsl["argument_names"] == %{"read_with_invalid_arg" => %{"is_active?" => "isActive"}}
    end

    test "formatted field names: explicit mapping wins over the formatter, others follow it" do
      assert FieldName.format_field_for_client(:is_active?, Deco, :camel_case) == "isActive"

      assert FieldName.format_field_for_client(:address_line_1, Deco, :camel_case) ==
               "addressLine1"

      assert FieldName.format_field_for_client(:name, Deco, :camel_case) == "name"
      assert_raise ArgumentError, fn -> FieldName.compute(:name, :weird_format) end
    end

    test "resources without the extension are not decorated", %{surface: surface} do
      refute Map.has_key?(Dsl.read(surface.manifest), inspect(AshSurface.Ported.NotExposed))
      assert Dsl.serialize(AshSurface.Ported.NotExposed) == %{}
    end
  end

  describe "embedded resource decoration" do
    test "embedded resources carry their own declarations" do
      dsl = Dsl.serialize(AshSurface.Ported.TaskMetadata)
      assert dsl["field_names"] == %{"created_by?" => "createdBy", "is_public?" => "isPublic"}
    end
  end

  describe "type decoration (NewTypes with typescript_field_names)" do
    test "Options NewType exposes its field-name mappings through the type callback" do
      options = AshSurface.Ported.InputParsing.Options
      assert Map.new(options.typescript_field_names()) == %{cache_enabled_1?: "cacheEnabled1"}

      assert FieldName.format_field_for_client(:cache_enabled_1?, options, :camel_case) ==
               "cacheEnabled1"

      # reverse direction
      {:ok, %{reverse: reverse}} =
        Mapping.build(
          fields: [:cache_enabled_1?],
          type_names: Map.new(options.typescript_field_names())
        )

      assert reverse == %{"cacheEnabled1" => :cache_enabled_1?}
    end
  end

  describe "entrypoint decoration" do
    test "projection facts are mirrored to the action's custom.ash_surface entry", %{
      surface: surface
    } do
      e = entrypoint(surface, :read_with_invalid_meta)
      assert %{"id" => id} = e.action.custom.ash_surface
      assert id == AshSurface.action_id(e)
      assert e.action.custom.ash_surface["profile"] == %{}
    end

    test "metadata_field_names is derived from the projection", %{surface: surface} do
      e = entrypoint(surface, :read_with_invalid_meta)

      assert e.action.custom.ash_surface["metadata_field_names"] ==
               %{"meta_1" => "meta1", "is_valid?" => "isValid", "field_2" => "field2"}

      {:ok, %{reverse: reverse}} =
        Mapping.build(
          fields: [:meta_1, :is_valid?, :field_2],
          field_names: %{meta_1: "meta1", is_valid?: "isValid", field_2: "field2"}
        )

      assert reverse == %{"meta1" => :meta_1, "isValid" => :is_valid?, "field2" => :field_2}
    end

    test "entrypoints without metadata_field_names get no mappings", %{surface: surface} do
      e = entrypoint(surface, :meta_unset)
      refute Map.has_key?(e.action.custom.ash_surface, "metadata_field_names")
    end
  end

  describe "accessors with nil / undecorated inputs" do
    test "all readers handle nil and undecorated inputs gracefully" do
      assert Dsl.read(%{}) == %{}
      assert Dsl.serialize(nil) == %{}

      assert AshSurface.IR.delegated(
               %Ash.Info.Manifest.Entrypoint{action: %{custom: %{}}},
               "semanticId"
             ) == nil

      assert FieldName.format(:foo, :camel_case) == "foo"
    end
  end

  describe "type_name decoration" do
    test "resource type_name is read from the DSL, nil when undeclared" do
      assert AshSurface.Resource.Info.type_name(Deco) == "Deco"
      assert AshSurface.Resource.Info.type_name(AshSurface.Ported.NotExposed) == nil
    end

    test "resource type_name honors a custom type_name" do
      assert AshSurface.Resource.Info.type_name(AshSurface.Ported.Todo) == "Todo"
    end

    test "type module type_name is present only when the type exports typescript_type_name/0" do
      palette = AshSurface.Ported.Todo.ColorPalette

      if function_exported?(palette, :typescript_type_name, 0),
        do: assert(is_binary(palette.typescript_type_name())),
        else: refute(function_exported?(palette, :typescript_type_name, 0))
    end
  end

  describe "exposed_metadata_fields decoration" do
    test "show_metadata unset writes no restriction (all metadata stays exposed)", %{
      surface: surface
    } do
      e = entrypoint(surface, :meta_unset)
      refute Map.has_key?(e.action.custom.ash_surface, "show_metadata")
      assert Enum.map(e.action.metadata, & &1.name) == [:some_string, :some_number, :other]
    end

    test "show_metadata: false exposes none", %{surface: surface} do
      assert entrypoint(surface, :meta_false).action.custom.ash_surface["show_metadata"] == false
    end

    test "show_metadata: [] exposes none", %{surface: surface} do
      assert entrypoint(surface, :meta_empty).action.custom.ash_surface["show_metadata"] == []
    end

    test "explicit list is preserved", %{surface: surface} do
      assert entrypoint(surface, :meta_two).action.custom.ash_surface["show_metadata"] ==
               ["some_string", "some_number"]
    end
  end

  describe "load restrictions & filter/sort decoration" do
    test "allowed_loads keeps the verbatim (flattened, sorted) list" do
      assert facts(:allow_user).allowed_loads == ["owner"]
      assert facts(:allow_user).denied_loads == nil
    end

    test "nested allowed_loads preserve the exact nested shape" do
      assert facts(:allow_nested).allowed_loads == ["comments", "comments.deco", "owner"]
    end

    test "denied_loads are carried as the deny list" do
      assert facts(:deny_user).denied_loads == ["owner"]
      assert facts(:deny_user).allowed_loads == nil
    end

    test "neither means no restriction" do
      f = facts(:meta_unset)
      assert f.allowed_loads == nil
      assert f.denied_loads == nil
    end

    test "enable_filter?/enable_sort? default true, false when disabled" do
      assert facts(:allow_user).enable_filter? == true
      assert facts(:allow_user).enable_sort? == true
      assert facts(:no_filter).enable_filter? == false
      assert facts(:no_sort).enable_sort? == false
    end
  end

  describe "compiled action manifest honours the real action config" do
    alias AshSurface.Manifest.ActionManifest
    alias AshSurface.RuntimeParity.Rpc.Pipeline

    defp manifest_action(surface, name, opts \\ []) do
      surface.manifest
      |> ActionManifest.build([Pipeline.entry(name, Deco, name, opts)])
      |> Map.fetch!("actions")
      |> hd()
    end

    test "enableFilter / enableSort are true by default and per the entry when disabled",
         %{surface: surface} do
      default = manifest_action(surface, :allow_user)
      assert default["enableFilter"] == true
      assert default["enableSort"] == true

      no_filter = manifest_action(surface, :no_filter, enable_filter?: false)
      assert no_filter["enableFilter"] == false
      assert no_filter["enableSort"] == true

      no_sort = manifest_action(surface, :no_sort, enable_sort?: false)
      assert no_sort["enableSort"] == false
      assert no_sort["enableFilter"] == true
    end

    test "show_metadata: false hides all metadata fields, unset exposes all, list restricts",
         %{surface: surface} do
      assert manifest_action(surface, :meta_unset)["metadataFields"] ==
               ["other", "some_number", "some_string"]

      assert manifest_action(surface, :meta_false, show_metadata: false)["metadataFields"] == []
      assert manifest_action(surface, :meta_empty, show_metadata: [])["metadataFields"] == []

      assert manifest_action(surface, :meta_two, show_metadata: [:some_string])[
               "metadataFields"
             ] == ["some_string"]
    end
  end
end
