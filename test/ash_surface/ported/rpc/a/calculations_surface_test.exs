defmodule AshSurface.Ported.Rpc.A.CalculationsSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `calculations_test.exs`. The reference creates rows and lets the
  data layer compute `isOverdue` / `daysUntilDue`; here the `Todo` structs carry the calculation
  values the data layer would have loaded (derived from real `Date` arithmetic in the test),
  and the request parse + result processor + formatter produce the client envelope. The
  calculation arithmetic itself is the fixture calculation module's concern, not the pipeline's.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcFixtures}

  @user_id RpcFixtures.user_id()

  defp days_until(nil), do: nil
  defp days_until(%Date{} = due), do: Date.diff(due, Date.utc_today())
  defp overdue?(nil), do: false
  defp overdue?(%Date{} = due), do: Date.compare(due, Date.utc_today()) == :lt

  # the record a data layer would return for a todo with `due_date` and both calcs loaded
  defp loaded(n, title, due_date) do
    RpcFixtures.todo(
      id: "44444444-4444-4444-4444-4444444444" <> String.pad_leading("#{n}", 2, "0"),
      title: title,
      due_date: due_date,
      user_id: @user_id,
      is_overdue: overdue?(due_date),
      days_until_due: days_until(due_date)
    )
  end

  defp date_in(days), do: Date.add(Date.utc_today(), days)

  defp get(todo, fields),
    do:
      Rpc.run(%{"action" => "get_todo", "input" => %{"id" => todo.id}, "fields" => fields}, todo)

  defp list(todos, fields),
    do: Rpc.run(%{"action" => "list_todos", "fields" => fields}, todos)

  describe "boolean calculations" do
    test "isOverdue calculation returns correct boolean values" do
      past_date = date_in(-7)
      future_date = date_in(7)

      past = get(loaded(1, "Past Due Todo", past_date), ["id", "title", "dueDate", "isOverdue"])
      assert past["success"] == true
      past_data = past["data"]
      assert past_data["title"] == "Past Due Todo"
      assert past_data["dueDate"] == Date.to_iso8601(past_date)
      assert is_boolean(past_data["isOverdue"])
      assert past_data["isOverdue"] == true

      future =
        get(loaded(2, "Future Due Todo", future_date), ["id", "title", "dueDate", "isOverdue"])

      assert future["success"] == true
      future_data = future["data"]
      assert future_data["title"] == "Future Due Todo"
      assert is_boolean(future_data["isOverdue"])
      assert future_data["isOverdue"] == false
    end

    test "isOverdue calculation handles todos without due dates" do
      result = get(loaded(3, "No Due Date Todo", nil), ["id", "title", "dueDate", "isOverdue"])

      assert result["success"] == true
      data = result["data"]
      assert data["title"] == "No Due Date Todo"
      assert Map.has_key?(data, "dueDate")
      assert is_nil(data["dueDate"])
      assert is_boolean(data["isOverdue"])
      assert data["isOverdue"] == false
    end
  end

  describe "integer calculations" do
    test "daysUntilDue calculation returns correct integer values" do
      target_days = 5

      result =
        get(loaded(4, "Days Calculation Todo", date_in(target_days)), [
          "id",
          "title",
          "dueDate",
          "daysUntilDue"
        ])

      assert result["success"] == true
      data = result["data"]
      assert data["title"] == "Days Calculation Todo"
      assert is_integer(data["daysUntilDue"])
      assert data["daysUntilDue"] >= target_days - 1
      assert data["daysUntilDue"] <= target_days + 1
    end

    test "daysUntilDue calculation handles past dates correctly" do
      past_days = -3

      result =
        get(loaded(5, "Past Days Todo", date_in(past_days)), [
          "id",
          "title",
          "dueDate",
          "daysUntilDue"
        ])

      assert result["success"] == true
      data = result["data"]
      assert data["title"] == "Past Days Todo"
      assert is_integer(data["daysUntilDue"])
      assert data["daysUntilDue"] >= past_days - 1
      assert data["daysUntilDue"] <= past_days + 1
    end

    test "daysUntilDue calculation handles nil due date" do
      result =
        get(loaded(6, "No Due Date Days Todo", nil), ["id", "title", "dueDate", "daysUntilDue"])

      assert result["success"] == true
      data = result["data"]
      assert data["title"] == "No Due Date Days Todo"
      assert is_nil(data["dueDate"])
      assert Map.has_key?(data, "daysUntilDue")
      assert is_nil(data["daysUntilDue"])
    end
  end

  describe "calculations in list operations" do
    test "calculations work correctly in list queries" do
      todos = [
        loaded(7, "Past Todo", date_in(-2)),
        loaded(8, "Future Todo", date_in(3)),
        loaded(9, "No Date Todo", nil)
      ]

      result = list(todos, ["id", "title", "dueDate", "isOverdue", "daysUntilDue"])

      assert result["success"] == true
      assert is_list(result["data"])
      assert length(result["data"]) == 3

      for todo_data <- result["data"] do
        assert Map.has_key?(todo_data, "isOverdue")
        assert is_boolean(todo_data["isOverdue"])
        assert Map.has_key?(todo_data, "daysUntilDue")
        assert is_integer(todo_data["daysUntilDue"]) or is_nil(todo_data["daysUntilDue"])
      end

      past_todo = Enum.find(result["data"], &(&1["title"] == "Past Todo"))
      future_todo = Enum.find(result["data"], &(&1["title"] == "Future Todo"))
      no_date_todo = Enum.find(result["data"], &(&1["title"] == "No Date Todo"))

      assert past_todo["isOverdue"] == true
      assert future_todo["isOverdue"] == false
      assert no_date_todo["isOverdue"] == false

      assert past_todo["daysUntilDue"] < 0
      assert future_todo["daysUntilDue"] > 0
    end
  end

  describe "calculation field selection" do
    test "calculations can be selected independently" do
      todo = loaded(10, "Selection Test Todo", date_in(2))

      result1 = get(todo, ["id", "title", "isOverdue"])
      assert result1["success"] == true
      assert Map.has_key?(result1["data"], "isOverdue")
      refute Map.has_key?(result1["data"], "daysUntilDue")

      result2 = get(todo, ["id", "title", "daysUntilDue"])
      assert result2["success"] == true
      assert Map.has_key?(result2["data"], "daysUntilDue")
      refute Map.has_key?(result2["data"], "isOverdue")

      result3 = get(todo, ["id", "title", "isOverdue", "daysUntilDue"])
      assert result3["success"] == true
      assert Map.has_key?(result3["data"], "isOverdue")
      assert Map.has_key?(result3["data"], "daysUntilDue")
    end

    test "calculations work with minimal field selection" do
      result =
        get(loaded(11, "Minimal Test Todo", date_in(2)), ["id", "isOverdue", "daysUntilDue"])

      assert result["success"] == true
      data = result["data"]
      assert Map.has_key?(data, "id")
      assert Map.has_key?(data, "isOverdue")
      assert Map.has_key?(data, "daysUntilDue")

      refute Map.has_key?(data, "title")
      refute Map.has_key?(data, "description")
      refute Map.has_key?(data, "status")
    end

    test "an unknown calculation name is refused at parse" do
      result =
        Rpc.error(%{
          "action" => "get_todo",
          "input" => %{"id" => RpcFixtures.todo_id()},
          "fields" => ["id", "isOverdueAnymore"]
        })

      assert result["success"] == false
      assert [%{"type" => "unknown_field"} | _] = result["errors"]
    end
  end

  describe "calculation type consistency" do
    test "calculation return types are consistent across different todos" do
      todos = [
        loaded(12, "Todo 1", date_in(5)),
        loaded(13, "Todo 2", date_in(-3)),
        loaded(14, "Todo 3", nil)
      ]

      for todo <- todos do
        result = get(todo, ["id", "isOverdue", "daysUntilDue"])
        assert result["success"] == true
        data = result["data"]

        assert is_boolean(data["isOverdue"])
        assert is_integer(data["daysUntilDue"]) or is_nil(data["daysUntilDue"])
      end
    end
  end

  describe "calculation performance" do
    test "calculations perform correctly with multiple todos" do
      todo_count = 10

      todos =
        for i <- 1..todo_count do
          loaded(20 + i, "Perf Todo #{i}", date_in(i - 5))
        end

      start_time = System.monotonic_time(:millisecond)
      result = list(todos, ["id", "title", "isOverdue", "daysUntilDue"])
      duration = System.monotonic_time(:millisecond) - start_time

      assert result["success"] == true
      assert length(result["data"]) == todo_count
      assert duration < 5000

      for todo_data <- result["data"] do
        assert is_boolean(todo_data["isOverdue"])
        assert is_integer(todo_data["daysUntilDue"]) or is_nil(todo_data["daysUntilDue"])
      end

      # per-row values are not smeared across rows
      assert Enum.map(result["data"], & &1["daysUntilDue"]) == Enum.map(1..todo_count, &(&1 - 5))
    end
  end
end
