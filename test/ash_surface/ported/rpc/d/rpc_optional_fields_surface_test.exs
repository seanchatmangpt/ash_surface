defmodule AshSurface.Ported.Rpc.D.RpcOptionalFieldsSurfaceTest do
  @moduledoc """
  Surface port of `rpc_optional_fields_test.exs`. The action result is a caller-built real
  `User` struct (no data layer); the pipeline applies request parsing, field selection and
  output formatting.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, User}

  @user_id "11111111-1111-1111-1111-111111111111"

  defp user(attrs \\ []),
    do:
      struct(
        User,
        Keyword.merge([id: @user_id, name: "Jane Doe", email: "jane@example.com"], attrs)
      )

  describe "optional fields parameter" do
    test "create action with nil fields returns empty data" do
      result =
        Rpc.run(
          %{
            "action" => "create_user",
            "input" => %{"name" => "Jane Doe", "email" => "jane@example.com"}
          },
          user()
        )

      assert result["success"] == true
      assert result["data"] == %{}
    end

    test "create action with empty fields list returns empty data" do
      result =
        Rpc.run(
          %{
            "action" => "create_user",
            "input" => %{"name" => "Jane Doe", "email" => "jane@example.com"},
            "fields" => []
          },
          user()
        )

      assert result["success"] == true
      assert result["data"] == %{}
    end

    test "create action with fields returns requested data" do
      result =
        Rpc.run(
          %{
            "action" => "create_user",
            "input" => %{"name" => "Jane Doe", "email" => "jane@example.com"},
            "fields" => ["id", "name", "email"]
          },
          user()
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert Map.has_key?(result["data"], "id")
      assert result["data"]["name"] == "Jane Doe"
      assert result["data"]["email"] == "jane@example.com"
    end

    test "update action with nil fields returns empty data" do
      result =
        Rpc.run(
          %{
            "action" => "update_user",
            "identity" => @user_id,
            "input" => %{"name" => "Updated Name"}
          },
          user(name: "Updated Name", email: "original@example.com")
        )

      assert result["success"] == true
      assert result["data"] == %{}
    end

    test "update action with empty fields list returns empty data" do
      result =
        Rpc.run(
          %{
            "action" => "update_user",
            "identity" => @user_id,
            "input" => %{"name" => "Updated Name"},
            "fields" => []
          },
          user(name: "Updated Name", email: "original@example.com")
        )

      assert result["success"] == true
      assert result["data"] == %{}
    end

    test "update action with fields returns requested data" do
      result =
        Rpc.run(
          %{
            "action" => "update_user",
            "identity" => @user_id,
            "input" => %{"name" => "Updated Name"},
            "fields" => ["id", "name", "email"]
          },
          user(name: "Updated Name", email: "original@example.com")
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["id"] == @user_id
      assert result["data"]["name"] == "Updated Name"
      assert result["data"]["email"] == "original@example.com"
    end

    test "read action still requires fields parameter" do
      result = Rpc.error(%{"action" => "list_users"})

      assert result["success"] == false
      assert is_list(result["errors"])
    end

    test "read action with empty fields should fail" do
      result = Rpc.error(%{"action" => "list_users", "fields" => []})

      assert result["success"] == false
      assert is_list(result["errors"])
    end
  end
end
