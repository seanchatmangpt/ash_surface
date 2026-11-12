defmodule AshSurface.Ported.Manifest.CustomSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/custom_test`
  (`AshTypescript.Manifest.Custom` accessors). ash_surface keeps the same facts
  in `AshSurface.Manifest.Dsl` (resource-level declarations) and the projection
  option defaults of `AshSurface.Resource.Info`; real fixture resources only.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Manifest.Dsl
  alias AshSurface.Resource.Info
  alias AshSurface.Resource.Projections

  describe "resolve_resource/1 (Dsl.serialize/1)" do
    test "resolves a domain resource module to its declarations" do
      dsl = Dsl.serialize(AshSurface.Ported.User)
      assert dsl["type_name"] == "User"
      assert dsl["field_names"]["address_line_1"] == "addressLine1"
    end

    test "resolves an embedded resource module" do
      assert is_map(Dsl.serialize(AshSurface.Ported.TodoMetadata))
    end

    test "returns an empty declaration map for a module that is not surface-extended" do
      assert Dsl.serialize(AshSurface.Ported.NotExposed) == %{}
      assert Dsl.serialize(Enum) == %{}
    end

    test "returns an empty map for nil / non-atoms" do
      assert Dsl.serialize(nil) == %{}
      assert Dsl.serialize("nope") == %{}
    end
  end

  describe "type_name/1" do
    test "returns the declared resource type name" do
      assert Info.type_name(AshSurface.Ported.User) == "User"
    end

    test "returns nil for an undeclared resource" do
      assert Info.type_name(AshSurface.Ported.NotExposed) == nil
    end
  end

  describe "exposed_metadata_fields/1" do
    test "an undeclared projection exposes no metadata" do
      assert Projections.option(%{}, :show_metadata) == nil
    end

    test "a declared show_metadata list is returned verbatim" do
      assert Projections.option(%{show_metadata: [:score]}, :show_metadata) == [:score]
    end
  end

  describe "load_restrictions / filter / sort accessors" do
    test "defaults on an undeclared projection" do
      p = %{}
      assert Projections.option(p, :allowed_loads) == nil
      assert Projections.option(p, :denied_loads) == nil
      assert Projections.option(p, :enable_filter?) == true
      assert Projections.option(p, :enable_sort?) == true
    end

    test "declared restrictions override the defaults" do
      p = %{allowed_loads: [:user], enable_filter?: false, enable_sort?: false}
      assert Projections.option(p, :allowed_loads) == [:user]
      assert Projections.option(p, :enable_filter?) == false
      assert Projections.option(p, :enable_sort?) == false
    end
  end
end
