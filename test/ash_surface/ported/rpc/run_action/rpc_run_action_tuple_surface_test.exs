defmodule AshSurface.Ported.RpcRunActionTupleSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_tuple_test.exs`: tuple coordinates are carried by
  hand-built `Todo` structs / a caller-supplied generic-action result and shaped by the result
  processor.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}
  import RpcFixtures, only: [todo: 1, user: 1]

  @coords %{latitude: 37.7749, longitude: -122.4194}
  @tid "22222222-2222-2222-2222-222222222299"

  defp todos do
    u = user(name: "Tuple User", email: "tuple@example.com")

    [
      todo(title: "Todo with Coordinates", coordinates: @coords, user: u),
      todo(id: @tid, title: "Todo without Coordinates", coordinates: nil, user: u)
    ]
  end

  defp coords_todo(result),
    do: Enum.find(result["data"], &(&1["title"] == "Todo with Coordinates"))

  describe "tuple field selection" do
    test "processes tuple field selection correctly" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", %{"coordinates" => ["latitude", "longitude"]}]
          },
          todos()
        )

      assert result["success"] == true
      assert is_list(result["data"])

      t = coords_todo(result)
      assert t != nil
      assert Map.has_key?(t, "id")
      assert Map.has_key?(t, "title")
      assert Map.has_key?(t, "coordinates")
      assert t["coordinates"]["latitude"] == 37.7749
      assert t["coordinates"]["longitude"] == -122.4194
    end

    test "processes partial tuple field selection" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", %{"coordinates" => ["latitude"]}]
          },
          todos()
        )

      assert result["success"] == true
      coordinates = coords_todo(result)["coordinates"]
      assert Map.has_key?(coordinates, "latitude")
      refute Map.has_key?(coordinates, "longitude")
      assert coordinates["latitude"] == 37.7749
    end

    test "processes tuple fields with relationships" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => [
              "id",
              "title",
              %{"coordinates" => ["latitude", "longitude"]},
              %{"user" => ["id", "name", "email"]}
            ]
          },
          todos()
        )

      assert result["success"] == true
      t = coords_todo(result)
      assert t["coordinates"]["latitude"] == 37.7749
      assert t["coordinates"]["longitude"] == -122.4194
      assert Map.has_key?(t["user"], "id")
      assert t["user"]["name"] == "Tuple User"
      assert t["user"]["email"] == "tuple@example.com"
    end
  end

  describe "generic action returning tuple type" do
    @info %{latitude: 37.7749, longitude: -122.4194, altitude: 50}

    defp info(fields),
      do: Rpc.run(%{"action" => "get_coordinates_info_todo", "fields" => fields}, @info)

    test "runs get_coordinates_info_todo action and processes field selection" do
      result = info(["latitude", "longitude", "altitude"])
      assert result["success"] == true, "failed: #{inspect(result)}"
      c = result["data"]
      assert is_map(c)
      assert c["latitude"] == 37.7749
      assert c["longitude"] == -122.4194
      assert c["altitude"] == 50
    end

    test "runs get_coordinates_info_todo action with partial field selection" do
      result = info(["latitude", "longitude"])
      assert result["success"] == true
      c = result["data"]
      assert c["latitude"] == 37.7749
      assert c["longitude"] == -122.4194
      refute Map.has_key?(c, "altitude")
    end

    test "runs get_coordinates_info_todo action with single field selection" do
      result = info(["altitude"])
      assert result["success"] == true
      c = result["data"]
      assert c["altitude"] == 50
      refute Map.has_key?(c, "latitude")
      refute Map.has_key?(c, "longitude")
    end

    test "validates get_coordinates_info_todo action returns correct data types" do
      c = info(["latitude", "longitude", "altitude"])["data"]
      assert is_float(c["latitude"])
      assert is_float(c["longitude"])
      assert is_integer(c["altitude"])
    end
  end

  describe "tuple field edge cases" do
    test "handles todos without tuple fields set" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", %{"coordinates" => ["latitude", "longitude"]}]
          },
          todos()
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")

        if t["coordinates"] != nil do
          assert is_map(t["coordinates"])
          assert Map.has_key?(t["coordinates"], "latitude")
          assert Map.has_key?(t["coordinates"], "longitude")
        end
      end)

      assert Enum.any?(result["data"], &is_nil(&1["coordinates"]))
    end

    test "handles only valid tuple fields" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", %{"coordinates" => ["latitude", "longitude"]}]
          },
          todos()
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        if t["coordinates"] != nil do
          assert Map.has_key?(t["coordinates"], "latitude")
          assert Map.has_key?(t["coordinates"], "longitude")
        end
      end)
    end
  end
end
