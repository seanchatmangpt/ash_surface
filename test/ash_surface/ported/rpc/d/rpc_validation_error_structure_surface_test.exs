defmodule AshSurface.Ported.Rpc.D.RpcValidationErrorStructureSurfaceTest do
  @moduledoc """
  Surface port of `rpc_validation_error_structure_test.exs`. `validate_action` is
  `AshSurface.Ported.RpcValidate.validate/2` (parse in validation mode + real Ash
  query/changeset validation, no data layer); `run_action` error comparison uses the
  request-refusal path of the non-actuating pipeline.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, RpcValidate}

  # AshSurface.Errors camelCases `fields` / `vars.field` / path via the output field formatter
  # and emits the bare message template for Invalid* types, as the reference does (F1-errcamel).
  defp names(field), do: [field]
  defp field_in?(fields, field), do: Enum.any?(names(field), &(&1 in fields))

  describe "required field validation errors" do
    test "missing required title field returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "autoComplete" => false,
            "userId" => "550e8400-e29b-41d4-a716-446655440000"
            # Missing required title
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])
      assert result["errors"] != []

      # Field names are formatted for client (camelCase)
      title_error = Enum.find(result["errors"], &field_in?(&1["fields"], "title"))
      assert title_error != nil

      # Assert on error structure - missing required fields show as invalid_attribute
      assert title_error["type"] == "invalid_attribute"
      assert title_error["message"] =~ "is required"
      assert is_map(title_error["vars"])
      assert title_error["vars"]["field"] in names("title")
      assert field_in?(title_error["fields"], "title")
      assert is_list(title_error["path"])
      assert Map.has_key?(title_error, "shortMessage")
    end

    test "missing required user_id field returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => "Test Todo",
            "autoComplete" => false
            # Missing required userId
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      # Find the user_id required error - field names are formatted (userId in camelCase)
      user_id_error = Enum.find(result["errors"], &field_in?(&1["fields"], "userId"))
      assert user_id_error != nil

      # Assert on error structure - missing required fields show as invalid_attribute
      assert user_id_error["type"] == "invalid_attribute"
      assert user_id_error["message"] =~ "is required"
      assert is_map(user_id_error["vars"])
      assert user_id_error["vars"]["field"] in names("userId")
      assert field_in?(user_id_error["fields"], "userId")
      assert is_list(user_id_error["path"])
      assert Map.has_key?(user_id_error, "shortMessage")
    end

    test "multiple missing required fields returns multiple errors" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "autoComplete" => false
            # Missing both title and userId
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])
      assert length(result["errors"]) >= 2

      # Check that we have required errors for both fields - field names are formatted
      title_error = Enum.find(result["errors"], &field_in?(&1["fields"], "title"))
      user_id_error = Enum.find(result["errors"], &field_in?(&1["fields"], "userId"))

      assert title_error != nil
      assert user_id_error != nil

      # Both should be "invalid_attribute" type errors with "is required" message
      assert title_error["type"] == "invalid_attribute"
      assert title_error["message"] =~ "is required"
      assert user_id_error["type"] == "invalid_attribute"
      assert user_id_error["message"] =~ "is required"
    end
  end

  describe "invalid attribute type validation errors" do
    test "invalid title type returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            # Should be string, not integer
            "title" => 123,
            "autoComplete" => false,
            "userId" => "550e8400-e29b-41d4-a716-446655440000"
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      # Find the title error - field names are formatted
      title_error = Enum.find(result["errors"], &field_in?(&1["fields"], "title"))
      assert title_error != nil

      # Assert on error structure
      assert title_error["type"] == "invalid_attribute"
      assert title_error["message"] =~ "is invalid"
      assert is_map(title_error["vars"])
      assert title_error["vars"]["field"] in names("title")
      assert field_in?(title_error["fields"], "title")
      assert is_list(title_error["path"])
      assert Map.has_key?(title_error, "shortMessage")
    end

    test "invalid user_id type returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => "Test Todo",
            "autoComplete" => false,
            # Should be UUID string, not integer
            "userId" => 12_345
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      # Find the user_id error - field names are formatted (userId in camelCase)
      user_id_error = Enum.find(result["errors"], &field_in?(&1["fields"], "userId"))
      assert user_id_error != nil

      # Assert on error structure
      assert user_id_error["type"] == "invalid_attribute"
      assert user_id_error["message"] =~ "is invalid"
      assert is_map(user_id_error["vars"])
      assert user_id_error["vars"]["field"] in names("userId")
      assert field_in?(user_id_error["fields"], "userId")
      assert is_list(user_id_error["path"])
      assert Map.has_key?(user_id_error, "shortMessage")
    end
  end

  describe "invalid enum value validation errors" do
    test "invalid priority enum value returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => "Test Todo",
            "autoComplete" => false,
            "userId" => "550e8400-e29b-41d4-a716-446655440000",
            # Not in [:low, :medium, :high, :urgent]
            "priority" => "invalid_priority"
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      # Find the priority error - field names are formatted
      priority_error = Enum.find(result["errors"], &field_in?(&1["fields"], "priority"))
      assert priority_error != nil

      # Assert on error structure
      assert priority_error["type"] == "invalid_attribute"
      assert priority_error["message"] =~ "is invalid"
      assert is_map(priority_error["vars"])
      assert priority_error["vars"]["field"] in names("priority")
      assert field_in?(priority_error["fields"], "priority")
      assert is_list(priority_error["path"])
      assert Map.has_key?(priority_error, "shortMessage")
    end

    test "invalid priority argument in read action returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          "input" => %{
            # Not a valid priority value
            "priorityFilter" => "invalid_priority"
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      [error | _] = result["errors"]

      # Assert on error structure - arguments use invalid_argument type
      # Field names are formatted (priorityFilter in camelCase)
      assert error["type"] == "invalid_argument"
      assert error["message"] =~ "is invalid"
      assert is_map(error["vars"])
      assert error["vars"]["field"] in names("priorityFilter")
      assert field_in?(error["fields"], "priorityFilter")
      assert is_list(error["path"])
      assert error["path"] == []
      assert Map.has_key?(error, "shortMessage")
    end
  end

  describe "error structure completeness" do
    test "all validation errors include required error fields" do
      # Create a validation with multiple errors
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            # Invalid type for title
            "title" => 123,
            # Invalid enum for priority
            "priority" => "invalid",
            # Missing required userId
            "autoComplete" => false
          }
        })

      assert result["success"] == false
      assert is_list(result["errors"])
      assert result["errors"] != []

      # Every error should have the required structure
      for error <- result["errors"] do
        # Required fields from AshTypescript.Rpc.Error protocol
        assert Map.has_key?(error, "type"), "Error missing 'type' field: #{inspect(error)}"

        assert Map.has_key?(error, "message"),
               "Error missing 'message' field: #{inspect(error)}"

        assert Map.has_key?(error, "shortMessage"),
               "Error missing 'shortMessage' field: #{inspect(error)}"

        assert Map.has_key?(error, "vars"), "Error missing 'vars' field: #{inspect(error)}"
        assert Map.has_key?(error, "fields"), "Error missing 'fields' field: #{inspect(error)}"
        assert Map.has_key?(error, "path"), "Error missing 'path' field: #{inspect(error)}"

        # Type assertions
        assert is_binary(error["type"]), "Error type should be string: #{inspect(error)}"

        assert is_binary(error["message"]),
               "Error message should be string: #{inspect(error)}"

        assert is_binary(error["shortMessage"]),
               "Error shortMessage should be string: #{inspect(error)}"

        assert is_map(error["vars"]), "Error vars should be map: #{inspect(error)}"
        assert is_list(error["fields"]), "Error fields should be list: #{inspect(error)}"
        assert is_list(error["path"]), "Error path should be list: #{inspect(error)}"
      end
    end

    test "error vars contain relevant field information" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "autoComplete" => false,
            "userId" => "550e8400-e29b-41d4-a716-446655440000"
            # Missing title
          }
        })

      assert result["success"] == false
      # Field names are formatted
      title_error = Enum.find(result["errors"], &field_in?(&1["fields"], "title"))
      assert title_error != nil

      # The vars map should contain the field name (formatted)
      assert Map.has_key?(title_error["vars"], "field")
      assert title_error["vars"]["field"] in names("title")
    end

    test "error messages are non-empty strings" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => 123,
            # Invalid type
            "userId" => "550e8400-e29b-41d4-a716-446655440000"
          }
        })

      assert result["success"] == false

      for error <- result["errors"] do
        assert is_binary(error["message"])
        assert String.length(error["message"]) > 0
        assert is_binary(error["shortMessage"])
        assert String.length(error["shortMessage"]) > 0
      end
    end
  end

  describe "successful validation structure" do
    test "successful validation returns expected structure" do
      result =
        RpcValidate.validate(%{
          "action" => "create_todo",
          "input" => %{
            "title" => "Valid Todo",
            "autoComplete" => false,
            "userId" => "550e8400-e29b-41d4-a716-446655440000"
          }
        })

      assert result["success"] == true
      assert is_map(result)
      # Successful validations should not have errors
      refute Map.has_key?(result, "errors")
    end
  end

  describe "pagination validation errors" do
    test "invalid pagination parameter type returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "list_todos",
          # Wrong type - should be map
          "page" => "invalid_pagination"
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      [error | _] = result["errors"]

      # Assert on error structure
      assert error["type"] == "invalid_pagination"
      assert error["message"] == "Invalid pagination parameter format"
      assert is_map(error["vars"])
      assert error["vars"]["received"] == "\"invalid_pagination\""
      assert is_list(error["fields"])
      assert error["fields"] == []
      assert is_list(error["path"])
      assert error["path"] == []
      assert Map.has_key?(error, "shortMessage")
      assert Map.has_key?(error, "details")
    end
  end

  describe "action not found errors" do
    test "non-existent action returns proper error structure" do
      result =
        RpcValidate.validate(%{
          "action" => "non_existent_action"
        })

      assert result["success"] == false
      assert is_list(result["errors"])

      [error | _] = result["errors"]

      # Assert on error structure
      assert error["type"] == "action_not_found"
      assert is_binary(error["message"])
      assert is_map(error["vars"])
      assert error["vars"]["actionName"] == "non_existent_action"
      assert is_list(error["fields"])
      assert is_list(error["path"])
    end
  end

  describe "comparison with run_action errors" do
    test "validate_action and run_action return same error structure for validation errors" do
      validate_input = %{
        "action" => "create_todo",
        "input" => %{
          "title" => 123,
          # Invalid type
          "userId" => "550e8400-e29b-41d4-a716-446655440000"
        }
      }

      validate_result = RpcValidate.validate(validate_input)

      # The executor's create fails with the changeset's Ash errors; feed that real failure
      # through the pipeline's result path.
      run_params = Map.put(validate_input, "fields", ["id"])
      {:ok, request} = Rpc.parse(run_params)

      changeset = Ash.Changeset.for_create(request.resource, request.action.name, request.input)
      run_result = Rpc.run(run_params, {:error, Ash.Error.to_error_class(changeset.errors)})

      assert validate_result["success"] == false
      assert run_result["success"] == false

      # Both should return the same error structure
      validate_error = List.first(validate_result["errors"])
      run_error = List.first(run_result["errors"])

      assert validate_error["type"] == run_error["type"]
      assert validate_error["fields"] == run_error["fields"]
      # Messages should be similar (might have slight differences)
      assert is_binary(validate_error["message"])
      assert is_binary(run_error["message"])
    end
  end
end
