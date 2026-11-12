defmodule AshSurface.Fixtures.TypedContainersFixtureTest do
  use ExUnit.Case, async: true
  alias AshSurface.ZodFixtures.TypedContainers, as: T

  defp attr(name), do: Ash.Resource.Info.attribute(T.Holder, name)

  test "struct, tuple, keyword types resolve to their Ash storage types" do
    assert Ash.Type.storage_type(attr(:stats).type) == :map
    assert Ash.Type.get_type(T.Point) == T.Point
    assert Ash.Type.get_type(T.Options) == T.Options
    assert T.Stats.subtype_of() == Ash.Type.Struct
    assert T.Point.subtype_of() == Ash.Type.Tuple
    assert T.Options.subtype_of() == Ash.Type.Keyword
  end

  test "array of unions and union with array member" do
    assert {:array, Ash.Type.Union} = attr(:mixed).type
    assert Keyword.has_key?(attr(:mixed).constraints[:items][:types], :stats)
    assert Ash.Type.Union = attr(:choice).type

    assert {:array, Ash.Type.String} =
             attr(:choice).constraints[:types][:many][:type] |> Ash.Type.get_type()
  end

  test "diamond embedded graph A -> B,C -> D -> E" do
    dep = fn mod, name -> Ash.Resource.Info.attribute(mod, name).type end
    assert dep.(T.NodeA, :left) == T.NodeB
    assert dep.(T.NodeA, :right) == T.NodeC
    assert dep.(T.NodeB, :down) == T.NodeD
    assert dep.(T.NodeC, :down) == T.NodeD
    assert dep.(T.NodeD, :leaf) == T.NodeE
  end
end
