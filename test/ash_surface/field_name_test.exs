defmodule AshSurface.FieldNameTest do
  use ExUnit.Case, async: true
  alias AshSurface.FieldName

  # Real formatter collaborators (hand-written, not mocks).
  def shout(f), do: f |> to_string() |> String.upcase()
  def wrap(f, pre), do: pre <> to_string(f)
  def wrap3(f, a, b), do: a <> to_string(f) <> b

  defp atom_exists?(s) do
    _ = String.to_existing_atom(s)
    true
  rescue
    ArgumentError -> false
  end

  describe "custom formatters" do
    test "{Module, :fun} and {Module, :fun, extra}" do
      assert FieldName.format(:user_name, {__MODULE__, :shout}) == "USER_NAME"
      assert FieldName.format(:user_name, {__MODULE__, :wrap, ["x_"]}) == "x_user_name"
      assert FieldName.format(:n, {__MODULE__, :wrap3, ["<", ">"]}) == "<n>"
    end

    test "overrides still win over custom formatter" do
      assert FieldName.format(:a, {__MODULE__, :shout}, %{a: "Z"}) == "Z"
    end

    test "validation returns typed errors" do
      assert FieldName.validate_formatter({__MODULE__, :shout}) == :ok
      assert FieldName.validate_formatter({__MODULE__, :wrap, ["a"]}) == :ok

      assert {:error, {:invalid_formatter, {:undefined_function, __MODULE__, :nope, 1}, _}} =
               FieldName.validate_formatter({__MODULE__, :nope})

      assert {:error, {:invalid_formatter, {:undefined_function, __MODULE__, :shout, 2}, _}} =
               FieldName.validate_formatter({__MODULE__, :shout, ["extra"]})

      assert {:error, {:invalid_formatter, :too_many_extra_args, _}} =
               FieldName.validate_formatter({__MODULE__, :wrap, [1, 2, 3, 4]})

      assert {:error, {:invalid_formatter, :unsupported, :bogus}} =
               FieldName.validate_formatter(:bogus)
    end

    test "unsupported/invalid formatter raises ArgumentError" do
      assert_raise ArgumentError, fn -> FieldName.compute(:a, :bogus) end
      assert_raise ArgumentError, fn -> FieldName.compute(:a, {__MODULE__, :nope}) end
    end

    test "short aliases" do
      assert FieldName.compute(:user_name, :camel) == "userName"
      assert FieldName.compute(:user_name, :pascal) == "UserName"
      assert FieldName.compute(:user_name, :snake) == "user_name"
    end
  end

  describe "atom safety" do
    test "resolves existing, passes atoms through" do
      _ = :user_name
      assert FieldName.parse_input("userName", :camel_case) == {:ok, :user_name}
      assert FieldName.parse_input(:already, :camel_case) == {:ok, :already}
    end

    test "never mints atoms (batch, long names, custom formatter)" do
      for i <- 1..500 do
        n = "atomBombBatch#{i}X#{System.unique_integer([:positive])}"
        assert FieldName.parse_input(n, :camel_case) == :error
        refute atom_exists?(n)
        refute atom_exists?(Macro.underscore(n))
      end

      assert FieldName.parse_input(String.duplicate("a", 300), :camel_case) == :error
      u = "custom_unknown_#{System.unique_integer([:positive])}"
      assert FieldName.parse_input(u, {__MODULE__, :shout}) == :error
      refute atom_exists?(u)
    end
  end

  describe "formatting comprehensive" do
    test "camel/pascal/snake incl. digits and question marks" do
      assert FieldName.compute(:address_line_1, :camel_case) == "addressLine1"
      # RBS: trailing `?` kept (reference parity); leading `_` preserved (KD-13)
      assert FieldName.compute(:is_active?, :camel_case) == "isActive?"
      assert FieldName.compute(:_x, :camel_case) == "_x"
      assert FieldName.compute("Foo_bar", :camel_case) == "fooBar"
      assert FieldName.compute("a_B", :camel_case) == "a_B"
      assert FieldName.compute("user_name", :pascal_case) == "UserName"
      assert FieldName.compute(:id, :camel_case) == "id"
      assert FieldName.compute(:id, :pascal_case) == "Id"
    end

    test "round trip through parse_input" do
      for f <- [:user_name, :created_at, :first_name_x] do
        for fm <- [:camel_case, :pascal_case, :snake_case] do
          assert FieldName.parse_input(FieldName.compute(f, fm), fm) == {:ok, f}
        end
      end
    end

    test "client_to_internal builds map and reports collisions" do
      assert {:ok, %{"userName" => :user_name}} =
               FieldName.client_to_internal([:user_name], :camel_case)

      assert {:error, {:collision, "x", [_, _]}} =
               FieldName.client_to_internal([:a, :b], :camel_case, %{a: "x", b: "x"})
    end
  end

  describe "parse_sort/1" do
    test "all prefixes and string-only input" do
      assert FieldName.parse_sort("++a") == {"++", "a"}
      assert FieldName.parse_sort("--a") == {"--", "a"}
      assert FieldName.parse_sort("+a") == {"+", "a"}
      assert FieldName.parse_sort("-a") == {"-", "a"}
      assert FieldName.parse_sort("a") == {"", "a"}
      assert FieldName.parse_sort("") == {"", ""}
      assert_raise FunctionClauseError, fn -> FieldName.parse_sort(:a) end
    end
  end
end
