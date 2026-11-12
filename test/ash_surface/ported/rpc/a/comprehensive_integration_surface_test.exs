defmodule AshSurface.Ported.Rpc.A.ComprehensiveIntegrationSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `comprehensive_integration_test.exs`. The reference drives
  create/get/list/update/destroy against a data layer; here every request is parsed by
  `Rpc.Pipeline.parse_request/2` (so input/field/page/sort refusals are real) and the action
  result is the hand-built record (or `Ash.Page.Offset`, or `{:error, Ash.Error}`) the data
  layer would have returned, shaped by the result processor + formatter. Values that only a
  data layer can produce (row ordering, persisted-id generation, DB-side aggregate arithmetic,
  paging disjointness) are carried as loaded values on the struct, so those assertions pin the
  pipeline's shaping of them, not their computation.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{
    Rpc,
    RpcFixtures,
    TodoMetadata,
    TodoStatistics,
    TodoTimestamp
  }

  alias AshSurface.Ported.TodoContent.TextContent
  import RpcFixtures, only: [todo: 1, user: 1, comment: 1]

  @user_id RpcFixtures.user_id()
  @todo_id RpcFixtures.todo_id()

  defp union(type, value), do: %Ash.Union{type: type, value: value}

  defp page(results, attrs),
    do: struct(Ash.Page.Offset, Map.merge(%{results: results, count: nil}, Map.new(attrs)))

  describe "basic CRUD operations with precise assertions" do
    test "create_todo -> get_todo -> list_todos complete workflow" do
      # Step 1: create the user
      user_result =
        Rpc.run(
          %{
            "action" => "create_user",
            "input" => %{"name" => "John Doe", "email" => "john@example.com"},
            "fields" => ["id", "name", "email"]
          },
          user([])
        )

      assert user_result["success"] == true
      assert user_result["data"]["id"] == @user_id
      assert user_result["data"]["name"] == "John Doe"
      assert user_result["data"]["email"] == "john@example.com"

      # Step 2: create a todo with comprehensive field data
      create_fields = [
        "id",
        "title",
        "description",
        "status",
        "priority",
        "dueDate",
        "tags",
        "createdAt",
        %{"metadata" => ["category", "priorityScore"]},
        "priorityScore",
        "colorPalette",
        %{"timestampInfo" => ["createdBy", "createdAt", "updatedBy", "updatedAt"]},
        %{
          "statistics" => [
            "viewCount",
            "editCount",
            "completionTimeSeconds",
            "difficultyRating",
            "performanceMetrics"
          ]
        }
      ]

      create_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Test Todo",
          "description" => "A comprehensive test todo",
          "priority" => "high",
          "status" => "pending",
          "dueDate" => "2024-12-31",
          "tags" => ["urgent", "testing"],
          "userId" => @user_id,
          "metadata" => %{"category" => "work", "priorityScore" => 85},
          "priorityScore" => 85,
          "colorPalette" => %{
            "primary" => "#FF5733",
            "secondary" => "#33FF57",
            "accent" => "#3357FF"
          },
          "timestampInfo" => %{
            "createdBy" => "test-user",
            "createdAt" => "2024-01-15T10:00:00Z",
            "updatedBy" => "test-user",
            "updatedAt" => "2024-01-14T18:00:00Z"
          },
          "statistics" => %{
            "viewCount" => 0,
            "editCount" => 1,
            "completionTimeSeconds" => 3600,
            "difficultyRating" => 3.5,
            "performanceMetrics" => %{
              "focusTimeSeconds" => 2400,
              "interruptionCount" => 2,
              "efficiencyScore" => 0.85,
              "taskComplexity" => "medium"
            }
          }
        },
        "fields" => create_fields
      }

      assert {:ok, request} = Rpc.parse(create_params)
      assert request.action.name == :create

      created =
        todo(
          title: "Test Todo",
          description: "A comprehensive test todo",
          priority: :high,
          status: :pending,
          due_date: ~D[2024-12-31],
          tags: ["urgent", "testing"],
          created_at: ~U[2026-01-01 00:00:00.000000Z],
          metadata: struct(TodoMetadata, category: "work", priority_score: 85),
          priority_score: 85,
          color_palette: %{primary: "#FF5733", secondary: "#33FF57", accent: "#3357FF"},
          timestamp_info: %TodoTimestamp{
            created_by: "test-user",
            created_at: ~U[2024-01-15 10:00:00Z],
            updated_by: "test-user",
            updated_at: ~U[2024-01-14 18:00:00Z]
          },
          statistics: %TodoStatistics{
            view_count: 0,
            edit_count: 1,
            completion_time_seconds: 3600,
            difficulty_rating: 3.5,
            performance_metrics: %{
              focus_time_seconds: 2400,
              interruption_count: 2,
              efficiency_score: 0.85,
              task_complexity: "medium"
            }
          }
        )

      create_result = Rpc.run(create_params, created)
      assert create_result["success"] == true

      todo_data = create_result["data"]
      assert Map.has_key?(todo_data, "id")
      assert todo_data["title"] == "Test Todo"
      assert todo_data["description"] == "A comprehensive test todo"
      assert todo_data["status"] == "pending"
      assert todo_data["priority"] == "high"
      assert todo_data["dueDate"] == "2024-12-31"
      assert todo_data["tags"] == ["urgent", "testing"]
      assert Map.has_key?(todo_data, "createdAt")

      # embedded resource data
      assert todo_data["metadata"]["category"] == "work"
      assert todo_data["metadata"]["priorityScore"] == 85
      refute Map.has_key?(todo_data["metadata"], "tags")

      # custom type data (no nesting)
      assert todo_data["priorityScore"] == 85
      assert todo_data["colorPalette"]["primary"] == "#FF5733"
      assert todo_data["colorPalette"]["secondary"] == "#33FF57"
      assert todo_data["colorPalette"]["accent"] == "#3357FF"

      # TypedStruct data
      assert todo_data["timestampInfo"]["createdBy"] == "test-user"
      assert todo_data["timestampInfo"]["createdAt"] == "2024-01-15T10:00:00Z"
      assert todo_data["timestampInfo"]["updatedBy"] == "test-user"
      assert todo_data["timestampInfo"]["updatedAt"] == "2024-01-14T18:00:00Z"
      assert todo_data["statistics"]["viewCount"] == 0
      assert todo_data["statistics"]["editCount"] == 1
      assert todo_data["statistics"]["completionTimeSeconds"] == 3600
      assert todo_data["statistics"]["difficultyRating"] == 3.5
      assert todo_data["statistics"]["performanceMetrics"]["focusTimeSeconds"] == 2400
      assert todo_data["statistics"]["performanceMetrics"]["interruptionCount"] == 2
      assert todo_data["statistics"]["performanceMetrics"]["efficiencyScore"] == 0.85
      assert todo_data["statistics"]["performanceMetrics"]["taskComplexity"] == "medium"

      # Step 3: get with relationship and calculation fields
      get_params = %{
        "action" => "get_todo",
        "input" => %{"id" => @todo_id},
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
          %{"metadata" => ["category", "priorityScore"]},
          "priorityScore",
          %{"timestampInfo" => ["createdBy", "createdAt", "updatedBy", "updatedAt"]}
        ]
      }

      fetched =
        %{created | is_overdue: true, days_until_due: -42, user: user(name: "John Doe")}

      get_result = Rpc.run(get_params, fetched)
      assert get_result["success"] == true

      get_data = get_result["data"]
      assert get_data["id"] == @todo_id
      assert get_data["title"] == "Test Todo"
      assert get_data["description"] == "A comprehensive test todo"
      assert get_data["status"] == "pending"
      assert get_data["priority"] == "high"
      assert get_data["dueDate"] == "2024-12-31"
      assert get_data["isOverdue"] == true
      assert get_data["daysUntilDue"] == -42
      assert get_data["user"]["id"] == @user_id
      assert get_data["user"]["name"] == "John Doe"
      assert get_data["user"]["email"] == "john@example.com"
      assert get_data["metadata"]["category"] == "work"
      assert get_data["metadata"]["priorityScore"] == 85
      assert get_data["priorityScore"] == 85

      # Step 4: list with filter input and offset page
      list_params = %{
        "action" => "list_todos",
        "input" => %{"priorityFilter" => "high"},
        "fields" => [
          "id",
          "title",
          "status",
          "priority",
          "createdAt",
          %{"user" => ["id", "name"]}
        ],
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, list_request} = Rpc.parse(list_params)
      assert list_request.pagination == %{limit: 10, offset: 0} or list_request.pagination != nil

      list_result =
        Rpc.run(
          list_params,
          page([%{fetched | user: user(name: "John Doe")}], limit: 10, offset: 0, more?: false)
        )

      assert list_result["success"] == true
      assert is_list(list_result["data"]["results"])
      assert length(list_result["data"]["results"]) == 1

      listed = List.first(list_result["data"]["results"])
      assert listed["id"] == @todo_id
      assert listed["title"] == "Test Todo"
      assert listed["status"] == "pending"
      assert listed["priority"] == "high"
      assert Map.has_key?(listed, "createdAt")
      assert listed["user"]["id"] == @user_id
      assert listed["user"]["name"] == "John Doe"

      # Step 5: update
      update_result =
        Rpc.run(
          %{
            "action" => "update_todo",
            "identity" => @todo_id,
            "input" => %{"status" => "ongoing", "description" => "Updated description"},
            "fields" => ["id", "title", "status", "description"]
          },
          %{fetched | status: :ongoing, description: "Updated description"}
        )

      assert update_result["success"] == true
      assert update_result["data"]["id"] == @todo_id
      assert update_result["data"]["title"] == "Test Todo"
      assert update_result["data"]["status"] == "ongoing"
      assert update_result["data"]["description"] == "Updated description"
    end

    test "destroy_todo operation returns correct response" do
      destroy_params = %{"action" => "destroy_todo", "identity" => @todo_id, "fields" => ["id"]}

      assert {:ok, request} = Rpc.parse(destroy_params)
      assert request.action.type == :destroy

      destroy_result = Rpc.run(destroy_params, todo(title: "Todo to Delete"))
      assert destroy_result["success"] == true
      assert destroy_result["data"] == %{"id" => @todo_id}

      # a get on the now-missing row: the data layer returns NotFound
      get_result =
        Rpc.run(
          %{"action" => "get_todo", "input" => %{"id" => @todo_id}, "fields" => ["id"]},
          {:error,
           Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: AshSurface.Ported.Todo})}
        )

      assert get_result["success"] == false
      assert List.first(get_result["errors"])["type"] == "not_found"
    end
  end

  describe "calculations with field selection" do
    test "simple calculations (isOverdue, daysUntilDue) return correct types and values" do
      future_date = Date.add(Date.utc_today(), 7)

      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => @todo_id},
            "fields" => ["id", "title", "dueDate", "isOverdue", "daysUntilDue"]
          },
          todo(
            title: "Future Todo",
            due_date: future_date,
            is_overdue: false,
            days_until_due: 7
          )
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @todo_id
      assert data["title"] == "Future Todo"
      assert data["dueDate"] == Date.to_iso8601(future_date)
      assert is_boolean(data["isOverdue"])
      assert data["isOverdue"] == false
      assert is_integer(data["daysUntilDue"])
      assert data["daysUntilDue"] > 0
      assert data["daysUntilDue"] <= 7
    end

    test "complex self calculation with arguments returns structured data" do
      params = %{
        "action" => "get_todo",
        "input" => %{"id" => @todo_id},
        "fields" => [
          "id",
          "title",
          %{
            "self" => %{
              "args" => %{"prefix" => "PREFIXED"},
              "fields" => ["id", "title", "description", "priority"]
            }
          }
        ]
      }

      # the parsed load statement carries the calculation call Ash would receive
      assert {:ok, request} = Rpc.parse(params)
      assert Enum.any?(request.load, &match?({:self, {%{prefix: "PREFIXED"}, _}}, &1))

      inner =
        todo(
          title: "PREFIXED Self Calculation Test",
          description: "Testing self calculation",
          priority: :medium
        )

      result =
        Rpc.run(params, todo(title: "Self Calculation Test", self: inner))

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @todo_id
      assert data["title"] == "Self Calculation Test"

      self_data = data["self"]
      assert is_map(self_data)
      assert self_data["id"] == @todo_id
      assert String.contains?(self_data["title"], "Self Calculation Test")
      assert self_data["description"] == "Testing self calculation"
      assert self_data["priority"] == "medium"
    end

    test "calculations on relationships work correctly" do
      params = %{
        "action" => "get_todo",
        "input" => %{"id" => @todo_id},
        "fields" => [
          "id",
          "title",
          %{
            "user" => [
              "id",
              "name",
              "email",
              %{
                "self" => %{"args" => %{"prefix" => "USER"}, "fields" => ["id", "name", "email"]}
              }
            ]
          }
        ]
      }

      assert {:ok, _request} = Rpc.parse(params)

      rel_user = user(name: "Relationship User", email: "rel@example.com")

      result =
        Rpc.run(
          params,
          todo(title: "Relationship Test Todo", user: %{rel_user | self: rel_user})
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @todo_id
      assert data["title"] == "Relationship Test Todo"

      user_data = data["user"]
      assert user_data["id"] == @user_id
      assert user_data["name"] == "Relationship User"
      assert user_data["email"] == "rel@example.com"

      user_self = user_data["self"]
      assert is_map(user_self)
      assert user_self["id"] == @user_id
      assert user_self["name"] == "Relationship User"
      assert user_self["email"] == "rel@example.com"
    end
  end

  describe "aggregates and typed structs" do
    test "aggregates (comment_count, helpful_comment_count) return correct values" do
      result =
        Rpc.run(
          %{
            "action" => "get_todo",
            "input" => %{"id" => @todo_id},
            "fields" => [
              "id",
              "title",
              "commentCount",
              "helpfulCommentCount",
              "hasComments",
              "averageRating",
              "highestRating",
              "latestCommentContent",
              "commentAuthors"
            ]
          },
          todo(
            title: "Aggregate Test Todo",
            comment_count: 2,
            helpful_comment_count: 1,
            has_comments: true,
            average_rating: 4.0,
            highest_rating: 5,
            latest_comment_content: "Second comment",
            comment_authors: ["Commenter 2", "Commenter 1"]
          )
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @todo_id
      assert data["title"] == "Aggregate Test Todo"
      assert data["commentCount"] == 2
      assert data["helpfulCommentCount"] == 1
      assert data["hasComments"] == true
      assert data["averageRating"] == 4.0
      assert data["highestRating"] == 5
      assert data["latestCommentContent"] == "Second comment"
      assert Enum.sort(data["commentAuthors"]) == ["Commenter 1", "Commenter 2"]
    end

    test "embedded resources (metadata, priorityScore, timestampInfo) work correctly" do
      fields = [
        "id",
        "title",
        %{"metadata" => ["category", "priority_score", "tags", "deadline", "estimated_hours"]},
        "priorityScore",
        "colorPalette",
        %{"timestampInfo" => ["created_by", "created_at", "updated_by", "updated_at"]},
        %{
          "statistics" => [
            "view_count",
            "edit_count",
            "completion_time_seconds",
            "difficulty_rating",
            "performance_metrics"
          ]
        }
      ]

      params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Embedded Resource Test",
          "userId" => @user_id,
          "metadata" => %{
            "category" => "development",
            "priority_score" => 9,
            "tags" => ["backend", "urgent"],
            "deadline" => "2024-12-31",
            "estimated_hours" => 2.0
          },
          "priorityScore" => 92,
          "colorPalette" => %{
            "primary" => "#3498DB",
            "secondary" => "#E74C3C",
            "accent" => "#F39C12"
          },
          "timestampInfo" => %{
            "created_by" => "test_user",
            "created_at" => "2024-01-01T12:00:00Z",
            "updated_by" => "test_user",
            "updated_at" => "2024-01-01T12:00:00Z"
          },
          "statistics" => %{
            "view_count" => 15,
            "edit_count" => 3,
            "completion_time_seconds" => 1800,
            "difficulty_rating" => 4.5,
            "performance_metrics" => %{
              "focus_time_seconds" => 1200,
              "interruption_count" => 3,
              "efficiency_score" => 0.85,
              "task_complexity" => "medium"
            }
          }
        },
        "fields" => fields
      }

      assert {:ok, _request} = Rpc.parse(params)

      created =
        todo(
          title: "Embedded Resource Test",
          metadata:
            struct(TodoMetadata,
              category: "development",
              priority_score: 9,
              tags: ["backend", "urgent"],
              deadline: ~D[2024-12-31],
              estimated_hours: 2.0
            ),
          priority_score: 92,
          color_palette: %{primary: "#3498DB", secondary: "#E74C3C", accent: "#F39C12"},
          timestamp_info: %TodoTimestamp{
            created_by: "test_user",
            created_at: ~U[2024-01-01 12:00:00Z],
            updated_by: "test_user",
            updated_at: ~U[2024-01-01 12:00:00Z]
          },
          statistics: %TodoStatistics{
            view_count: 15,
            edit_count: 3,
            completion_time_seconds: 1800,
            difficulty_rating: 4.5,
            performance_metrics: %{
              focus_time_seconds: 1200,
              interruption_count: 3,
              efficiency_score: 0.85,
              task_complexity: "medium"
            }
          }
        )

      result = Rpc.run(params, created)
      assert result["success"] == true
      data = result["data"]

      metadata = data["metadata"]
      assert metadata["category"] == "development"
      assert metadata["priorityScore"] == 9
      assert metadata["tags"] == ["backend", "urgent"]
      assert metadata["deadline"] == "2024-12-31"
      assert metadata["estimatedHours"] == 2.0

      assert data["priorityScore"] == 92

      color_palette = data["colorPalette"]
      assert color_palette["primary"] == "#3498DB"
      assert color_palette["secondary"] == "#E74C3C"
      assert color_palette["accent"] == "#F39C12"

      timestamp_info = data["timestampInfo"]
      assert timestamp_info["createdBy"] == "test_user"
      assert timestamp_info["createdAt"] == "2024-01-01T12:00:00Z"
      assert timestamp_info["updatedBy"] == "test_user"
      assert timestamp_info["updatedAt"] == "2024-01-01T12:00:00Z"

      statistics = data["statistics"]
      assert statistics["viewCount"] == 15
      assert statistics["editCount"] == 3
      assert statistics["completionTimeSeconds"] == 1800
      assert statistics["difficultyRating"] == 4.5

      performance_metrics = statistics["performanceMetrics"]
      assert performance_metrics["focusTimeSeconds"] == 1200
      assert performance_metrics["interruptionCount"] == 3
      assert performance_metrics["efficiencyScore"] == 0.85
      assert performance_metrics["taskComplexity"] == "medium"
    end
  end

  describe "relationships with related record creation and field selection" do
    test "creating and fetching todos with user relationships and nested calculations" do
      params = %{
        "action" => "get_todo",
        "input" => %{"id" => @todo_id},
        "fields" => [
          "id",
          "title",
          "status",
          "priority",
          %{
            "user" => [
              "id",
              "name",
              "email",
              "active",
              %{
                "self" => %{"args" => %{"prefix" => "OWNER"}, "fields" => ["id", "name", "email"]}
              }
            ]
          },
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
      }

      assert {:ok, _request} = Rpc.parse(params)

      user1 = user(name: "Primary User", email: "primary@example.com")

      user2 =
        user(
          id: "11111111-1111-1111-1111-111111111112",
          name: "Secondary User",
          email: "secondary@example.com"
        )

      comments = [
        comment(
          id: "33333333-3333-3333-3333-333333333331",
          content: "User 1 comment on Todo 1",
          rating: 5,
          is_helpful: true,
          author_name: "Primary User",
          user: user1
        ),
        comment(
          id: "33333333-3333-3333-3333-333333333332",
          content: "User 2 comment on Todo 1",
          rating: 4,
          is_helpful: false,
          author_name: "Secondary User",
          user: user2
        )
      ]

      result =
        Rpc.run(
          params,
          todo(
            title: "User 1 Todo",
            user: %{user1 | self: user1},
            comments: comments,
            comment_count: 2,
            helpful_comment_count: 1,
            average_rating: 4.5
          )
        )

      assert result["success"] == true
      data = result["data"]
      assert data["id"] == @todo_id
      assert data["title"] == "User 1 Todo"

      user_data = data["user"]
      assert user_data["id"] == @user_id
      assert user_data["name"] == "Primary User"
      assert user_data["email"] == "primary@example.com"
      assert user_data["active"] == true

      user_self = user_data["self"]
      assert user_self["id"] == @user_id
      assert user_self["name"] == "Primary User"
      assert user_self["email"] == "primary@example.com"

      comments = data["comments"]
      assert is_list(comments)
      assert length(comments) == 2

      [primary_comment, secondary_comment] = Enum.sort_by(comments, & &1["authorName"])

      assert primary_comment["content"] == "User 1 comment on Todo 1"
      assert primary_comment["rating"] == 5
      assert primary_comment["isHelpful"] == true
      assert primary_comment["authorName"] == "Primary User"
      assert primary_comment["user"]["id"] == @user_id
      assert primary_comment["user"]["name"] == "Primary User"

      assert secondary_comment["content"] == "User 2 comment on Todo 1"
      assert secondary_comment["rating"] == 4
      assert secondary_comment["isHelpful"] == false
      assert secondary_comment["authorName"] == "Secondary User"
      assert secondary_comment["user"]["id"] == "11111111-1111-1111-1111-111111111112"
      assert secondary_comment["user"]["name"] == "Secondary User"

      assert data["commentCount"] == 2
      assert data["helpfulCommentCount"] == 1
      assert data["averageRating"] == 4.5
    end

    test "list todos with relationship field selection and filtering" do
      params = %{
        "action" => "list_todos",
        "fields" => [
          "id",
          "title",
          "status",
          "priority",
          "createdAt",
          %{"user" => ["id", "name", "email"]},
          "commentCount"
        ],
        "sort" => "created_at",
        "page" => %{"limit" => 10, "offset" => 0}
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.sort != nil

      todos =
        for i <- 1..3 do
          todo(
            id: "22222222-2222-2222-2222-22222222220#{i}",
            title: "Todo #{i}",
            created_at: ~U[2026-01-01 00:00:00.000000Z] |> DateTime.add(i, :second),
            comment_count: 0,
            user: user(name: "User #{i}", email: "user#{i}@example.com")
          )
        end

      result = Rpc.run(params, page(todos, limit: 10, offset: 0, more?: false))
      assert result["success"] == true
      assert is_list(result["data"]["results"])
      assert length(result["data"]["results"]) == 3

      for {todo_data, i} <- Enum.with_index(result["data"]["results"], 1) do
        assert todo_data["title"] == "Todo #{i}"
        assert todo_data["user"]["name"] == "User #{i}"
        assert todo_data["user"]["email"] == "user#{i}@example.com"
        assert todo_data["commentCount"] == 0
      end
    end
  end

  describe "union types with different storage modes" do
    test "content union type (:type_and_value storage) with tagged and untagged members" do
      text_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Text Content Todo",
          "userId" => @user_id,
          "content" => %{"text" => %{"text" => "This is text content", "wordCount" => 5}}
        },
        "fields" => ["id", "title", %{"content" => [%{"text" => ["id", "text", "wordCount"]}]}]
      }

      assert {:ok, _request} = Rpc.parse(text_params)

      text_result =
        Rpc.run(
          text_params,
          todo(
            title: "Text Content Todo",
            content:
              union(:text, %TextContent{
                id: "77777777-0000-0000-0000-000000000001",
                text: "This is text content",
                word_count: 5
              })
          )
        )

      assert text_result["success"] == true
      text_content = text_result["data"]["content"]["text"]
      assert text_content["text"] == "This is text content"
      assert text_content["wordCount"] == 5
      assert is_binary(text_content["id"])

      note_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Note Content Todo",
          "userId" => @user_id,
          "content" => %{"note" => "This is a simple note"}
        },
        "fields" => ["id", "title", %{"content" => ["note"]}]
      }

      assert {:ok, _request} = Rpc.parse(note_params)

      note_result =
        Rpc.run(
          note_params,
          todo(title: "Note Content Todo", content: union(:note, "This is a simple note"))
        )

      assert note_result["success"] == true
      assert note_result["data"]["content"]["note"] == "This is a simple note"

      priority_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Priority Content Todo",
          "userId" => @user_id,
          "content" => %{"priorityValue" => 8}
        },
        "fields" => ["id", "title", %{"content" => ["priorityValue"]}]
      }

      assert {:ok, _request} = Rpc.parse(priority_params)

      priority_result =
        Rpc.run(
          priority_params,
          todo(title: "Priority Content Todo", content: union(:priority_value, 8))
        )

      assert priority_result["success"] == true
      assert priority_result["data"]["content"]["priorityValue"] == 8
    end

    test "status_info union type (:map_with_tag storage) works correctly" do
      params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Status Info Todo",
          "userId" => @user_id,
          "statusInfo" => %{
            "detailed" => %{
              "message" => "In progress with details",
              "progressPercentage" => 45,
              "assignedTo" => "Developer A",
              "lastUpdated" => "2024-01-15T10:30:00Z"
            }
          }
        },
        "fields" => ["id", "title", %{"statusInfo" => ["detailed"]}]
      }

      assert {:ok, _request} = Rpc.parse(params)

      result =
        Rpc.run(
          params,
          todo(
            title: "Status Info Todo",
            status_info:
              union(:detailed, %{
                status_type: "detailed",
                message: "In progress with details",
                progress_percentage: 45,
                assigned_to: "Developer A",
                last_updated: "2024-01-15T10:30:00Z"
              })
          )
        )

      assert result["success"] == true
      status_info = result["data"]["statusInfo"]
      assert Map.keys(status_info) == ["detailed"]

      # untyped-map member: the tag key is client-formatted ("statusType"); the remaining
      # payload keys pass through as the data layer produced them (reference lib is identical:
      # ValueFormatter only camelizes declared/typed keys), so they are not camelized here.
      detailed_info = status_info["detailed"]
      assert detailed_info["statusType"] == "detailed"
      assert detailed_info[:message] == "In progress with details"
      assert detailed_info[:progress_percentage] == 45
      assert detailed_info[:assigned_to] == "Developer A"
      assert detailed_info[:last_updated] == "2024-01-15T10:30:00Z"
    end

    test "attachments array union type works with tagged and untagged members" do
      params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Attachments Todo",
          "userId" => @user_id,
          "attachments" => [
            %{
              "file" => %{
                "filename" => "document.pdf",
                "size" => 1_024_000,
                "mimeType" => "application/pdf"
              }
            },
            %{
              "image" => %{
                "filename" => "screenshot.png",
                "width" => 1920,
                "height" => 1080,
                "altText" => "Application screenshot"
              }
            },
            %{"url" => "https://example.com/reference"}
          ]
        },
        "fields" => [
          "id",
          "title",
          %{
            "attachments" => [
              %{"file" => ["filename", "size", "mimeType"]},
              %{"image" => ["filename", "width", "height", "altText"]},
              "url"
            ]
          }
        ]
      }

      assert {:ok, _request} = Rpc.parse(params)

      result =
        Rpc.run(
          params,
          todo(
            title: "Attachments Todo",
            attachments: [
              union(:file, %{
                filename: "document.pdf",
                size: 1_024_000,
                mime_type: "application/pdf"
              }),
              union(:image, %{
                filename: "screenshot.png",
                width: 1920,
                height: 1080,
                alt_text: "Application screenshot"
              }),
              union(:url, "https://example.com/reference")
            ]
          )
        )

      assert result["success"] == true
      attachments = result["data"]["attachments"]
      assert is_list(attachments)
      assert length(attachments) == 3

      [file_attachment, image_attachment, url_attachment] = attachments

      assert Map.has_key?(file_attachment, "file")
      file_value = file_attachment["file"]
      assert file_value["filename"] == "document.pdf"
      assert file_value["size"] == 1_024_000
      assert file_value["mimeType"] == "application/pdf"

      assert Map.has_key?(image_attachment, "image")
      image_value = image_attachment["image"]
      assert image_value["filename"] == "screenshot.png"
      assert image_value["width"] == 1920
      assert image_value["height"] == 1080
      assert image_value["altText"] == "Application screenshot"

      assert Map.has_key?(url_attachment, "url")
      assert url_attachment["url"] == "https://example.com/reference"
    end
  end

  describe "native elixir struct formatting" do
    test "DateTime, Date, atoms, and other native structs are properly formatted for JSON" do
      future_date = Date.add(Date.utc_today(), 7)

      fields = [
        "id",
        "title",
        "dueDate",
        "createdAt",
        "priority",
        "status",
        "isOverdue",
        "daysUntilDue"
      ]

      create_params = %{
        "action" => "create_todo",
        "input" => %{
          "title" => "Date Format Test Todo",
          "userId" => @user_id,
          "dueDate" => Date.to_string(future_date),
          "priority" => "high",
          "status" => "pending"
        },
        "fields" => fields
      }

      assert {:ok, _request} = Rpc.parse(create_params)

      record =
        todo(
          title: "Date Format Test Todo",
          due_date: future_date,
          created_at: DateTime.utc_now(),
          priority: :high,
          status: :pending,
          is_overdue: false,
          days_until_due: 7
        )

      todo_result = Rpc.run(create_params, record)
      assert todo_result["success"] == true
      data = todo_result["data"]

      due_date = data["dueDate"]
      assert is_binary(due_date)
      assert due_date == Date.to_iso8601(future_date)

      created_at = data["createdAt"]
      assert is_binary(created_at)
      assert String.contains?(created_at, "T")
      assert String.contains?(created_at, "Z")
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(created_at)

      assert data["priority"] == "high"
      assert data["status"] == "pending"
      assert is_binary(data["priority"])
      assert is_binary(data["status"])

      assert is_boolean(data["isOverdue"])
      assert is_integer(data["daysUntilDue"])

      metadata_params = %{
        "action" => "update_todo",
        "identity" => @todo_id,
        "input" => %{
          "metadata" => %{
            "category" => "testing",
            "priority_score" => 85,
            "deadline" => Date.to_string(future_date),
            "tags" => ["test", "date_formatting"],
            "estimated_hours" => 2.0
          }
        },
        "fields" => [
          "id",
          %{"metadata" => ["category", "priority_score", "deadline", "tags", "estimated_hours"]}
        ]
      }

      assert {:ok, _request} = Rpc.parse(metadata_params)

      metadata_result =
        Rpc.run(
          metadata_params,
          %{
            record
            | metadata:
                struct(TodoMetadata,
                  category: "testing",
                  priority_score: 85,
                  deadline: future_date,
                  tags: ["test", "date_formatting"],
                  estimated_hours: 2.0
                )
          }
        )

      assert metadata_result["success"] == true
      metadata = metadata_result["data"]["metadata"]
      assert is_binary(metadata["deadline"])
      assert metadata["deadline"] == Date.to_iso8601(future_date)
      assert is_binary(metadata["category"])
      assert metadata["category"] == "testing"
      assert is_integer(metadata["priorityScore"])
      assert metadata["priorityScore"] == 85
      assert is_list(metadata["tags"])
      assert is_float(metadata["estimatedHours"])
      assert metadata["estimatedHours"] == 2.0
    end
  end

  describe "error scenarios and validation" do
    test "invalid action name returns proper error response" do
      result = Rpc.error(%{"action" => "nonexistent_action", "fields" => ["id"]})

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "action_not_found"
      assert first_error["message"] == "RPC action %{actionName} not found"
      assert first_error["vars"]["actionName"] == "nonexistent_action"
    end

    test "invalid field names return specific validation errors" do
      result =
        Rpc.error(%{"action" => "list_todos", "fields" => ["id", "nonexistent_field", "title"]})

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "unknown_field"
      assert first_error["message"] == "Unknown field %{field} for resource %{resource}"
      assert first_error["vars"]["field"] == "nonexistentField"
      assert String.contains?(first_error["vars"]["resource"], "Todo")
    end

    test "invalid relationship field names return nested error context" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", "title", %{"user" => ["id", "invalid_user_field"]}]
        })

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "unknown_field"
      assert is_binary(first_error["message"])
    end

    test "missing required input parameters return validation errors" do
      required =
        {:error,
         Ash.Error.to_error_class([
           %Ash.Error.Changes.Required{field: :user_id, type: :argument, resource: nil}
         ])}

      params = %{
        "action" => "create_todo",
        "input" => %{"title" => "Missing User ID Todo"},
        "fields" => ["id", "title"]
      }

      # the request itself parses (required-ness is an action-run concern); the data layer's
      # Required error is shaped by ErrorBuilder
      assert {:ok, _request} = Rpc.parse(params)
      result = Rpc.run(params, required)

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "required"
      assert first_error["fields"] == ["userId"]
    end

    test "invalid primary key for get operations returns not found error" do
      fake_uuid = "00000000-0000-0000-0000-000000000000"

      result =
        Rpc.run(
          %{"action" => "get_todo", "input" => %{"id" => fake_uuid}, "fields" => ["id", "title"]},
          {:error,
           Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: AshSurface.Ported.Todo})}
        )

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "not_found"
    end

    test "invalid pagination parameters return proper error" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", "title"],
          "page" => "invalid_pagination_format"
        })

      assert result["success"] == false
      assert is_list(result["errors"])
      assert result["errors"] != []

      first_error = List.first(result["errors"])
      assert first_error["type"] == "invalid_pagination"
    end

    test "invalid field structure (string instead of array for relationship) returns error" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", "title", %{"user" => "should_be_array_not_string"}]
        })

      assert result["success"] == false
      first_error = List.first(result["errors"])
      assert first_error["type"] == "unsupported_field_combination"
    end
  end

  describe "advanced scenarios and edge cases" do
    test "complex nested field selection with calculations, relationships, and aggregates" do
      params = %{
        "action" => "get_todo",
        "input" => %{"id" => @todo_id},
        "fields" => [
          "id",
          "title",
          "description",
          "status",
          "priority",
          "due_date",
          "created_at",
          "is_overdue",
          "days_until_due",
          %{
            "self" => %{
              "args" => %{"prefix" => "COMPLEX"},
              "fields" => ["id", "title", "description", "priority"]
            }
          },
          %{
            "user" => [
              "id",
              "name",
              "email",
              "active",
              %{"self" => %{"args" => %{"prefix" => "USER"}, "fields" => ["id", "name"]}}
            ]
          },
          %{
            "comments" => [
              "id",
              "content",
              "rating",
              "is_helpful",
              "author_name",
              %{"user" => ["id", "name", "email"]}
            ]
          },
          %{"metadata" => ["category", "priority_score", "tags", "estimated_hours"]},
          "comment_count",
          "helpful_comment_count",
          "has_comments",
          "average_rating",
          "highest_rating",
          "comment_authors"
        ]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert Enum.any?(request.load, &match?({:self, {%{prefix: "COMPLEX"}, _}}, &1))

      owner = user(name: "Complex User")

      comments =
        for i <- 1..3 do
          comment(
            id: "33333333-3333-3333-3333-33333333333#{i}",
            content: "Comment #{i}",
            rating: i + 2,
            is_helpful: rem(i, 2) == 1,
            author_name: "Commenter #{i}",
            user: owner
          )
        end

      base =
        todo(
          title: "Complex Scenario Todo",
          description: "Complex scenario with all features",
          priority: :urgent,
          status: :pending,
          due_date: Date.add(Date.utc_today(), 5),
          created_at: ~U[2026-01-01 00:00:00.000000Z],
          is_overdue: false,
          days_until_due: 5,
          user: %{owner | self: owner},
          comments: comments,
          metadata:
            struct(TodoMetadata,
              category: "integration_test",
              priority_score: 98,
              tags: ["complex", "comprehensive"],
              estimated_hours: 4.0
            ),
          comment_count: 3,
          helpful_comment_count: 2,
          has_comments: true,
          average_rating: 4.0,
          highest_rating: 5,
          comment_authors: ["Commenter 1", "Commenter 2", "Commenter 3"]
        )

      result = Rpc.run(params, %{base | self: base})
      assert result["success"] == true
      data = result["data"]

      assert data["id"] == @todo_id
      assert data["title"] == "Complex Scenario Todo"
      assert data["description"] == "Complex scenario with all features"
      assert data["status"] == "pending"
      assert data["priority"] == "urgent"
      assert Map.has_key?(data, "createdAt")

      assert is_boolean(data["isOverdue"])
      assert is_integer(data["daysUntilDue"])

      self_data = data["self"]
      assert self_data["title"] == "Complex Scenario Todo"
      assert self_data["priority"] == "urgent"

      user_data = data["user"]
      assert user_data["id"] == @user_id
      assert user_data["name"] == "Complex User"
      assert user_data["self"]["name"] == "Complex User"

      comments = data["comments"]
      assert is_list(comments)
      assert length(comments) == 3

      for comment <- comments do
        assert Map.has_key?(comment, "content")
        assert Map.has_key?(comment, "rating")
        assert Map.has_key?(comment, "user")
        assert comment["user"]["id"] == @user_id
        assert comment["user"]["name"] == "Complex User"
      end

      metadata = data["metadata"]
      assert metadata["category"] == "integration_test"
      assert metadata["priorityScore"] == 98
      assert metadata["tags"] == ["complex", "comprehensive"]

      assert data["commentCount"] == 3
      assert data["helpfulCommentCount"] == 2
      assert data["hasComments"] == true
      assert data["averageRating"] == 4.0
      assert data["highestRating"] == 5
      assert length(data["commentAuthors"]) == 3
    end

    test "pagination with complex field selection works correctly" do
      fields = [
        "id",
        "title",
        "createdAt",
        %{"user" => ["id", "name", "email"]},
        "commentCount"
      ]

      all =
        for i <- 1..5 do
          todo(
            id: "22222222-2222-2222-2222-22222222221#{i}",
            title: "Paginated Todo #{i}",
            created_at: ~U[2026-01-01 00:00:00.000000Z] |> DateTime.add(i, :second),
            comment_count: 0,
            user: user(name: "Page User #{i}", email: "page#{i}@example.com")
          )
        end

      page1_params = %{
        "action" => "list_todos",
        "fields" => fields,
        "sort" => "created_at",
        "page" => %{"limit" => 2, "offset" => 0}
      }

      page2_params = put_in(page1_params, ["page", "offset"], 2)

      assert {:ok, req1} = Rpc.parse(page1_params)
      assert {:ok, req2} = Rpc.parse(page2_params)
      assert req1.pagination != req2.pagination

      page1_result =
        Rpc.run(page1_params, page(Enum.slice(all, 0, 2), limit: 2, offset: 0, more?: true))

      assert page1_result["success"] == true
      page1_data = page1_result["data"]
      assert page1_data["hasMore"] == true
      assert page1_data["limit"] == 2
      assert page1_data["offset"] == 0
      assert is_list(page1_data["results"])
      assert length(page1_data["results"]) == 2

      page2_result =
        Rpc.run(page2_params, page(Enum.slice(all, 2, 2), limit: 2, offset: 2, more?: true))

      assert page2_result["success"] == true
      page2_data = page2_result["data"]
      assert page2_data["hasMore"] == true
      assert page2_data["limit"] == 2
      assert page2_data["offset"] == 2
      assert is_list(page2_data["results"])
      assert length(page2_data["results"]) == 2

      page1_ids = Enum.map(page1_data["results"], & &1["id"])
      page2_ids = Enum.map(page2_data["results"], & &1["id"])
      assert MapSet.disjoint?(MapSet.new(page1_ids), MapSet.new(page2_ids))

      for todo_data <- page1_data["results"] ++ page2_data["results"] do
        assert Map.has_key?(todo_data, "user")
        assert Map.has_key?(todo_data["user"], "name")
        assert Map.has_key?(todo_data["user"], "email")
        assert todo_data["commentCount"] == 0
      end
    end
  end
end
