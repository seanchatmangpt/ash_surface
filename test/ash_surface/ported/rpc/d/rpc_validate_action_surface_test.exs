defmodule AshSurface.Ported.Rpc.D.RpcValidateActionSurfaceTest do
  @moduledoc """
  Surface port of `rpc_validate_action_test.exs` via `AshSurface.Ported.RpcValidate.validate/2`
  (parse in validation mode + real Ash query/changeset validation, no data layer). Update
  targets are caller-built `Todo` structs; `run_action` comparisons use `Rpc.error/1` (request
  refusals) and `Rpc.run/2` (caller-built results).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcValidate, Todo}

  @user_id "550e8400-e29b-41d4-a716-446655440000"

  describe "validate_action functionality" do
    test "validates CRUD action parameters" do
      assert RpcValidate.validate(%{"action" => "list_todos"})["success"] == true

      create_result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{"title" => "Test Todo", "autoComplete" => false, "userId" => @user_id}
        })

      assert create_result["success"] == true
    end

    test "validates field-selectable action parameters" do
      assert RpcValidate.validate(%{"action" => "get_statistics_todo"})["success"] == true
    end

    test "validates primitive return action parameters" do
      result =
        RpcValidate.validate(%{
          "action" => "bulk_complete_todo",
          "input" => %{"todoIds" => [@user_id]}
        })

      assert result["success"] == true
    end
  end

  describe "form validation scenarios" do
    test "validates create action input" do
      valid_result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => "Valid Todo Title",
            "description" => "A valid description",
            "autoComplete" => false,
            "userId" => @user_id
          }
        })

      assert valid_result["success"] == true

      invalid_result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{"title" => "Valid Title", "autoComplete" => false}
        })

      assert invalid_result["success"] == false
      error_message = inspect(invalid_result["errors"])
      assert error_message =~ "validation_error" or error_message =~ "required"
    end

    test "validates update action input" do
      result =
        RpcValidate.validate(
          %{
            "action" => "update_todo",
            "identity" => @user_id,
            "input" => %{"title" => "Updated Title", "completed" => true}
          },
          record: struct(Todo, id: @user_id, title: "Old", completed: false)
        )

      assert is_map(result)
      assert Map.has_key?(result, "success")

      if not result["success"] do
        assert result["errors"] != [], "Should have at least one error"
        [error | _] = result["errors"]
        assert error["type"] == "not_found"
      end
    end

    test "validates read action arguments" do
      valid_result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          "input" => %{"filterCompleted" => true, "priorityFilter" => "high"}
        })

      assert valid_result["success"] == true

      invalid_result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          "input" => %{"priorityFilter" => "invalid_priority"}
        })

      assert invalid_result["success"] == false
    end

    test "validates pagination parameters" do
      result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          "page" => %{"limit" => 50, "offset" => 0}
        })

      assert result["success"] == true

      invalid_result =
        RpcValidate.validate(%{"action" => "list_todos", "page" => "invalid_pagination_format"})

      assert invalid_result["success"] == false
    end
  end

  describe "client-side form validation" do
    test "validates todo creation form" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{"title" => "", "autoComplete" => false, "userId" => @user_id}
        })

      assert is_map(result)
      assert Map.has_key?(result, "success")
    end

    test "validates action existence" do
      result = RpcValidate.validate(%{"action" => "non_existent_action"})

      assert result["success"] == false
      error_message = inspect(result["errors"])
      assert error_message =~ "action_not_found" or error_message =~ "not found"
    end
  end

  describe "comparison with run_action behavior" do
    test "validate_action vs run_action for CRUD actions" do
      # run_action requires fields for data selection
      run_result = Rpc.error(%{"action" => "list_todos"})
      assert run_result["success"] == false
      error_message = inspect(run_result["errors"])
      assert error_message =~ "missing_required_parameter" or error_message =~ "fields"

      # validate_action works without fields
      assert RpcValidate.validate(%{"action" => "list_todos"})["success"] == true
    end

    test "validate_action vs run_action for field-selectable actions" do
      run_result = Rpc.error(%{"action" => "get_statistics_todo"})
      assert run_result["success"] == false

      assert RpcValidate.validate(%{"action" => "get_statistics_todo"})["success"] == true
    end

    test "field requirements still enforced in run_action" do
      run_result = Rpc.error(%{"action" => "get_statistics_todo", "fields" => []})

      assert run_result["success"] == false
      assert inspect(run_result["errors"]) =~ "empty_fields_array"

      params = %{"action" => "get_statistics_todo", "fields" => ["total", "completed"]}
      result = Rpc.run(params, %{total: 3, completed: 1, priority_counts: %{}, overdue: 0})

      assert result["success"] == true
    end
  end

  describe "pagination refusals (mutation-killing)" do
    test "top-level page on a non-list action is refused as pagination_not_supported" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{"title" => "T", "autoComplete" => false, "userId" => @user_id},
          "page" => %{"limit" => 5}
        })

      assert result["success"] == false
      assert [error] = result["errors"]
      assert error["type"] == "pagination_not_supported"
      assert error["shortMessage"] == "Pagination not supported"
      assert to_string(error["details"]["reason"]) == "unsupported"
    end

    test "unknown page keys are refused as invalid_pagination naming the keys" do
      result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          "page" => %{"limit" => 5, "bogusKey" => 1}
        })

      assert result["success"] == false
      assert [error] = result["errors"]
      assert error["type"] == "invalid_pagination"
      assert error["vars"]["keys"] =~ "bogusKey"
      assert error["path"] == ["page"]
    end

    test "non-map page is refused with the exact received payload (P2)" do
      assert {:error, {:invalid_pagination, "bogus"}} =
               Rpc.parse(%{"action" => "list_todos", "fields" => ["id"], "page" => "bogus"})

      result =
        RpcValidate.validate(%{"action" => "list_todos", "page" => "bogus"})

      assert [error] = result["errors"]
      assert error["type"] == "invalid_pagination"
      assert error["message"] == "Invalid pagination parameter format"
      assert error["vars"]["received"] == inspect("bogus")
      assert error["path"] == []
    end

    test "unknown page keys travel as strings (P3)" do
      assert {:error, {:unknown_page_keys, keys}} =
               Rpc.parse(%{
                 "action" => "list_todos",
                 "fields" => ["id"],
                 "page" => %{"limit" => 5, "bogusKey" => 1}
               })

      assert Enum.all?(keys, &is_binary/1)
      assert length(keys) == 1
    end

    test "page on a list read without pagination support is refused (P4)" do
      assert {:error, {:pagination_not_supported, :top_level, :unsupported}} =
               Rpc.parse(%{
                 "action" => "list_high_priority_todos",
                 "fields" => ["id"],
                 "page" => %{"limit" => 5}
               })

      assert {:ok, _} =
               Rpc.parse(%{"action" => "list_high_priority_todos", "fields" => ["id"]})
    end

    test "disabled vs unsupported top-level param reason (P6)" do
      assert {:error, {:filter_not_supported, :top_level, :disabled}} =
               Rpc.parse(%{
                 "action" => "list_todos_no_filter",
                 "fields" => ["id"],
                 "filter" => %{"status" => %{"eq" => "active"}}
               })

      assert {:error, {:sort_not_supported, :top_level, :disabled}} =
               Rpc.parse(%{
                 "action" => "list_todos_no_sort",
                 "fields" => ["id"],
                 "sort" => "-createdAt"
               })

      assert {:error, {:sort_not_supported, :top_level, :unsupported}} =
               Rpc.parse(%{
                 "action" => "create_todo",
                 "fields" => ["id"],
                 "input" => %{"title" => "T", "autoComplete" => false, "userId" => @user_id},
                 "sort" => "-createdAt"
               })

      result =
        RpcValidate.validate(%{
          "action" => "list_todos_no_sort",
          "sort" => "-createdAt"
        })

      assert [%{"type" => "sort_not_supported", "details" => %{"reason" => reason}}] =
               result["errors"]

      assert to_string(reason) == "disabled"
    end
  end
end
