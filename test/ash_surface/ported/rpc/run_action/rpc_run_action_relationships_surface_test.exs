defmodule AshSurface.Ported.RpcRunActionRelationshipsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_relationships_test.exs`: relationship graphs
  (todo.user, todo.comments, user.comments, user.todos, comment.user) are hand-built real Ash
  structs carrying loaded relationships; field selection and refusals run through the pipeline.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc
  import AshSurface.Ported.RpcFixtures, only: [todo: 1, user: 1, comment: 1]

  @t1 "22222222-2222-2222-2222-222222222201"
  @u1 "11111111-1111-1111-1111-111111111101"
  @u2 "11111111-1111-1111-1111-111111111102"

  defp list(todos, fields), do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)
  defp find(result, title), do: Enum.find(result["data"], &(&1["title"] == title))

  defp error_of(fields) do
    result = Rpc.error(%{"action" => "list_todos", "fields" => fields})
    assert result["success"] == false
    assert is_list(result["errors"])
    hd(result["errors"])
  end

  # todo "Todo with User": user + two comments
  defp rel_todo do
    u = user(id: @u1, name: "Relationship User", email: "relationship@example.com")

    c1 =
      comment(
        id: "33333333-3333-3333-3333-333333333301",
        content: "First comment",
        author_name: "First Author",
        rating: 5,
        user_id: @u1,
        todo_id: @t1
      )

    c2 =
      comment(
        id: "33333333-3333-3333-3333-333333333302",
        content: "Second comment",
        author_name: "Second Author",
        rating: 4,
        user_id: @u1,
        todo_id: @t1
      )

    todo(
      id: @t1,
      title: "Todo with User",
      description: "A todo for relationship testing",
      user_id: @u1,
      user: u,
      comments: [c1, c2]
    )
  end

  # nested graph: todo owned by user1; comments by user1 and user2; user1 has todos + comments
  defp nested_todo do
    u1 = user(id: @u1, name: "Nested User 1", email: "nested1@example.com")
    u2 = user(id: @u2, name: "Nested User 2", email: "nested2@example.com")

    c = fn n, content, u ->
      comment(
        id: "33333333-3333-3333-3333-3333333333" <> n,
        content: content,
        user_id: u.id,
        todo_id: @t1,
        rating: 3,
        user: u
      )
    end

    comments = [
      c.("11", "User1 comment on todo", u1),
      c.("12", "User2 comment on todo", u2),
      c.("13", "User comment from user1", u1)
    ]

    t = todo(id: @t1, title: "Nested Todo", user_id: @u1, comments: comments)
    u1 = %{u1 | comments: Enum.filter(comments, &(&1.user_id == @u1)), todos: [t]}
    %{t | user: u1}
  end

  describe "single level relationships" do
    test "processes belongs_to relationships" do
      result = list([rel_todo()], ["id", "title", %{"user" => ["id", "name", "email"]}])
      assert result["success"] == true
      t = find(result, "Todo with User")
      assert t != nil
      for k <- ["id", "title", "user"], do: assert(Map.has_key?(t, k))
      assert Map.has_key?(t["user"], "id")
      assert t["user"]["name"] == "Relationship User"
      assert t["user"]["email"] == "relationship@example.com"
      refute Map.has_key?(t, "description")
      refute Map.has_key?(t, "completed")
    end

    test "processes has_many relationships" do
      result = list([rel_todo()], ["id", "title", %{"comments" => ["id", "content", "rating"]}])
      assert result["success"] == true
      comments = find(result, "Todo with User")["comments"]
      assert is_list(comments)
      assert length(comments) >= 2

      Enum.each(comments, fn c ->
        for k <- ["id", "content", "rating"], do: assert(Map.has_key?(c, k))
        assert is_binary(c["content"])
        assert is_integer(c["rating"])
        refute Map.has_key?(c, "userId")
        refute Map.has_key?(c, "todoId")
      end)

      contents = Enum.map(comments, & &1["content"])
      assert "First comment" in contents
      assert "Second comment" in contents
    end

    test "processes multiple relationships at same level" do
      result =
        list([rel_todo()], [
          "id",
          "title",
          %{"user" => ["id", "name"], "comments" => ["id", "content"]}
        ])

      assert result["success"] == true
      t = find(result, "Todo with User")
      assert Map.has_key?(t, "user")
      assert Map.has_key?(t, "comments")
      assert Map.has_key?(t["user"], "name")
      refute Map.has_key?(t["user"], "email")

      Enum.each(t["comments"], fn c ->
        assert Map.has_key?(c, "id")
        assert Map.has_key?(c, "content")
        refute Map.has_key?(c, "rating")
      end)
    end
  end

  describe "nested relationships" do
    test "handles deeply nested relationships correctly" do
      result =
        list([nested_todo()], [
          "id",
          "title",
          %{"user" => ["id", "name", %{"comments" => ["id", "content"]}]}
        ])

      assert result["success"] == true
      t = find(result, "Nested Todo")
      assert t != nil
      assert t["user"]["name"] == "Nested User 1"
      user_comments = t["user"]["comments"]
      assert is_list(user_comments)
      assert length(user_comments) == 2

      Enum.each(user_comments, fn c ->
        assert Map.has_key?(c, "id")
        assert is_binary(c["content"])
      end)
    end

    test "handles three-level nested relationships" do
      u = nested_todo().user

      result =
        Rpc.run(
          %{
            "action" => "list_users",
            "fields" => [
              "id",
              "name",
              %{
                "todos" => [
                  "id",
                  "title",
                  %{"comments" => ["id", "content", %{"user" => ["id", "name"]}]}
                ]
              }
            ]
          },
          [u]
        )

      assert result["success"] == true
      nested_user = Enum.find(result["data"], &(&1["name"] == "Nested User 1"))
      assert nested_user != nil
      todos = nested_user["todos"]
      assert is_list(todos)
      nested = Enum.find(todos, &(&1["title"] == "Nested Todo"))
      assert nested != nil
      assert length(nested["comments"]) == 3

      Enum.each(nested["comments"], fn c ->
        for k <- ["id", "content", "user"], do: assert(Map.has_key?(c, k))
        assert Map.has_key?(c["user"], "id")
        assert Map.has_key?(c["user"], "name")
      end)

      assert nested["comments"] |> Enum.map(& &1["user"]["name"]) |> Enum.sort() ==
               ["Nested User 1", "Nested User 1", "Nested User 2"]
    end

    test "handles multiple nested relationships in different branches" do
      result =
        list([nested_todo()], [
          "id",
          "title",
          %{
            "user" => ["id", "name", %{"comments" => ["id", "content"]}],
            "comments" => ["id", "rating", %{"user" => ["id", "email"]}]
          }
        ])

      assert result["success"] == true
      t = find(result, "Nested Todo")
      for k <- ["id", "title", "user", "comments"], do: assert(Map.has_key?(t, k))
      assert is_list(t["user"]["comments"])
      assert Map.has_key?(t["user"], "name")

      Enum.each(t["comments"], fn c ->
        for k <- ["id", "rating", "user"], do: assert(Map.has_key?(c, k))
        assert Map.has_key?(c["user"], "id")
        assert Map.has_key?(c["user"], "email")
        refute Map.has_key?(c["user"], "name")
      end)
    end
  end

  describe "mixed simple fields and relationships" do
    defp mixed_todo do
      u = user(id: @u1, name: "Mixed User", email: "mixed@example.com")

      c =
        comment(
          id: "33333333-3333-3333-3333-333333333321",
          content: "Mixed comment",
          rating: 5,
          user_id: @u1,
          todo_id: @t1
        )

      u = %{u | comments: [c]}

      todo(
        id: @t1,
        title: "Mixed Fields Todo",
        description: "Testing mixed fields",
        user_id: @u1,
        user: u,
        comments: [c],
        created_at: ~U[2024-01-01 00:00:00Z],
        comment_count: 1,
        is_overdue: false
      )
    end

    test "handles mixed simple fields and nested relationships" do
      result =
        list([mixed_todo()], [
          "id",
          "title",
          "completed",
          %{"user" => ["id", "email", %{"comments" => ["id", "content", "rating"]}]},
          "createdAt"
        ])

      assert result["success"] == true
      t = find(result, "Mixed Fields Todo")
      for k <- ["id", "title", "completed", "createdAt", "user"], do: assert(Map.has_key?(t, k))
      assert is_boolean(t["completed"])
      for k <- ["id", "email", "comments"], do: assert(Map.has_key?(t["user"], k))
      refute Map.has_key?(t["user"], "name")

      Enum.each(t["user"]["comments"], fn c ->
        for k <- ["id", "content", "rating"], do: assert(Map.has_key?(c, k))
      end)
    end

    test "handles loadable fields mixed with relationships" do
      result =
        list([mixed_todo()], [
          "id",
          "title",
          "commentCount",
          %{"user" => ["id", "name"]},
          "isOverdue",
          %{"comments" => ["id", "content"]}
        ])

      assert result["success"] == true
      t = find(result, "Mixed Fields Todo")
      assert is_integer(t["commentCount"])
      assert is_boolean(t["isOverdue"])
      assert Map.has_key?(t["user"], "name")
      refute Map.has_key?(t["user"], "email")

      Enum.each(t["comments"], fn c ->
        assert Map.has_key?(c, "id")
        assert Map.has_key?(c, "content")
        refute Map.has_key?(c, "rating")
      end)
    end
  end

  describe "relationship validation" do
    test "returns error for invalid relationship field" do
      error = error_of([%{"user" => ["invalidField"]}])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "user.invalidField"
    end

    test "returns error for invalid nested relationship" do
      error = error_of([%{"user" => [%{"invalidRelationship" => ["id"]}]}])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "user.invalidRelationship"
    end

    test "returns error for invalid deeply nested field" do
      error = error_of([%{"user" => ["id", %{"comments" => ["id", "invalidField"]}]}])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "user.comments.invalidField"
    end

    test "validates relationship existence before processing nested fields" do
      error = error_of([%{"nonexistentRelation" => ["id", "name"]}])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "nonexistentRelation"
    end

    test "returns error for relationships requested as simple atoms without field specification" do
      error = error_of(["id", "user"])
      assert error["type"] == "requires_field_selection"
      assert List.first(error["fields"]) =~ "user"
    end
  end

  describe "edge cases" do
    test "returns error for empty relationship field lists" do
      error = error_of(["id", %{"user" => []}])
      assert error["type"] == "requires_field_selection"
    end

    test "handles relationship with only nested relationships (no direct fields)" do
      result =
        list([nested_todo()], [
          "id",
          "title",
          %{"user" => [%{"comments" => ["id", "content"]}]}
        ])

      assert result["success"] == true
      t = find(result, "Nested Todo")
      assert Map.has_key?(t, "id")
      u = t["user"]
      assert Map.has_key?(u, "comments")
      refute Map.has_key?(u, "name")
      refute Map.has_key?(u, "email")
      refute Map.has_key?(u, "id")
      assert is_list(u["comments"])

      Enum.each(u["comments"], fn c ->
        assert Map.has_key?(c, "id")
        assert Map.has_key?(c, "content")
      end)
    end
  end

  describe "relationship access restrictions" do
    test "rejects RPC action with fields accessing restricted relationships" do
      result =
        Rpc.error(%{
          "action" => "get_todo",
          "input" => %{"id" => @t1},
          "fields" => ["id", "title", %{"notExposedItems" => ["id", "name"]}]
        })

      assert result["success"] == false
      error = List.first(result["errors"])
      assert error["type"] == "unknown_field"
      assert List.first(error["fields"]) == "notExposedItems"
    end

    test "allows RPC action with fields accessing allowed relationships" do
      t =
        todo(
          id: @t1,
          title: "Security Test Todo",
          user: user(id: @u1, name: "Security Test User", email: "security@example.com")
        )

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => @t1},
            "fields" => ["id", "title", %{"user" => ["id", "name"]}]
          },
          t
        )

      assert result["success"] == true
      assert Map.has_key?(result["data"], "user")
      assert result["data"]["user"]["name"] == "Security Test User"
    end
  end
end
