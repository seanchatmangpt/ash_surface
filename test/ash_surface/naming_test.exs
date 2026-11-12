defmodule AshSurface.NamingTest do
  use ExUnit.Case, async: true
  alias AshSurface.{FieldName, Naming}

  test "naming predicates" do
    assert Naming.invalid_name?(:field_1)
    assert Naming.invalid_name?(:active?)
    refute Naming.invalid_name?(:user_name)
    assert Naming.identifier?(:user_name)
    refute Naming.identifier?(:"foo-bar")
    assert Naming.make_name_better(:field_1) == "field1"
    assert Naming.make_name_better(:active?) == "active"
  end

  test "format, override verbatim" do
    assert FieldName.format(:user_name, :camel_case) == "userName"
    assert FieldName.format(:user_name, :pascal_case) == "UserName"
    assert FieldName.format(:user_name, :snake_case) == "user_name"
    assert FieldName.format(:is_active?, :camel_case, %{is_active?: "Active_X"}) == "Active_X"
  end

  test "parse never mints atoms" do
    assert FieldName.parse_input("userName", :camel_case) == {:ok, :user_name}
    assert FieldName.parse_input("zzNeverExistedAtom9", :camel_case) == :error

    refute (try do
              String.to_existing_atom("zz_never_existed_atom9")
            rescue
              _ -> false
            end)
  end

  test "sort prefix and table" do
    assert FieldName.parse_sort("--userName") == {"--", "userName"}
    assert FieldName.parse_sort("-userName") == {"-", "userName"}
    assert FieldName.parse_sort("userName") == {"", "userName"}

    assert {:ok, %{"userName" => :user_name}} =
             FieldName.client_to_internal([:user_name], :camel_case)

    assert {:error, {:collision, "a", _}} =
             FieldName.client_to_internal([:a, :b], :camel_case, %{a: "a", b: "a"})
  end
end
