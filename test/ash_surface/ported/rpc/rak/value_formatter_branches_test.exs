defmodule AshSurface.Ported.Rpc.Rak.ValueFormatterBranchesTest do
  @moduledoc """
  Lane RAK. Exact-value court over the `Rpc.ValueFormatter` tuple, keyword and vector branches
  (no ported test reached them). Hand-built `%Ash.Info.Manifest.Type{}` values, real
  `Ash.Vector`; pure formatting, no action runs.
  """
  use ExUnit.Case, async: true

  alias Ash.Info.Manifest.Type
  alias AshSurface.RuntimeParity.Rpc.ValueFormatter

  defp scalar(module), do: %Type{kind: :scalar, module: module, constraints: []}

  defp fields do
    [
      %{name: :first_value, type: scalar(Ash.Type.Integer), allow_nil?: true, description: nil},
      %{name: :second_value, type: scalar(Ash.Type.String), allow_nil?: true, description: nil},
      %{name: :third_value, type: scalar(Ash.Type.Boolean), allow_nil?: true, description: nil}
    ]
  end

  defp tuple_type, do: %Type{kind: :tuple, module: Ash.Type.Tuple, element_types: fields()}
  defp keyword_type, do: %Type{kind: :keyword, module: Ash.Type.Keyword, fields: fields()}

  describe "tuple branch" do
    test "output maps each tuple position to its named client key, by index" do
      assert ValueFormatter.format({7, "x", true}, tuple_type(), [], :camel_case, :output) ==
               %{"firstValue" => 7, "secondValue" => "x", "thirdValue" => true}
    end

    test "positions are not interchangeable" do
      assert ValueFormatter.format({true, 1, "y"}, tuple_type(), [], :camel_case, :output) ==
               %{"firstValue" => true, "secondValue" => 1, "thirdValue" => "y"}
    end

    test "input keeps the client map shape with internal atom-parsed keys" do
      assert ValueFormatter.format(
               %{"firstValue" => 1, "secondValue" => "a"},
               tuple_type(),
               [],
               :camel_case,
               :input
             ) == %{first_value: 1, second_value: "a"}
    end

    test "snake_case formatter keeps snake keys" do
      assert ValueFormatter.format({1, "b", false}, tuple_type(), [], :snake_case, :output) ==
               %{"first_value" => 1, "second_value" => "b", "third_value" => false}
    end

    test "a non-tuple non-map value passes through" do
      assert ValueFormatter.format("raw", tuple_type(), [], :camel_case, :output) == "raw"
    end
  end

  describe "keyword branch" do
    test "output turns a keyword list into a client-keyed map" do
      assert ValueFormatter.format(
               [first_value: 3, second_value: "k"],
               keyword_type(),
               [],
               :camel_case,
               :output
             ) == %{"firstValue" => 3, "secondValue" => "k"}
    end

    test "map value is formatted the same way" do
      assert ValueFormatter.format(
               %{second_value: "m"},
               keyword_type(),
               [],
               :camel_case,
               :output
             ) == %{"secondValue" => "m"}
    end

    test "input client map parses to internal keys" do
      assert ValueFormatter.format(
               %{"thirdValue" => false},
               keyword_type(),
               [],
               :camel_case,
               :input
             ) == %{third_value: false}
    end

    test "duplicate keys in a keyword list: the last occurrence wins (map collapse order)" do
      assert ValueFormatter.format(
               [first_value: 1, second_value: "k", first_value: 9],
               keyword_type(),
               [],
               :camel_case,
               :output
             ) == %{"firstValue" => 9, "secondValue" => "k"}
    end

    test "non list non map passes through" do
      assert ValueFormatter.format(42, keyword_type(), [], :camel_case, :output) == 42
    end
  end

  describe "vector branch" do
    @vector_type %Type{kind: :scalar, module: Ash.Type.Vector, constraints: []}

    test "Ash.Vector becomes a plain float list" do
      {:ok, vector} = Ash.Vector.new([1.5, 2.5, 3.5])

      assert ValueFormatter.format(vector, @vector_type, [], :camel_case, :output) ==
               [1.5, 2.5, 3.5]
    end

    test "from_struct'd vector (binary data map) becomes a plain float list" do
      {:ok, v} = Ash.Vector.new([0.5, 4.0])
      raw = Map.from_struct(v)

      assert ValueFormatter.format(raw, @vector_type, [], :camel_case, :output) == [0.5, 4.0]
    end

    test "list input falls through untouched" do
      assert ValueFormatter.format([1.0, 2.0], @vector_type, [], :camel_case, :input) ==
               [1.0, 2.0]
    end
  end
end
