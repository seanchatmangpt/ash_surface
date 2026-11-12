defmodule AshSurface.Ported.Rpc.B.MapFieldNameRpcSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of ash_typescript `rpc/map_field_name_rpc_test` run phase.
  The generic actions' `run` result is the caller-built term fed through
  `Rpc.run/2` (parse -> result processor -> output formatter); ash_surface never actuates.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, TodoMetadata}

  @metrics %{total: 100, last_week: 10, last_month: 40, last_year: 90}

  @stats %{
    user_stats: %{active_users: 1000, new_signups: 50, churn_rate: 2.5},
    content_stats: %{total_posts: 500, posts_this_week: 25, avg_engagement_rate: 7.5}
  }

  @users %{
    total_count: 1,
    results: [
      %{
        id: "user-1",
        email: "test@example.com",
        first_name: "Test",
        last_name: "User",
        phone: nil,
        is_admin: false,
        confirmed_at: nil,
        inserted_at: ~U[2025-01-01 00:00:00Z]
      }
    ]
  }

  defp run(action, fields, result),
    do: Rpc.run(%{"action" => action, "fields" => fields}, result)

  describe "RPC should accept camelCase field names for map return types" do
    test "get_metrics action accepts camelCase field names" do
      result = run("get_metrics", ["total", "lastWeek", "lastMonth", "lastYear"], @metrics)
      assert result["success"] == true, inspect(result)
      data = result["data"]
      for k <- ["total", "lastWeek", "lastMonth", "lastYear"], do: assert(Map.has_key?(data, k))
      assert data["lastWeek"] == 10
    end

    test "get_metrics action also accepts snake_case field names for backwards compatibility" do
      result = run("get_metrics", ["total", "last_week", "last_month", "last_year"], @metrics)
      assert result["success"] == true, inspect(result)
      data = result["data"]
      for k <- ["total", "lastWeek", "lastMonth", "lastYear"], do: assert(Map.has_key?(data, k))
    end

    test "get_nested_stats action accepts camelCase for top-level and nested field selection" do
      result =
        run(
          "get_nested_stats",
          [
            %{"userStats" => ["activeUsers", "newSignups", "churnRate"]},
            %{"contentStats" => ["totalPosts", "postsThisWeek", "avgEngagementRate"]}
          ],
          @stats
        )

      assert result["success"] == true, inspect(result)

      assert result["data"] == %{
               "userStats" => %{"activeUsers" => 1000, "newSignups" => 50, "churnRate" => 2.5},
               "contentStats" => %{
                 "totalPosts" => 500,
                 "postsThisWeek" => 25,
                 "avgEngagementRate" => 7.5
               }
             }
    end
  end

  describe "list_users_map action with nested {:array, :map}" do
    test "list_users_map action accepts camelCase for top-level and nested array fields" do
      result =
        run(
          "list_users_map",
          ["totalCount", %{"results" => ["id", "email", "firstName", "lastName", "isAdmin"]}],
          @users
        )

      assert result["success"] == true, inspect(result)
      data = result["data"]
      assert data["totalCount"] == 1
      [first | _] = data["results"]

      assert first == %{
               "id" => "user-1",
               "email" => "test@example.com",
               "firstName" => "Test",
               "lastName" => "User",
               "isAdmin" => false
             }
    end

    test "applies the nested selection to each item of the array" do
      result = run("list_users_map", [%{"results" => ["id", "email"]}], @users)
      assert result["success"] == true, inspect(result)

      assert result["data"] == %{
               "results" => [%{"id" => "user-1", "email" => "test@example.com"}]
             }
    end

    test "formats nested primitive values when selecting array items" do
      result = run("list_users_map", ["totalCount", %{"results" => ["insertedAt"]}], @users)
      assert result["success"] == true, inspect(result)

      assert result["data"] == %{
               "totalCount" => 1,
               "results" => [%{"insertedAt" => "2025-01-01T00:00:00Z"}]
             }
    end
  end

  describe "get_metadata_report array of embedded resources in a typed map" do
    test "applies the nested selection to each embedded resource" do
      report = %{
        total: 2,
        rows: [
          struct(TodoMetadata, %{category: "work", priority_score: 80, display_category: "x"}),
          struct(TodoMetadata, %{category: "personal", priority_score: 20, display_category: "y"})
        ]
      }

      result =
        run("get_metadata_report", ["total", %{"rows" => ["category", "priorityScore"]}], report)

      assert result["success"] == true, inspect(result)

      assert result["data"] == %{
               "total" => 2,
               "rows" => [
                 %{"category" => "work", "priorityScore" => 80},
                 %{"category" => "personal", "priorityScore" => 20}
               ]
             }
    end
  end

  describe "get_nested_stats nested typed map selection" do
    test "only returns the selected nested fields" do
      result = run("get_nested_stats", [%{"userStats" => ["activeUsers"]}], @stats)
      assert result["success"] == true, inspect(result)
      assert result["data"] == %{"userStats" => %{"activeUsers" => 1000}}
    end
  end

  describe "output field formatting consistency" do
    test "output fields are always camelCase regardless of input format" do
      result = run("get_metrics", ["total", "last_week", "last_month", "last_year"], @metrics)
      assert result["success"] == true
      data = result["data"]
      for k <- ["last_week", "last_month", "last_year"], do: refute(Map.has_key?(data, k))
    end
  end
end
