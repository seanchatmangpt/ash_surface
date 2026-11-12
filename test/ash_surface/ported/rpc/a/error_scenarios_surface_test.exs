defmodule AshSurface.Ported.Rpc.A.ErrorScenariosSurfaceTest do
  @moduledoc """
  Non-actuating port of the request-refusal half of `error_scenarios_test.exs`. Tests whose
  error comes from Ash action execution (casting, required, not_found, page validation,
  validate_action) stay in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.Rpc
  alias AshSurface.RuntimeParity.Rpc.Pipeline

  # Real Ash validation errors, built by non-executing changeset/query/input constructors and
  # fed through the pipeline's failure envelope (nothing is executed).
  defp create_errors(input),
    do: Ash.Changeset.for_create(P.Todo, :create, input).errors

  defp not_found(id),
    do: Ash.Error.Query.NotFound.exception(primary_key: %{id: id}, resource: P.Todo)

  describe "actual error behavior" do
    test "invalid field returns unknown_field error" do
      result = Rpc.error(%{"action" => "list_todos", "fields" => ["id", "invalid_field"]})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "unknown_field"
      assert error["message"] =~ "Unknown field"
      assert error["vars"]["field"] == "invalidField"
    end

    test "non-existent action returns action_not_found" do
      result = Rpc.error(%{"action" => "non_existent_action", "fields" => ["id"]})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "action_not_found"
      assert error["message"] =~ "not found"
      assert error["vars"]["actionName"] == "non_existent_action"
      assert error["message"] == "RPC action %{actionName} not found"

      assert Enum.all?(Map.keys(error["vars"]), fn key ->
               String.contains?(error["message"], "%{#{key}}")
             end)
    end

    test "missing fields parameter returns proper error" do
      result = Rpc.error(%{"action" => "list_todos"})

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "missing_required_parameter"
      assert error["message"] == "Required parameter %{parameter} is missing or empty"
      assert error["vars"]["parameter"] == "fields"
    end

    test "nested field errors maintain path context" do
      result =
        Rpc.error(%{
          "action" => "list_todos",
          "fields" => ["id", %{"user" => ["id", "invalid_nested_field"]}]
        })

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "unknown_field"
      assert String.contains?(error["vars"]["field"] || "", "invalidNestedField")
      assert "user" in error["path"]
    end

    test "wrong data type returns invalid_attribute error" do
      params = %{"action" => "create_todo", "input" => %{"title" => 123}, "fields" => ["id"]}
      assert {:ok, _request} = Rpc.parse(params)

      result =
        Pipeline.error_response(create_errors(%{"title" => 123, user_id: Ash.UUID.generate()}))

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "invalid_attribute"
      assert error["message"] == "is invalid"
      assert "title" in error["fields"]
    end

    test "missing required field returns required error" do
      result = Pipeline.error_response(create_errors(%{user_id: Ash.UUID.generate()}))

      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "required"
      assert "title" in error["fields"]
    end

    test "destroy and update of a missing record return not_found" do
      id = Ash.UUID.generate()

      assert {:ok, %{resource: P.Todo}} =
               Rpc.parse(%{"action" => "destroy_todo", "identity" => id})

      assert {:ok, %{resource: P.Todo}} =
               Rpc.parse(%{
                 "action" => "update_todo",
                 "identity" => id,
                 "input" => %{"title" => "x"},
                 "fields" => ["id"]
               })

      result = Pipeline.error_response(not_found(id))
      assert result["success"] == false
      assert [%{"type" => "not_found"}] = result["errors"]
    end

    test "invalid enum value returns invalid_attribute" do
      errors =
        create_errors(%{
          title: "Test",
          user_id: Ash.UUID.generate(),
          priority: "invalid_priority"
        })

      result = Pipeline.error_response(errors)
      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] == "invalid_attribute"
      assert "priority" in error["fields"]
    end

    test "invalid pagination returns proper error" do
      params = %{"action" => "list_todos", "fields" => ["id"], "page" => %{"limit" => -5}}
      assert {:ok, %{pagination: %{limit: -5}}} = Rpc.parse(params)

      errors = Ash.Query.page(Ash.Query.for_read(P.Todo, :read, %{}), limit: -5).errors
      assert [%Ash.Error.Query.InvalidPage{}] = errors

      result = Pipeline.error_response(errors)
      assert result["success"] == false
      [error | _] = result["errors"]
      assert error["type"] in ["invalid_page", "invalid_attribute"]
    end

    test "validate action returns errors for a missing record" do
      params = %{
        "action" => "update_todo",
        "identity" => "550e8400-e29b-41d4-a716-446655440000",
        "input" => %{"title" => "Updated"}
      }

      assert {:ok, _request} = Rpc.parse(params, validation_mode?: true)

      result = Pipeline.error_response(not_found(params["identity"]))
      assert [%{"type" => "not_found"} | _] = result["errors"]
    end
  end
end
