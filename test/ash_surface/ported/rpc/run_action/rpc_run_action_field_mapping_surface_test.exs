defmodule AshSurface.Ported.RpcRunActionFieldMappingSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `rpc_run_action_field_mapping_test.exs`: input mapping is asserted
  on the parsed request, output mapping on the result processor over hand-built `Task` structs.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Task}

  @task_id "44444444-4444-4444-4444-444444444444"

  defp task(attrs \\ []),
    do:
      struct(
        Task,
        Keyword.merge(
          [id: @task_id, title: "Test Task", completed: false, archived?: false],
          attrs
        )
      )

  describe "mapped field names - output" do
    test "read action returns mapped field names" do
      result =
        Rpc.run(
          %{
            "action" => "list_tasks",
            "resource" => "Task",
            "fields" => ["id", "title", "completed", "isArchived"]
          },
          [task()]
        )

      assert %{"success" => true, "data" => [found_task]} = result
      assert found_task["title"] == "Test Task"
      assert found_task["completed"] == false
      assert found_task["isArchived"] == false
      refute Map.has_key?(found_task, "archived?")
    end

    test "read action with archived? field set to true" do
      result =
        Rpc.run(
          %{
            "action" => "list_tasks",
            "resource" => "Task",
            "fields" => ["id", "title", "isArchived"]
          },
          [task(title: "Archived Task", archived?: true)]
        )

      assert %{"success" => true, "data" => [found_task]} = result
      assert found_task["title"] == "Archived Task"
      assert found_task["isArchived"] == true
      refute Map.has_key?(found_task, "archived?")
    end
  end

  describe "mapped argument names - input" do
    test "update action accepts mapped argument names" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "mark_completed_task",
                 "resource" => "Task",
                 "identity" => @task_id,
                 "input" => %{"isCompleted" => true},
                 "fields" => ["id", "title", "completed", "isArchived"]
               })

      assert request.input == %{is_task_completed_now?: true}
      assert request.identity == @task_id

      result =
        Rpc.run(
          %{
            "action" => "mark_completed_task",
            "identity" => @task_id,
            "input" => %{"isCompleted" => true},
            "fields" => ["id", "title", "completed", "isArchived"]
          },
          task(title: "Incomplete Task", completed: true)
        )

      assert %{"success" => true, "data" => updated_task} = result
      assert updated_task["title"] == "Incomplete Task"
      assert updated_task["completed"] == true
      assert updated_task["isArchived"] == false
    end

    test "update action with isCompleted set to false" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "mark_completed_task",
                 "identity" => @task_id,
                 "input" => %{"isCompleted" => false},
                 "fields" => ["id", "title", "completed"]
               })

      assert request.input == %{is_task_completed_now?: false}

      result =
        Rpc.run(
          %{
            "action" => "mark_completed_task",
            "identity" => @task_id,
            "input" => %{"isCompleted" => false},
            "fields" => ["id", "title", "completed"]
          },
          task(completed: false)
        )

      assert %{"success" => true, "data" => updated_task} = result
      assert updated_task["completed"] == false
    end

    test "validation mode parses mapped argument names" do
      assert {:ok, request} =
               Rpc.parse(
                 %{
                   "action" => "mark_completed_task",
                   "identity" => @task_id,
                   "input" => %{"isCompleted" => true}
                 },
                 validation_mode?: true
               )

      assert request.input == %{is_task_completed_now?: true}
    end
  end

  describe "combined field and argument mapping" do
    test "update action with both mapped input and output" do
      params = %{
        "action" => "mark_completed_task",
        "identity" => @task_id,
        "input" => %{"isCompleted" => true},
        "fields" => ["id", "title", "completed", "isArchived"]
      }

      assert {:ok, %{input: %{is_task_completed_now?: true}}} = Rpc.parse(params)

      assert %{"success" => true, "data" => updated_task} =
               Rpc.run(params, task(title: "Combined Test", completed: true, archived?: true))

      assert updated_task["title"] == "Combined Test"
      assert updated_task["completed"] == true
      assert updated_task["isArchived"] == true
      refute Map.has_key?(updated_task, "archived?")
    end
  end

  describe "create action with mapped field output" do
    test "create action returns mapped field names" do
      assert %{"success" => true, "data" => created} =
               Rpc.run(
                 %{
                   "action" => "create_task",
                   "resource" => "Task",
                   "input" => %{"title" => "New Task"},
                   "fields" => ["id", "title", "completed", "isArchived"]
                 },
                 task(title: "New Task")
               )

      assert created["title"] == "New Task"
      assert created["completed"] == false
      assert created["isArchived"] == false
      refute Map.has_key?(created, "archived?")
    end
  end

  describe "field selection with mapped names" do
    test "selecting only mapped field works" do
      assert %{"success" => true, "data" => [found_task]} =
               Rpc.run(
                 %{"action" => "list_tasks", "fields" => ["isArchived"]},
                 [task(title: "Selection Test", archived?: true)]
               )

      assert found_task["isArchived"] == true
      assert map_size(found_task) == 1
    end

    test "selecting multiple fields including mapped field" do
      assert %{"success" => true, "data" => [found_task]} =
               Rpc.run(
                 %{"action" => "list_tasks", "fields" => ["id", "title", "isArchived"]},
                 [task(title: "Multiple Fields Test")]
               )

      assert found_task["title"] == "Multiple Fields Test"
      assert found_task["isArchived"] == false
      assert Map.has_key?(found_task, "id")
      refute Map.has_key?(found_task, "completed")
    end
  end

  describe "inline change with mapped argument" do
    test "mapped client argument name resolves to the original argument atom" do
      params = %{
        "action" => "mark_completed_task",
        "identity" => @task_id,
        "input" => %{"isCompleted" => true},
        "fields" => ["id", "completed"]
      }

      assert {:ok, %{input: input}} = Rpc.parse(params)
      assert Map.keys(input) == [:is_task_completed_now?]

      assert %{"success" => true, "data" => updated_task} =
               Rpc.run(params, task(completed: true))

      assert updated_task["completed"] == true
    end
  end

  describe "error cases with mapped names" do
    test "unmapped fields still work normally" do
      assert %{"success" => true, "data" => created} =
               Rpc.run(
                 %{
                   "action" => "create_task",
                   "input" => %{"title" => "Normal Fields Test"},
                   "fields" => ["id", "title", "completed"]
                 },
                 task(title: "Normal Fields Test")
               )

      assert created["title"] == "Normal Fields Test"
      assert created["completed"] == false
    end
  end
end
