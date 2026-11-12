defmodule AshSurface.Ported.Resource.MapFieldNamesUtilityTest do
  @moduledoc """
  Port of ash_typescript `resource/map_field_names_utility_test.exs`. The reference
  `AshTypescript.NameValidation` is `AshSurface.Naming` (`invalid_name?/1`,
  `make_name_better/1`). Same cases, same expectations.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Naming

  describe "invalid_name?/1" do
    test "returns true for names with underscores followed by digits" do
      for name <- ["field_1", "address_line_2", "item__3", "data___4"] do
        assert Naming.invalid_name?(name), "#{name} should be invalid"
      end
    end

    test "returns true for names with question marks" do
      for name <- ["field?", "is_active?", "enabled?"] do
        assert Naming.invalid_name?(name), "#{name} should be invalid"
      end
    end

    test "returns true for names with both patterns" do
      for name <- ["field_1?", "item_2?data", "test__5?"] do
        assert Naming.invalid_name?(name), "#{name} should be invalid"
      end
    end

    test "returns false for valid names" do
      for name <- ["normal_field", "camelCase", "snake_case", "field1", "item2", "field_name"] do
        refute Naming.invalid_name?(name), "#{name} should be valid"
      end
    end
  end

  describe "make_name_better/1" do
    test "removes underscores before digits" do
      for {input, expected} <- [
            {"field_1", "field1"},
            {"address_line_2", "address_line2"},
            {"item__3", "item3"},
            {"data___4", "data4"}
          ] do
        assert Naming.make_name_better(input) == expected
      end
    end

    test "removes question marks" do
      for {input, expected} <- [{"field?", "field"}, {"is_active?", "is_active"}] do
        assert Naming.make_name_better(input) == expected
      end
    end

    test "handles combined patterns" do
      for {input, expected} <- [
            {"field_1?", "field1"},
            {"item_2?data", "item2data"},
            {"test__5?", "test5"}
          ] do
        assert Naming.make_name_better(input) == expected
      end
    end

    test "leaves valid names unchanged" do
      for name <- ["normalField", "field_name", "camelCase", "snake_case", "field1", "item2"] do
        assert Naming.make_name_better(name) == name
      end
    end
  end
end
