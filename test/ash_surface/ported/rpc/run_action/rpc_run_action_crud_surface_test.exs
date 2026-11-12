defmodule AshSurface.Ported.RpcRunActionCrudSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_crud_test.exs`: requests are parsed by
  `Rpc.Pipeline`, the action result is a hand-built real Ash struct (no data layer), and the
  result processor + formatter produce the client envelope.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Todo, User}

  @user_id "11111111-1111-1111-1111-111111111111"
  @todo_id "22222222-2222-2222-2222-222222222222"

  defp user, do: struct(User, id: @user_id, name: "Jane Doe", email: "jane@example.com")

  defp todo(attrs \\ []),
    do:
      struct(
        Todo,
        Keyword.merge(
          [
            id: @todo_id,
            title: "New Todo",
            completed: false,
            description: "d",
            priority: :medium,
            user_id: @user_id
          ],
          attrs
        )
      )

  describe "read actions" do
    test "processes valid fields correctly" do
      result =
        Rpc.run(%{"action" => "list_todos", "fields" => ["id", "title", "completed"]}, [
          todo(),
          todo(id: "33333333-3333-3333-3333-333333333333", title: "Two")
        ])

      assert result["success"] == true
      assert is_list(result["data"])

      Enum.each(result["data"], fn todo ->
        assert Map.has_key?(todo, "id")
        refute Map.has_key?(todo, "description")
        refute Map.has_key?(todo, "priority")
      end)
    end

    test "processes mixed attributes and loadable fields" do
      result =
        Rpc.run(
          %{"action" => "list_todos", "fields" => ["id", "title", "commentCount"]},
          [todo(comment_count: 3)]
        )

      assert result["success"] == true

      Enum.each(result["data"], fn todo ->
        assert Map.has_key?(todo, "id")
        assert is_integer(todo["commentCount"])
      end)
    end

    test "processes simple relationship fields" do
      result =
        Rpc.run(
          %{
            "action" => "list_todos",
            "fields" => ["id", "title", %{"user" => ["id", "email"]}]
          },
          [todo(user: user())]
        )

      assert result["success"] == true

      Enum.each(result["data"], fn todo ->
        assert Map.has_key?(todo, "id")
        assert Map.has_key?(todo, "user")
        user = todo["user"]
        assert Map.has_key?(user, "id")
        assert Map.has_key?(user, "email")
        refute Map.has_key?(user, "name")
      end)
    end
  end

  describe "create actions" do
    test "processes fields correctly" do
      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{"title" => "New Todo", "userId" => @user_id, "autoComplete" => false},
            "fields" => ["id", "title", "completed"]
          },
          todo()
        )

      assert result["success"] == true
      created = result["data"]
      assert created["title"] == "New Todo"
      assert created["completed"] == false
      refute Map.has_key?(created, "description")
      refute Map.has_key?(created, "priority")
    end

    test "processes relationships in create actions" do
      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{"title" => "Todo with User", "userId" => @user_id},
            "fields" => ["id", "title", %{"user" => ["id", "name"]}]
          },
          todo(title: "Todo with User", user: user())
        )

      assert result["success"] == true
      created = result["data"]
      assert created["title"] == "Todo with User"
      user_data = created["user"]
      assert user_data["id"] == @user_id
      assert user_data["name"] == "Jane Doe"
      refute Map.has_key?(user_data, "email")
    end
  end

  describe "update actions" do
    test "processes fields correctly" do
      created_at = ~U[2026-01-01 00:00:00.000000Z]

      result =
        Rpc.run(
          %{
            "action" => "update_todo",
            "identity" => @todo_id,
            "input" => %{"title" => "Updated Title", "completed" => true},
            "fields" => ["id", "title", "completed", "createdAt"]
          },
          todo(title: "Updated Title", completed: true, created_at: created_at)
        )

      assert result["success"] == true
      updated = result["data"]
      assert updated["id"] == @todo_id
      assert updated["title"] == "Updated Title"
      assert updated["completed"] == true
      assert updated["createdAt"] == DateTime.to_iso8601(created_at)
      refute Map.has_key?(updated, "description")
      refute Map.has_key?(updated, "priority")
    end

    test "update with a nil attribute value in the result is returned as nil (formatting only)" do
      result =
        Rpc.run(
          %{
            "action" => "update_todo",
            "identity" => @todo_id,
            "input" => %{"description" => nil},
            "fields" => ["id", "title", "description"]
          },
          todo(title: "Todo with Description", description: nil)
        )

      assert result["success"] == true
      assert result["data"]["id"] == @todo_id
      assert result["data"]["title"] == "Todo with Description"
      assert result["data"]["description"] == nil
    end
  end

  describe "field validation for CRUD actions" do
    test "returns error for invalid attribute" do
      result = Rpc.error(%{"action" => "list_todos", "fields" => ["invalidField"]})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "invalidField"
    end

    test "returns error for invalid nested field" do
      result = Rpc.error(%{"action" => "list_todos", "fields" => [%{"user" => ["invalidField"]}]})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "user.invalidField"
    end

    test "returns error for invalid relationship" do
      result =
        Rpc.error(%{"action" => "list_todos", "fields" => [%{"invalidRelationship" => ["id"]}]})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "invalidRelationship"
    end
  end
end
