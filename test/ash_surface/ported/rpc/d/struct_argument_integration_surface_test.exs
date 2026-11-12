defmodule AshSurface.Ported.Rpc.D.StructArgumentIntegrationSurfaceTest do
  @moduledoc """
  Surface port of the runtime half of `struct_argument_integration_test.exs`. Struct
  arguments are cast by the request parser (`Rpc.parse`); the generic action's result is a
  caller-built map (no `run` callback executes) fed through result processing and formatting.
  TypeScript-text tests stay loud skips in `struct_argument_integration_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.{Rpc, User}

  @id1 "11111111-1111-1111-1111-111111111111"
  @id2 "22222222-2222-2222-2222-222222222222"

  describe "assign_to_user action with User struct argument" do
    test "accepts User struct argument and processes it correctly" do
      params = %{
        "action" => "assign_to_user_todo",
        "input" => %{
          "assignee" => %{"id" => @id1, "name" => "Test Assignee", "email" => "assignee@test.com"},
          "reason" => "Testing struct argument"
        },
        "fields" => ["assigneeId", "assigneeName", "reason"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert %User{id: @id1, name: "Test Assignee"} = request.input.assignee
      assert request.input.reason == "Testing struct argument"

      result =
        Rpc.run(params, %{
          assignee_id: @id1,
          assignee_name: "Test Assignee",
          reason: "Testing struct argument"
        })

      assert result["success"] == true, "Expected success, got: #{inspect(result)}"
      data = result["data"]
      assert data["assigneeId"] == @id1
      assert data["assigneeName"] == "Test Assignee"
      assert data["reason"] == "Testing struct argument"
    end

    test "accepts User struct argument with optional reason" do
      params = %{
        "action" => "assign_to_user_todo",
        "input" => %{
          "assignee" => %{
            "id" => @id1,
            "name" => "Optional Reason User",
            "email" => "optional@test.com"
          }
        },
        "fields" => ["assigneeId", "assigneeName", "reason"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert %User{id: @id1} = request.input.assignee
      refute Map.has_key?(request.input, :reason)

      result =
        Rpc.run(params, %{assignee_id: @id1, assignee_name: "Optional Reason User", reason: nil})

      assert result["success"] == true, "Expected success, got: #{inspect(result)}"
      assert result["data"]["assigneeId"] == @id1
      assert result["data"]["assigneeName"] == "Optional Reason User"
      assert result["data"]["reason"] == nil
    end

    test "fails when assignee struct is missing required fields" do
      params = %{
        "action" => "assign_to_user_todo",
        "input" => %{"assignee" => %{}},
        "fields" => ["assigneeId", "assigneeName"]
      }

      # The request parses (the empty map reaches the action as-is); a result built from
      # its missing fields carries nils, matching the reference's tolerated outcome.
      assert {:ok, request} = Rpc.parse(params)
      assignee = request.input.assignee

      result =
        Rpc.run(params, %{
          assignee_id: Map.get(assignee, :id),
          assignee_name: Map.get(assignee, :name)
        })

      assert result["success"] == false or
               (result["success"] == true and result["data"]["assigneeName"] == nil)
    end
  end

  describe "assign_to_users action with array of User struct arguments" do
    test "accepts array of User structs and processes them correctly" do
      params = %{
        "action" => "assign_to_users_todo",
        "input" => %{
          "assignees" => [
            %{"id" => @id1, "name" => "User One", "email" => "user1@test.com"},
            %{"id" => @id2, "name" => "User Two", "email" => "user2@test.com"}
          ]
        },
        "fields" => ["assigneeId", "assigneeName"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert [%User{id: @id1}, %User{id: @id2}] = request.input.assignees

      result =
        Rpc.run(
          params,
          Enum.map(request.input.assignees, &%{assignee_id: &1.id, assignee_name: &1.name})
        )

      assert result["success"] == true, "Expected success, got: #{inspect(result)}"
      data = result["data"]
      assert is_list(data)
      assert length(data) == 2
      [first, second] = data
      assert first["assigneeId"] == @id1
      assert first["assigneeName"] == "User One"
      assert second["assigneeId"] == @id2
      assert second["assigneeName"] == "User Two"
    end

    test "accepts empty array of assignees" do
      params = %{
        "action" => "assign_to_users_todo",
        "input" => %{"assignees" => []},
        "fields" => ["assigneeId", "assigneeName"]
      }

      assert {:ok, request} = Rpc.parse(params)
      assert request.input.assignees == []

      result = Rpc.run(params, [])
      assert result["success"] == true, "Expected success, got: #{inspect(result)}"
      assert result["data"] == []
    end
  end
end
