defmodule AshSurface.Ported.Rpc.D.RpcIntegrationSurfaceTest do
  @moduledoc """
  Surface port of `rpc_integration_test.exs`. Requests go through the non-actuating
  `Rpc.Pipeline` (parse + result process + format); no action executes. The validation-only
  endpoint is `Rpc.parse(..., validation_mode?: true)` (the reference's `validate_action`
  parse stage); input validation proper lives in `rpc_validate_action_surface_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, Todo}
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  describe "request parsing validation" do
    test "valid simple field requests parse successfully" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title", "description", "status"]
               })

      assert request.resource == Todo
      assert :id in request.select
      assert :title in request.select
      assert :description in request.select
      assert :status in request.select
      assert is_list(request.extraction_template)
    end

    test "valid complex field combinations parse successfully" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => [
                   "id",
                   "title",
                   "isOverdue",
                   %{"user" => ["id", "name"]},
                   %{"metadata" => ["category"]},
                   %{"self" => %{"args" => %{"prefix" => "test"}, "fields" => ["id", "title"]}}
                 ]
               })

      assert :id in request.select
      assert :title in request.select
      assert :is_overdue in request.load
      assert Enum.any?(request.load, &match?({:user, _}, &1))
      assert Enum.any?(request.load, &match?({:self, {%{prefix: "test"}, [:id, :title]}}, &1))
    end

    test "end-to-end strict validation - fails fast on unknown fields" do
      error_response =
        Rpc.error(%{"action" => "list_todos", "fields" => ["id", "title", "unknown_field"]})

      assert error_response["success"] == false
      error = List.first(error_response["errors"])
      assert error["type"] == "unknown_field"
      assert String.contains?(error["vars"]["field"] || "", "unknownField")
      assert String.contains?(error["vars"]["resource"] || "", "Todo")
    end

    test "validation-only endpoint works correctly" do
      assert {:ok, _request} =
               Rpc.parse(
                 %{
                   "action" => "list_todos",
                   "fields" => ["id", "title"],
                   "input" => %{"filterCompleted" => true, "priorityFilter" => "high"}
                 },
                 validation_mode?: true
               )

      error_response =
        Rpc.error(%{"action" => "list_todos", "fields" => ["id", "unknown_field"]},
          validation_mode?: true
        )

      assert error_response["success"] == false
      assert List.first(error_response["errors"])["type"] == "unknown_field"
    end
  end

  describe "field processing integration" do
    test "camelCase to snake_case conversion throughout pipeline" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "createdAt", "isOverdue"],
                 "input" => %{"filterCompleted" => true, "priorityFilter" => "high"}
               })

      assert :created_at in request.select
      assert :is_overdue in request.load
      assert request.input[:filter_completed] == true
      assert request.input[:priority_filter] == "high"
    end

    test "output formatting converts back to camelCase" do
      internal_data = [
        %{id: 1, title: "Test", created_at: ~U[2024-01-01 00:00:00Z], user_id: "123"},
        %{id: 2, title: "Another", created_at: ~U[2024-01-02 00:00:00Z], user_id: "456"}
      ]

      formatted_result = Pipeline.format_output(internal_data)

      first_item = List.first(formatted_result)
      assert Map.has_key?(first_item, "id")
      assert Map.has_key?(first_item, "title")
      assert Map.has_key?(first_item, "createdAt")
      assert Map.has_key?(first_item, "userId")
      refute Map.has_key?(first_item, "created_at")
      refute Map.has_key?(first_item, "user_id")
    end
  end

  describe "pagination integration" do
    test "pagination parameters are processed correctly" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title"],
                 "page" => %{"limit" => 10, "offset" => 20}
               })

      assert request.pagination[:limit] == 10
      assert request.pagination[:offset] == 20
    end

    test "invalid pagination format is rejected" do
      assert {:error, {:invalid_pagination, "invalid_pagination"}} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title"],
                 "page" => "invalid_pagination"
               })
    end
  end

  describe "error handling integration" do
    test "action not found flows through complete error handling" do
      error_response = Rpc.error(%{"action" => "nonexistent_action", "fields" => ["id"]})

      assert error_response["success"] == false
      error = List.first(error_response["errors"])
      assert error["type"] == "action_not_found"
      assert error["message"] == "RPC action %{actionName} not found"
      assert error["vars"]["actionName"] == "nonexistent_action"
      assert String.contains?(error["details"]["suggestion"], "rpc block")
    end

    test "field validation errors are user-friendly" do
      error_response =
        Rpc.error(%{"action" => "list_todos", "fields" => ["id", "completelyUnknownField"]})

      assert error_response["success"] == false
      error = List.first(error_response["errors"])
      assert error["type"] == "unknown_field"
      assert String.contains?(error["message"], "Unknown field")
      assert String.contains?(error["vars"]["field"] || "", "completelyUnknownField")
    end

    test "nested field errors provide context" do
      error_response =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => [%{"user" => ["id", "nonexistentUserField"]}]
        })

      assert error_response["success"] == false
      error = List.first(error_response["errors"])
      assert error["type"] == "unknown_field"
      assert String.contains?(error["message"], "Unknown field")
      assert String.contains?(error["vars"]["field"] || "", "nonexistentUserField")
    end
  end

  describe "real-world scenarios" do
    test "simple list view request parsing" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title", "status", "createdAt"]
               })

      assert request.resource == Todo
      for f <- [:id, :title, :status, :created_at], do: assert(f in request.select)
    end

    test "list with relationship request parsing" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title", "status", %{"user" => ["id", "name"]}]
               })

      assert request.resource == Todo
      for f <- [:id, :title, :status], do: assert(f in request.select)
      assert Enum.any?(request.load, &match?({:user, _}, &1))
    end

    test "detailed view with calculations request parsing" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "get_todo",
                 "fields" => [
                   "id",
                   "title",
                   "description",
                   "status",
                   "createdAt",
                   "isOverdue",
                   "daysUntilDue",
                   %{"user" => ["id", "name", "email"]},
                   %{"metadata" => ["category", "priorityScore"]}
                 ]
               })

      assert request.resource == Todo
      assert :is_overdue in request.load
      assert :days_until_due in request.load
    end

    test "request with filtering and pagination parsing" do
      assert {:ok, request} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id", "title", "status", "createdAt"],
                 "filter" => %{"status" => "active"},
                 "sort" => "created_at",
                 "page" => %{"limit" => 20, "offset" => 0}
               })

      assert request.resource == Todo
      assert request.pagination[:limit] == 20
      assert request.pagination[:offset] == 0
    end

    test "typo in field name should fail" do
      error_response = Rpc.error(%{"action" => "list_todos", "fields" => ["id", "titel"]})
      assert error_response["success"] == false
      error = List.first(error_response["errors"])
      assert error["type"] == "unknown_field"
      assert String.contains?(error["vars"]["field"] || "", "titel")
    end

    test "wrong action name should fail" do
      error_response = Rpc.error(%{"action" => "list_todo", "fields" => ["id"]})
      assert error_response["success"] == false
      assert List.first(error_response["errors"])["type"] == "action_not_found"
    end

    test "invalid nested structure should fail" do
      error_response =
        Rpc.error(%{"action" => "list_todos", "fields" => [%{"user" => "should_be_array"}]})

      assert error_response["success"] == false
      assert List.first(error_response["errors"])["type"] == "unsupported_field_combination"
    end

    test "invalid pagination format should fail" do
      error_response = Rpc.error(%{"action" => "list_todos", "fields" => ["id"], "page" => 10})
      assert error_response["success"] == false
      assert List.first(error_response["errors"])["type"] == "invalid_pagination"
    end
  end
end
