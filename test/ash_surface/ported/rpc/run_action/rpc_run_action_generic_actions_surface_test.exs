defmodule AshSurface.Ported.RpcRunActionGenericActionsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_generic_actions_test.exs`. Each generic action's
  result is the literal value the fixture action's `run` function returns, fed to the result
  processor; field refusals come from `Rpc.Pipeline.parse_request/2`. The four codegen-text
  tests (generated TypeScript) stay in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures, TaskStats}
  import RpcFixtures, only: [todo: 1, user: 1]

  @stats %{total: 10, completed: 6, pending: 4, overdue: 2}
  @todo_ids [
    "aaaaaaaa-1111-1111-1111-000000000001",
    "aaaaaaaa-1111-1111-1111-000000000002",
    "aaaaaaaa-1111-1111-1111-000000000003"
  ]

  defp act(action, fields, result, input \\ nil) do
    params = %{"action" => action, "fields" => fields}
    params = if input, do: Map.put(params, "input", input), else: params
    Rpc.run(params, result)
  end

  defp refuse(action, fields, input \\ nil) do
    params = %{"action" => action, "fields" => fields}
    params = if input, do: Map.put(params, "input", input), else: params
    Rpc.error(params)
  end

  defp err_text(result), do: inspect(result["errors"])

  describe "map return type actions (get_statistics)" do
    test "processes valid map fields correctly" do
      result = act("get_statistics_todo", ["total", "completed", "pending"], @stats)
      assert result["success"] == true
      data = result["data"]
      assert is_map(data)
      assert Map.has_key?(data, "total")
      assert Map.has_key?(data, "completed")
      assert Map.has_key?(data, "pending")
      refute Map.has_key?(data, "overdue")
      assert data["total"] == 10
      assert data["completed"] == 6
      assert data["pending"] == 4
    end

    test "processes all valid map fields" do
      result = act("get_statistics_todo", ["total", "completed", "pending", "overdue"], @stats)
      assert result["success"] == true
      data = result["data"]
      assert data["total"] == 10
      assert data["completed"] == 6
      assert data["pending"] == 4
      assert data["overdue"] == 2
    end

    test "rejects invalid fields for map return types" do
      result = refuse("get_statistics_todo", ["invalidField"])
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "invalidField" or msg =~ "unknown" or msg =~ "field"
    end

    test "rejects nested field selection for map types" do
      result = refuse("get_statistics_todo", [%{"nested" => ["field"]}])
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "nested" or msg =~ "unknown" or msg =~ "field"
    end

    test "requires fields for field-selectable map types" do
      result = refuse("get_statistics_todo", [])
      assert result["success"] == false
      msg = err_text(result)
      assert msg =~ "empty_fields_array" or msg =~ "fields"

      result = act("get_statistics_todo", ["total", "completed"], @stats)
      assert result["success"] == true
      data = result["data"]
      assert Map.has_key?(data, "total")
      assert Map.has_key?(data, "completed")
      assert map_size(data) == 2
    end
  end

  describe "primitive array return type actions (bulk_complete)" do
    test "processes empty field list for primitive arrays" do
      result = act("bulk_complete_todo", [], @todo_ids, %{"todoIds" => @todo_ids})
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)
      assert length(data) == 3

      Enum.each(data, fn uuid ->
        assert is_binary(uuid)
        assert uuid in @todo_ids
      end)
    end

    test "rejects field selection for primitive array types" do
      result = refuse("bulk_complete_todo", ["id"], %{"todoIds" => @todo_ids})
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "primitive" or msg =~ "field" or msg =~ "selection"
    end

    test "handles bulk_complete with valid input" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "bulk_complete_todo",
                 "input" => %{"todoIds" => @todo_ids},
                 "fields" => []
               })

      assert request.input == %{todo_ids: @todo_ids}

      result = act("bulk_complete_todo", [], @todo_ids, %{"todoIds" => @todo_ids})
      assert result["success"] == true
      assert Enum.sort(result["data"]) == Enum.sort(@todo_ids)
    end
  end

  describe "struct array return type actions (search)" do
    defp found_todos(extra \\ []),
      do: [
        todo([title: "Search Test Alpha"] ++ extra),
        todo([id: "bbbbbbbb-0000-0000-0000-000000000002", title: "Search Test Beta"] ++ extra)
      ]

    @search_input %{"query" => "Search Test", "includeCompleted" => true}

    test "processes fields for array of structs" do
      result = act("search_todos", ["id", "title", "completed"], found_todos(), @search_input)
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)

      Enum.each(data, fn t ->
        assert Map.has_key?(t, "id")
        assert Map.has_key?(t, "title")
        assert Map.has_key?(t, "completed")
        refute Map.has_key?(t, "description")
        refute Map.has_key?(t, "priority")
      end)
    end

    test "parses search input (query, includeCompleted) to action arguments" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "search_todos",
                 "input" => @search_input,
                 "fields" => ["id"]
               })

      assert request.input == %{query: "Search Test", include_completed: true}
    end

    test "processes relationships in struct arrays" do
      result =
        act(
          "search_todos",
          ["id", "title", %{"user" => ["id", "name"]}],
          found_todos(user: user(name: "Search User")),
          %{"query" => "Test", "includeCompleted" => true}
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "user")
        assert Map.has_key?(t["user"], "id")
        assert Map.has_key?(t["user"], "name")
        refute Map.has_key?(t["user"], "email")
      end)
    end

    test "handles search with empty results" do
      result =
        act("search_todos", ["id", "title"], [], %{
          "query" => "NonExistentSearchTerm",
          "includeCompleted" => true
        })

      assert result["success"] == true
      assert result["data"] == []
    end

    test "processes calculations in struct arrays" do
      result =
        act(
          "search_todos",
          ["id", "title", "isOverdue", "daysUntilDue"],
          found_todos(is_overdue: false, days_until_due: 4),
          %{"query" => "Test", "includeCompleted" => true}
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "isOverdue")
        assert Map.has_key?(t, "daysUntilDue")
        assert is_boolean(t["isOverdue"])
        assert is_integer(t["daysUntilDue"])
      end)
    end

    test "processes aggregates in struct arrays" do
      result =
        Rpc.run(
          %{"action" => "list_todos", "fields" => ["id", "title", "commentCount"]},
          found_todos(comment_count: 0)
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Map.has_key?(t, "commentCount")
        assert is_integer(t["commentCount"])
      end)
    end
  end

  describe "untyped return type actions (ping)" do
    test "runs without fields" do
      result = Rpc.run(%{"action" => "ping_todo"}, :ok)
      assert result["success"] == true
    end

    test "rejects string field names" do
      result = refuse("ping_todo", ["id"], %{})
      assert result["success"] == false
      assert [%{"type" => "invalid_field_selection"}] = result["errors"]
    end

    test "rejects nested field selection" do
      result = refuse("ping_todo", [%{"user" => ["id"]}])
      assert result["success"] == false
      assert [%{"type" => "invalid_field_selection"}] = result["errors"]
    end
  end

  describe "action validation" do
    test "returns error for non-existent action" do
      result = refuse("non_existent_action", [])
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "not found" or msg =~ "action"
    end

    test "validates action exists before processing fields" do
      result = refuse("missing_action", ["id", "title"])
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "not found" or msg =~ "action"
    end
  end

  describe "get_custom_data action (unconstrained map)" do
    @custom_data %{
      user_id: "123e4567-e89b-12d3-a456-426614174000",
      status: "active",
      count: 42,
      timestamp: 1_640_995_200,
      metadata: %{
        version: "1.0",
        tags: ["important", "urgent"],
        settings: %{notifications: true, theme: "dark"}
      }
    }

    defp assert_custom_data(data) do
      assert is_map(data)
      assert data[:user_id] == "123e4567-e89b-12d3-a456-426614174000"
      assert data[:status] == "active"
      assert data[:count] == 42
      assert data[:timestamp] == 1_640_995_200
      metadata = data[:metadata]
      assert metadata[:version] == "1.0"
      assert metadata[:tags] == ["important", "urgent"]
      assert metadata[:settings][:notifications] == true
      assert metadata[:settings][:theme] == "dark"
    end

    test "returns hardcoded map data without field constraints" do
      result = act("get_custom_data_todo", [], @custom_data)
      assert result["success"] == true
      assert_custom_data(result["data"])
    end

    test "returns full map data when no fields specified" do
      result = Rpc.run(%{"action" => "get_custom_data_todo"}, @custom_data)
      assert result["success"] == true
      assert_custom_data(result["data"])
    end

    test "works with empty fields array (legacy compatibility)" do
      result = act("get_custom_data_todo", [], @custom_data)
      assert result["success"] == true
      assert_custom_data(result["data"])
    end

    test "preserves underscore-prefixed keys verbatim" do
      doc = %{
        "_id" => "doc-123",
        "_type" => "post",
        "_rev" => "rev-1",
        "_createdAt" => "2026-04-14T00:00:00Z",
        "title" => "Hello"
      }

      result = Rpc.run(%{"action" => "get_underscored_document_todo"}, doc)
      assert result["success"] == true
      data = result["data"]
      assert data["_id"] == "doc-123"
      assert data["_type"] == "post"
      assert data["_rev"] == "rev-1"
      assert data["_createdAt"] == "2026-04-14T00:00:00Z"
      assert data["title"] == "Hello"
    end
  end

  describe "get_custom_data_list action (array of unconstrained maps)" do
    test "returns array of maps" do
      list = [
        %{user_id: "123e4567-e89b-12d3-a456-426614174000", status: "active"},
        %{user_id: "223e4567-e89b-12d3-a456-426614174001", status: "pending"}
      ]

      result = Rpc.run(%{"action" => "get_custom_data_list_todo"}, list)
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)
      assert length(data) == 2
      [first, second] = data
      assert first[:user_id] == "123e4567-e89b-12d3-a456-426614174000"
      assert first[:status] == "active"
      assert second[:user_id] == "223e4567-e89b-12d3-a456-426614174001"
      assert second[:status] == "pending"
    end
  end

  describe "complex return type validation" do
    test "handles nested array constraints correctly" do
      result =
        act("search_todos", ["id", "title"], found_todos(), %{
          "query" => "Test",
          "includeCompleted" => true
        })

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        assert Enum.sort(Map.keys(t)) == ["id", "title"]
      end)
    end

    test "handles complex nested field selection in arrays" do
      nested = fn n -> todo(title: n, id: "cccccccc-0000-0000-0000-000000000009") end

      result =
        act(
          "search_todos",
          ["id", "title", %{"user" => ["id", "name", %{"todos" => ["id", "title"]}]}],
          found_todos(user: user(name: "Complex User", todos: [nested.("n1"), nested.("n2")])),
          %{"query" => "Test", "includeCompleted" => true}
        )

      assert result["success"] == true

      Enum.each(result["data"], fn t ->
        user_data = t["user"]
        assert Map.has_key?(user_data, "id")
        assert Map.has_key?(user_data, "name")
        assert is_list(user_data["todos"])

        Enum.each(user_data["todos"], fn nt ->
          assert Map.has_key?(nt, "id")
          assert Map.has_key?(nt, "title")
          refute Map.has_key?(nt, "completed")
          refute Map.has_key?(nt, "description")
        end)
      end)
    end
  end

  describe "typed struct return type actions (get_task_stats)" do
    @task_id "dddddddd-0000-0000-0000-000000000001"
    defp stats(attrs \\ []),
      do:
        struct(
          TaskStats,
          Keyword.merge(
            [total_count: 10, completed?: true, is_urgent?: false, average_duration: 45.5],
            attrs
          )
        )

    test "processes valid typed struct fields correctly" do
      result =
        act("get_task_stats", ["totalCount", "completed", "isUrgent"], stats(), %{
          "taskId" => @task_id
        })

      assert result["success"] == true
      data = result["data"]
      assert is_map(data)
      assert data["totalCount"] == 10
      assert data["completed"] == true
      assert data["isUrgent"] == false
      refute Map.has_key?(data, "averageDuration")
    end

    test "processes all valid typed struct fields" do
      result =
        act(
          "get_task_stats",
          ["totalCount", "completed", "isUrgent", "averageDuration"],
          stats(),
          %{"taskId" => @task_id}
        )

      assert result["success"] == true
      data = result["data"]
      assert data["totalCount"] == 10
      assert data["completed"] == true
      assert data["isUrgent"] == false
      assert data["averageDuration"] == 45.5
    end

    test "rejects invalid fields for typed struct return types" do
      result = refuse("get_task_stats", ["invalidField"], %{"taskId" => @task_id})
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "invalidField" or msg =~ "unknown" or msg =~ "field"
    end

    test "requires fields for typed struct return types" do
      result = refuse("get_task_stats", [], %{"taskId" => @task_id})
      assert result["success"] == false
      msg = err_text(result)
      assert msg =~ "requires_field_selection" or msg =~ "field" or msg =~ "empty"

      result =
        act("get_task_stats", ["totalCount", "completed"], stats(), %{"taskId" => @task_id})

      assert result["success"] == true
      data = result["data"]
      assert Map.has_key?(data, "totalCount")
      assert Map.has_key?(data, "completed")
      assert map_size(data) == 2
    end
  end

  describe "array of typed struct return type actions (list_task_stats)" do
    defp stats_list,
      do: [
        stats(),
        stats(total_count: 5, completed?: false, is_urgent?: true, average_duration: 30.0)
      ]

    test "processes valid typed struct fields correctly for arrays" do
      result = act("list_task_stats", ["totalCount", "completed", "isUrgent"], stats_list())
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)
      assert length(data) == 2

      Enum.each(data, fn item ->
        assert is_integer(item["totalCount"])
        assert is_boolean(item["completed"])
        assert is_boolean(item["isUrgent"])
        refute Map.has_key?(item, "averageDuration")
      end)

      [first, second] = data
      assert {first["totalCount"], first["completed"], first["isUrgent"]} == {10, true, false}
      assert {second["totalCount"], second["completed"], second["isUrgent"]} == {5, false, true}
    end

    test "processes all valid typed struct fields for arrays" do
      result =
        act(
          "list_task_stats",
          ["totalCount", "completed", "isUrgent", "averageDuration"],
          stats_list()
        )

      assert result["success"] == true
      [first, second] = result["data"]
      assert first["averageDuration"] == 45.5
      assert second["averageDuration"] == 30.0
      assert is_float(first["averageDuration"])
    end

    test "rejects invalid fields for array of typed struct return types" do
      result = refuse("list_task_stats", ["invalidField"])
      assert result["success"] == false
      assert result["errors"]
      msg = err_text(result)
      assert msg =~ "invalidField" or msg =~ "unknown" or msg =~ "field"
    end

    test "requires fields for array of typed struct return types" do
      result = refuse("list_task_stats", [])
      assert result["success"] == false
      msg = err_text(result)
      assert msg =~ "requires_field_selection" or msg =~ "field" or msg =~ "empty"

      result = act("list_task_stats", ["totalCount", "completed"], stats_list())
      assert result["success"] == true

      Enum.each(result["data"], fn item ->
        assert Map.has_key?(item, "totalCount")
        assert Map.has_key?(item, "completed")
        assert map_size(item) == 2
      end)
    end
  end

  describe "NewType wrapping map return type (get_suggestion)" do
    @suggestion %{name: "Test Suggestion", category: nil, score: 85}

    test "processes valid fields correctly for NewType map" do
      result = act("get_suggestion", ["name", "score"], @suggestion, %{"query" => "test"})
      assert result["success"] == true
      data = result["data"]
      assert is_map(data)
      assert data["name"] == "Test Suggestion"
      assert data["score"] == 85
      refute Map.has_key?(data, "category")
    end

    test "processes all fields for NewType map" do
      result =
        act("get_suggestion", ["name", "category", "score"], @suggestion, %{"query" => "test"})

      assert result["success"] == true
      data = result["data"]
      assert Map.has_key?(data, "name")
      assert Map.has_key?(data, "category")
      assert Map.has_key?(data, "score")
      assert map_size(data) == 3
    end
  end

  describe "array of NewType wrapping map return type (list_suggestions)" do
    test "processes valid fields correctly for array of NewType maps" do
      list = [
        %{name: "Suggestion A", category: "work", score: 90},
        %{name: "Suggestion B", category: nil, score: 75}
      ]

      result = act("list_suggestions", ["name", "score"], list, %{"query" => "test"})
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)
      assert length(data) == 2

      Enum.each(data, fn item ->
        assert Map.has_key?(item, "name")
        assert Map.has_key?(item, "score")
        refute Map.has_key?(item, "category")
      end)
    end
  end

  describe "date array return type action (get_important_dates)" do
    test "returns dates as ISO strings" do
      dates = [~D[2025-01-15], ~D[2025-02-20], ~D[2025-03-25]]
      result = act("get_important_dates", [], dates)
      assert result["success"] == true
      data = result["data"]
      assert is_list(data)
      assert length(data) == 3
      assert data == ["2025-01-15", "2025-02-20", "2025-03-25"]
    end
  end

  describe "single date return type action (get_publication_date)" do
    test "returns date as ISO string" do
      result = act("get_publication_date", [], ~D[2025-01-15])
      assert result["success"] == true
      data = result["data"]
      assert is_binary(data)
      assert data == "2025-01-15"
    end
  end
end
