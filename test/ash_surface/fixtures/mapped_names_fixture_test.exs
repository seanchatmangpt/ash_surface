defmodule AshSurface.Fixtures.MappedNamesFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.MappedNames.Gadget

  test "special field names are real Ash fields" do
    names = Ash.Resource.Info.attributes(Gadget) |> Enum.map(& &1.name)
    assert :is_active? in names and :address_1 in names and :line_2_text in names
    assert Ash.Resource.Info.calculation(Gadget, :ready?)
    assert Ash.Resource.Info.calculation(Gadget, :slot_1_name)
  end

  test "override map covers every special name" do
    overrides = Gadget.field_overrides()
    assert overrides[:is_active?] == "isActive"
    assert Enum.all?(Map.keys(overrides), &(Ash.Resource.Info.field(Gadget, &1) != nil))
  end

  test "map constraint fields keep ?/digit names" do
    %{constraints: c} = Ash.Resource.Info.attribute(Gadget, :settings)
    assert Keyword.keys(c[:fields]) == [:enabled?, :retry_3_count, :label]
  end
end
