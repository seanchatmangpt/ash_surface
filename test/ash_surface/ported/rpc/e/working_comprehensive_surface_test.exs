defmodule AshSurface.Ported.Rpc.E.WorkingComprehensiveSurfaceTest do
  @moduledoc """
  Port of ash_typescript `rpc/working_comprehensive_test.exs` (12 tests) onto the non-actuating
  pipeline: requests are parsed (input mapping, refusals) and caller-built real Ash structs
  stand in for action results (no data layer, nothing is created/read/updated/destroyed).
  Persistence-dependent assertions (a created row being read back later, counts computed from
  stored comments, pagination windows over stored rows) become assertions on the shaped record
  the caller materialized.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.{Rpc, RpcFixtures}

  defp first_error(result), do: result["errors"] |> List.first()

  describe "basic CRUD operations" do
    test "001 create_todo -> get_todo -> list_todos complete workflow" do
      user = RpcFixtures.user(name: "John Doe", email: "john@example.com")
      user_id = user.id

      # create_user: result shaped from the materialized record
      user_result =
        Rpc.run(
          %{
            "action" => "create_user",
            "input" => %{"name" => "John Doe", "email" => "john@example.com"},
            "fields" => ["id", "name", "email"]
          },
          user
        )

      assert user_result["success"] == true
      assert user_result["data"]["id"] == user_id
      assert user_result["data"]["name"] == "John Doe"
      assert user_result["data"]["email"] == "john@example.com"

      # create_todo: the request input is parsed (client keys -> action input atoms)
      create_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Test Todo",
          "description" => "A comprehensive test todo",
          "priority" => "high",
          "status" => "pending",
          "dueDate" => "2024-12-31",
          "tags" => ["urgent", "testing"],
          "userId" => user_id,
          "metadata" => %{
            "category" => "work",
            "priorityScore" => 85,
            "isUrgent" => true,
            "tags" => ["backend", "urgent"]
          }
        },
        "fields" => [
          "id",
          "title",
          "description",
          "status",
          "priority",
          "dueDate",
          "tags",
          "created_at",
          %{"metadata" => ["category", "priorityScore", "isUrgent", "tags"]}
        ]
      }

      assert {:ok, request} = Rpc.parse(create_params)
      assert request.input.title == "Test Todo"
      assert request.input.user_id == user_id
      assert request.input.due_date == "2024-12-31"
      assert request.input.tags == ["urgent", "testing"]

      todo =
        RpcFixtures.todo(
          title: "Test Todo",
          description: "A comprehensive test todo",
          status: :pending,
          priority: :high,
          due_date: ~D[2024-12-31],
          tags: ["urgent", "testing"],
          created_at: ~U[2024-01-01 00:00:00Z],
          metadata:
            struct(P.TodoMetadata, %{
              category: "work",
              priority_score: 85,
              is_urgent: true,
              tags: ["backend", "urgent"]
            })
        )

      todo_result = Rpc.run(create_params, todo)
      assert todo_result["success"] == true
      todo_data = todo_result["data"]
      assert Map.has_key?(todo_data, "id")
      assert todo_data["title"] == "Test Todo"
      assert todo_data["description"] == "A comprehensive test todo"
      assert todo_data["status"] == "pending"
      assert todo_data["priority"] == "high"
      assert todo_data["dueDate"] == "2024-12-31"
      assert todo_data["tags"] == ["urgent", "testing"]
      assert Map.has_key?(todo_data, "createdAt")

      metadata = todo_data["metadata"]
      assert metadata["category"] == "work"
      assert metadata["priorityScore"] == 85
      assert metadata["isUrgent"] == true
      assert metadata["tags"] == ["backend", "urgent"]

      todo_id = todo_data["id"]

      # get_todo with calculations, relationship, embedded
      get_params = %{
        "action" => "get_todo",
        "input" => %{"id" => todo_id},
        "fields" => [
          "id",
          "title",
          "description",
          "status",
          "priority",
          "dueDate",
          "isOverdue",
          "daysUntilDue",
          %{"user" => ["id", "name", "email"]},
          %{"metadata" => ["category", "priorityScore", "isUrgent", "tags"]}
        ]
      }

      assert {:ok, get_request} = Rpc.parse(get_params)
      assert get_request.input.id == todo_id

      get_result =
        Rpc.run(
          get_params,
          Map.merge(todo, %{is_overdue: true, days_until_due: 3, user: user})
        )

      assert get_result["success"] == true
      get_data = get_result["data"]
      assert get_data["id"] == todo_id
      assert get_data["title"] == "Test Todo"
      assert get_data["status"] == "pending"
      assert get_data["priority"] == "high"
      assert get_data["dueDate"] == "2024-12-31"
      assert is_boolean(get_data["isOverdue"])
      assert is_integer(get_data["daysUntilDue"])
      assert get_data["user"]["id"] == user_id
      assert get_data["user"]["name"] == "John Doe"
      assert get_data["user"]["email"] == "john@example.com"
      assert get_data["metadata"]["category"] == "work"
      assert get_data["metadata"]["priorityScore"] == 85
      assert get_data["metadata"]["isUrgent"] == true

      # list_todos: page parsed; offset page shaped
      list_params = %{
        "action" => "list_todos",
        "input" => %{"priorityFilter" => "high"},
        "fields" => [
          "id",
          "title",
          "status",
          "priority",
          "created_at",
          %{"user" => ["id", "name"]}
        ],
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, list_request} = Rpc.parse(list_params)
      assert list_request.pagination == %{limit: 10, offset: 0}

      page =
        struct(Ash.Page.Offset, %{
          results: [Map.put(todo, :user, user)],
          limit: 10,
          offset: 0,
          count: 1,
          more?: false
        })

      list_result = Rpc.run(list_params, page)
      assert list_result["success"] == true
      assert is_list(list_result["data"]["results"])
      assert length(list_result["data"]["results"]) == 1
      listed = List.first(list_result["data"]["results"])
      assert listed["id"] == todo_id
      assert listed["title"] == "Test Todo"
      assert listed["priority"] == "high"
      assert Map.has_key?(listed, "createdAt")
      assert listed["user"]["id"] == user_id
      assert listed["user"]["name"] == "John Doe"

      # update_todo: identity + input parsed; updated record shaped
      update_params = %{
        "action" => "update_todo",
        "identity" => todo_id,
        "input" => %{"status" => "ongoing", "description" => "Updated description"},
        "fields" => ["id", "title", "status", "description"]
      }

      assert {:ok, update_request} = Rpc.parse(update_params)
      assert update_request.identity == todo_id
      assert update_request.input.status == "ongoing"

      update_result =
        Rpc.run(update_params, %{todo | status: :ongoing, description: "Updated description"})

      assert update_result["success"] == true
      assert update_result["data"]["id"] == todo_id
      assert update_result["data"]["title"] == "Test Todo"
      assert update_result["data"]["status"] == "ongoing"
      assert update_result["data"]["description"] == "Updated description"
    end

    test "002 destroy_todo operation returns correct response" do
      todo = RpcFixtures.todo(title: "Todo to Delete")

      destroy_params = %{"action" => "destroy_todo", "identity" => todo.id}
      assert {:ok, request} = Rpc.parse(destroy_params)
      assert request.identity == todo.id

      # the destroyed record is the action result; with no field selection the data is empty
      destroy_result = Rpc.run(destroy_params, todo)
      assert destroy_result["success"] == true
      assert destroy_result["data"] == %{}

      # a later get_todo for that id: the caller feeds the NotFound the read would produce
      not_found = {:error, Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: P.Todo})}

      get_result =
        Rpc.run(
          %{"action" => "get_todo", "input" => %{"id" => todo.id}, "fields" => ["id"]},
          not_found
        )

      assert get_result["success"] == false
      assert first_error(get_result)["type"] == "not_found"
    end
  end

  describe "simple calculations with field selection" do
    test "003 isOverdue and daysUntilDue calculations return correct types and values" do
      future = Date.add(Date.utc_today(), 7)
      todo = RpcFixtures.todo(title: "Future Todo", due_date: future)

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => todo.id},
            "fields" => ["id", "title", "dueDate", "isOverdue", "daysUntilDue"]
          },
          Map.merge(todo, %{is_overdue: false, days_until_due: 7})
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == todo.id
      assert data["title"] == "Future Todo"
      assert data["dueDate"] == Date.to_string(future)
      assert data["isOverdue"] == false
      assert is_integer(data["daysUntilDue"])
      assert data["daysUntilDue"] > 0
      assert data["daysUntilDue"] <= 7
    end
  end

  describe "aggregates and relationships" do
    test "004 aggregates (commentCount, helpfulCommentCount) return correct values" do
      todo =
        RpcFixtures.todo(title: "Aggregate Test Todo")
        |> Map.merge(%{
          comment_count: 2,
          helpful_comment_count: 1,
          has_comments: true,
          average_rating: 4.0,
          highest_rating: 5,
          comment_authors: ["Commenter 1", "Commenter 2"]
        })

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => todo.id},
            "fields" => [
              "id",
              "title",
              "commentCount",
              "helpfulCommentCount",
              "hasComments",
              "averageRating",
              "highestRating",
              "commentAuthors"
            ]
          },
          todo
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == todo.id
      assert data["title"] == "Aggregate Test Todo"
      assert data["commentCount"] == 2
      assert data["helpfulCommentCount"] == 1
      assert data["hasComments"] == true
      assert data["averageRating"] == 4.0
      assert data["highestRating"] == 5
      assert Enum.sort(data["commentAuthors"]) == ["Commenter 1", "Commenter 2"]
    end

    test "005 creating and fetching todos with user relationships and nested field selection" do
      user1 =
        RpcFixtures.user(
          id: Ash.UUID.generate(),
          name: "Primary User",
          email: "primary@example.com"
        )

      user2 =
        RpcFixtures.user(
          id: Ash.UUID.generate(),
          name: "Secondary User",
          email: "secondary@example.com"
        )

      comments = [
        RpcFixtures.comment(
          id: Ash.UUID.generate(),
          content: "User 1 comment on Todo 1",
          rating: 5,
          is_helpful: true,
          author_name: "Primary User"
        )
        |> Map.put(:user, user1),
        RpcFixtures.comment(
          id: Ash.UUID.generate(),
          content: "User 2 comment on Todo 1",
          rating: 4,
          is_helpful: false,
          author_name: "Secondary User"
        )
        |> Map.put(:user, user2)
      ]

      todo =
        RpcFixtures.todo(title: "User 1 Todo", user_id: user1.id)
        |> Map.merge(%{
          user: user1,
          comments: comments,
          comment_count: 2,
          helpful_comment_count: 1,
          average_rating: 4.5
        })

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => todo.id},
            "fields" => [
              "id",
              "title",
              "status",
              "priority",
              %{"user" => ["id", "name", "email", "active"]},
              %{
                "comments" => [
                  "id",
                  "content",
                  "rating",
                  "isHelpful",
                  "authorName",
                  %{"user" => ["id", "name", "email"]}
                ]
              },
              "commentCount",
              "helpfulCommentCount",
              "averageRating"
            ]
          },
          todo
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == todo.id
      assert data["title"] == "User 1 Todo"
      assert data["user"]["id"] == user1.id
      assert data["user"]["name"] == "Primary User"
      assert data["user"]["email"] == "primary@example.com"
      assert data["user"]["active"] == true

      assert is_list(data["comments"])
      assert length(data["comments"]) == 2
      [primary, secondary] = Enum.sort_by(data["comments"], & &1["authorName"])

      assert primary["content"] == "User 1 comment on Todo 1"
      assert primary["rating"] == 5
      assert primary["isHelpful"] == true
      assert primary["user"]["id"] == user1.id
      assert primary["user"]["name"] == "Primary User"

      assert secondary["content"] == "User 2 comment on Todo 1"
      assert secondary["rating"] == 4
      assert secondary["isHelpful"] == false
      assert secondary["user"]["id"] == user2.id
      assert secondary["user"]["name"] == "Secondary User"

      assert data["commentCount"] == 2
      assert data["helpfulCommentCount"] == 1
      assert data["averageRating"] == 4.5
    end
  end

  describe "union types with different storage modes" do
    test "006 content union type (:type_and_value storage) with untagged members" do
      for {input, selection, value, key} <- [
            {%{"note" => "This is a simple note"}, ["note"], "This is a simple note", "note"},
            {%{"priorityValue" => 8}, ["priorityValue"], 8, "priorityValue"}
          ] do
        params = %{
          "action" => "create_todo",
          "input" => %{
            "title" => "Content Todo",
            "userId" => RpcFixtures.user_id(),
            "content" => input
          },
          "fields" => ["id", "title", %{"content" => selection}]
        }

        assert {:ok, request} = Rpc.parse(params)
        assert request.input.title == "Content Todo"

        stored =
          case key do
            "note" -> %Ash.Union{type: :note, value: value}
            "priorityValue" -> %Ash.Union{type: :priority_value, value: value}
          end

        result = Rpc.run(params, RpcFixtures.todo(title: "Content Todo", content: stored))

        assert result["success"] == true
        assert result["data"]["content"][key] == value
      end
    end
  end

  describe "error scenarios and validation" do
    test "007 invalid action name returns proper error response" do
      result = Rpc.error(%{"action" => "nonexistent_action", "fields" => ["id"]})

      assert result["success"] == false
      error = first_error(result)
      assert error["type"] == "action_not_found"
      assert error["message"] == "RPC action %{actionName} not found"
      assert error["shortMessage"] == "Action not found"
      assert error["vars"]["actionName"] == "nonexistent_action"
    end

    test "008 invalid field names return specific validation errors" do
      result =
        Rpc.error(%{"action" => "list_todos", "fields" => ["id", "nonexistent_field", "title"]})

      assert result["success"] == false
      error = first_error(result)
      assert error["type"] == "unknown_field"
      assert error["message"] == "Unknown field %{field} for resource %{resource}"
      assert error["shortMessage"] == "Unknown field"
      assert error["vars"]["field"] == "nonexistentField"
      assert String.contains?(error["vars"]["resource"], "Todo")
      assert error["fields"] == ["nonexistentField"]
    end

    test "009 invalid relationship field names return nested error context" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", "title", %{"user" => ["id", "invalid_user_field"]}]
        })

      assert result["success"] == false
      error = first_error(result)
      assert error["type"] == "unknown_field"
      assert is_binary(error["message"])
    end

    test "010 missing required input parameters return validation errors" do
      # the action would fail changeset validation: the caller feeds the Required error
      required =
        Ash.Error.to_ash_error(%Ash.Error.Changes.Required{field: :user_id, resource: P.Todo})

      result =
        Rpc.run(
          %{
            "action" => "create_todo",
            "input" => %{"title" => "Missing User ID Todo"},
            "fields" => ["id", "title"]
          },
          {:error, required}
        )

      assert result["success"] == false
      assert first_error(result)["type"] == "required"
    end

    test "011 invalid pagination parameters return proper error" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", "title"],
          "page" => "invalid_pagination_format"
        })

      assert result["success"] == false
      assert first_error(result)["type"] == "invalid_pagination"
    end
  end

  describe "advanced scenarios and edge cases" do
    test "012 pagination with complex field selection works correctly" do
      users =
        for i <- 1..5,
            do:
              RpcFixtures.user(
                id: Ash.UUID.generate(),
                name: "Page User #{i}",
                email: "page#{i}@example.com"
              )

      todos =
        for {user, i} <- Enum.with_index(users, 1) do
          RpcFixtures.todo(
            id: Ash.UUID.generate(),
            title: "Paginated Todo #{i}",
            user_id: user.id
          )
          |> Map.merge(%{user: user, comment_count: 0})
        end

      params = fn offset ->
        %{
          "action" => "list_todos",
          "fields" => [
            "id",
            "title",
            "created_at",
            %{"user" => ["id", "name", "email"]},
            "commentCount"
          ],
          "sort" => "created_at",
          "page" => %{"limit" => 2, "offset" => offset}
        }
      end

      page = fn offset ->
        struct(Ash.Page.Offset, %{
          results: Enum.slice(todos, offset, 2),
          limit: 2,
          offset: offset,
          count: 5,
          more?: offset + 2 < 5
        })
      end

      assert {:ok, request} = Rpc.parse(params.(2))
      assert request.pagination == %{limit: 2, offset: 2}

      page1 = Rpc.run(params.(0), page.(0))
      page2 = Rpc.run(params.(2), page.(2))

      assert page1["success"] == true and page2["success"] == true
      assert length(page1["data"]["results"]) == 2
      assert length(page2["data"]["results"]) == 2

      ids1 = Enum.map(page1["data"]["results"], & &1["id"])
      ids2 = Enum.map(page2["data"]["results"], & &1["id"])
      assert MapSet.disjoint?(MapSet.new(ids1), MapSet.new(ids2))

      for t <- page1["data"]["results"] ++ page2["data"]["results"] do
        assert Map.has_key?(t, "user")
        assert Map.has_key?(t["user"], "name")
        assert Map.has_key?(t["user"], "email")
        assert t["commentCount"] == 0
      end
    end
  end
end
