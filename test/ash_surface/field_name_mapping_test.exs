defmodule AshSurface.FieldName.MappingTest do
  use ExUnit.Case, async: true
  alias AshSurface.FieldName.Mapping

  @fields [:is_active?, :address_line_1, :user_name]

  test "precedence: type names > field_names > formatter" do
    opts = [
      fields: @fields,
      type_names: %{is_active?: "typeActive"},
      field_names: %{is_active?: "isActive", address_line_1: "addressLine1"}
    ]

    assert Mapping.resolve(:is_active?, opts) == "typeActive"
    assert Mapping.resolve(:address_line_1, opts) == "addressLine1"
    assert Mapping.resolve(:user_name, opts) == "userName"
  end

  test "mapped names are verbatim (no formatter applied)" do
    assert Mapping.resolve(:is_active?,
             field_names: %{is_active?: "Is_Active"},
             formatter: :snake_case
           ) ==
             "Is_Active"
  end

  test "build returns mapped and reverse maps" do
    assert {:ok, %{mapped: m, reverse: r}} =
             Mapping.build(fields: @fields, field_names: %{is_active?: "isActive"})

    assert m[:user_name] == "userName"
    assert r["isActive"] == :is_active?
    assert r["userName"] == :user_name
  end

  test "typed errors" do
    base = [fields: @fields]

    assert {:error, {:field_not_found, :ghost_1}} =
             Mapping.verify(base ++ [field_names: %{ghost_1: "g"}])

    assert {:error, {:field_not_invalid, :user_name}} =
             Mapping.verify(base ++ [field_names: %{user_name: "u"}])

    assert {:error, {:replacement_not_string, :is_active?, :x}} =
             Mapping.verify(base ++ [field_names: %{is_active?: :x}])

    assert {:error, {:replacement_invalid_identifier, :is_active?, "a-b"}} =
             Mapping.verify(base ++ [field_names: %{is_active?: "a-b"}])

    assert {:error, {:invalid_formatter, :unsupported, :bogus}} =
             Mapping.verify(base ++ [formatter: :bogus])
  end

  test "collision detection (mapped vs computed)" do
    assert {:error, {:collision, "userName", atoms}} =
             Mapping.verify(
               fields: [:user_name, :is_active?],
               field_names: %{is_active?: "userName"}
             )

    assert Enum.sort(atoms) == [:is_active?, :user_name]
  end

  test "collision from formatter alone" do
    assert {:error, {:collision, "a", _}} =
             Mapping.verify(fields: [:a, :b], formatter: {__MODULE__, :same})
  end

  def same(_), do: "a"

  test "verify_names for argument/map-constraint names" do
    assert Mapping.verify_names(%{arg_1: "arg1"}, [:arg_1]) == :ok
    assert {:error, {:field_not_found, :arg_1}} = Mapping.verify_names(%{arg_1: "arg1"}, [])
  end
end
