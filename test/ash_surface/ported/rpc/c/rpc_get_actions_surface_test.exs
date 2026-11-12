defmodule AshSurface.Ported.Rpc.C.RpcGetActionsSurfaceTest do
  @moduledoc """
  Port of the reference rpc_get_actions tests that are decidable without running an action:
  request parsing (`get?` / `get_by` validation, unknown fields, validation mode) and result
  processing of caller-built records through the non-actuating pipeline
  (`AshSurface.Ported.Rpc.run/2`). Data-layer lookups ("retrieves X by Y"), generated-TypeScript
  text and global-config execution semantics stay loud skips in `rpc_get_actions_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported, as: P

  defp todo(attrs \\ %{}),
    do:
      struct(P.Todo, Map.merge(%{id: "t1", title: "Test Todo for Get", description: "d"}, attrs))

  defp user(attrs \\ %{}),
    do:
      struct(
        P.User,
        Map.merge(%{id: "u1", name: "Alice Smith", email: "alice@example.com"}, attrs)
      )

  defp not_found(resource),
    do: {:error, Ash.Error.to_ash_error(%Ash.Error.Query.NotFound{resource: resource})}

  defp first_error(result), do: result["errors"] |> List.first()

  describe "get? option - single resource read action" do
    test "retrieves single todo with basic fields (returns any single record)" do
      todo = todo(%{status: :pending, completed: false})

      result =
        R.run(%{"action" => "get_single_todo", "fields" => ["id", "title", "description"]}, todo)

      assert result["success"] == true
      assert is_map(result["data"])
      assert Map.has_key?(result["data"], "id")
      assert Map.has_key?(result["data"], "title")
      assert Map.has_key?(result["data"], "description")
      refute Map.has_key?(result["data"], "status")
      refute Map.has_key?(result["data"], "completed")
    end

    test "retrieves todo with input parameters (using action's built-in arguments)" do
      params = %{
        "action" => "get_single_todo",
        "input" => %{"filterCompleted" => false},
        "fields" => ["id", "title", "completed"]
      }

      assert {:ok, request} = R.parse(params)
      assert request.input == %{filter_completed: false}

      result = R.run(params, todo(%{completed: false}))
      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["completed"] == false
    end

    test "retrieves todo with relationship fields" do
      record = todo() |> Map.put(:user, user())

      result =
        R.run(
          %{
            "action" => "get_single_todo",
            "fields" => ["id", "title", %{"user" => ["id", "name", "email"]}]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["user"]["id"] == "u1"
      assert result["data"]["user"]["name"] == "Alice Smith"
    end

    test "retrieves todo with calculation fields" do
      record = todo(%{is_overdue: false, days_until_due: 3})

      result =
        R.run(
          %{
            "action" => "get_single_todo",
            "fields" => ["id", "title", "isOverdue", "daysUntilDue"]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert Map.has_key?(result["data"], "isOverdue")
      assert Map.has_key?(result["data"], "daysUntilDue")
    end

    test "retrieves todo with aggregate fields" do
      record = todo(%{comment_count: 2, has_comments: true})

      result =
        R.run(
          %{
            "action" => "get_single_todo",
            "fields" => ["id", "title", "commentCount", "hasComments"]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert is_integer(result["data"]["commentCount"])
      assert is_boolean(result["data"]["hasComments"])
    end

    test "retrieves todo with embedded resource fields" do
      record =
        todo(%{metadata: struct(P.TodoMetadata, %{category: "work", priority_score: 5})})

      result =
        R.run(
          %{
            "action" => "get_single_todo",
            "fields" => ["id", "title", %{"metadata" => ["category", "priorityScore"]}]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert is_map(result["data"]["metadata"])
      assert result["data"]["metadata"]["category"] == "work"
      assert result["data"]["metadata"]["priorityScore"] == 5
    end

    test "retrieves todo with self calculation" do
      record = todo(%{status: :pending}) |> Map.put(:self, todo(%{status: :pending}))

      result =
        R.run(
          %{
            "action" => "get_single_todo",
            "fields" => [
              "id",
              "title",
              %{
                "self" => %{
                  "args" => %{"prefix" => "test_"},
                  "fields" => ["id", "title", "status"]
                }
              }
            ]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert is_map(result["data"]["self"])
      assert Map.has_key?(result["data"]["self"], "id")
      assert Map.has_key?(result["data"]["self"], "title")
    end

    test "returns null with not_found_error?: false when no records exist" do
      result = R.run(%{"action" => "get_single_todo_nullable", "fields" => ["id", "title"]}, nil)

      assert result["success"] == true
      assert result["data"] == nil
    end

    test "returns record with not_found_error?: false when found" do
      result =
        R.run(%{"action" => "get_single_todo_nullable", "fields" => ["id", "title"]}, todo())

      assert result["success"] == true
      assert is_map(result["data"])
      assert Map.has_key?(result["data"], "id")
      assert Map.has_key?(result["data"], "title")
    end

    test "rejects invalid field names" do
      result =
        R.run(%{"action" => "get_single_todo", "fields" => ["id", "nonExistentField"]}, todo())

      assert result["success"] == false
      assert first_error(result)["type"] == "unknown_field"
    end
  end

  describe "get_by option - single resource by specified fields" do
    test "retrieves single user by email with basic fields" do
      params = %{
        "action" => "get_user_by_email",
        "getBy" => %{"email" => "alice@example.com"},
        "fields" => ["id", "name", "email"]
      }

      assert {:ok, request} = R.parse(params)
      assert request.get_by == %{email: "alice@example.com"}

      result = R.run(params, user())
      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["id"] == "u1"
      assert result["data"]["name"] == "Alice Smith"
      assert result["data"]["email"] == "alice@example.com"
    end

    test "retrieves different user by different email" do
      params = %{
        "action" => "get_user_by_email",
        "getBy" => %{"email" => "bob@example.com"},
        "fields" => ["id", "name", "email"]
      }

      assert {:ok, request} = R.parse(params)
      assert request.get_by == %{email: "bob@example.com"}

      bob = user(%{id: "u2", name: "Bob Jones", email: "bob@example.com"})
      result = R.run(params, bob)
      assert result["success"] == true
      assert result["data"]["id"] == "u2"
      assert result["data"]["name"] == "Bob Jones"
      assert result["data"]["email"] == "bob@example.com"
    end

    test "retrieves user with relationship fields" do
      record = user() |> Map.put(:todos, [todo(%{title: "Alice's Todo"})])

      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "alice@example.com"},
            "fields" => ["id", "name", "email", %{"todos" => ["id", "title"]}]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["name"] == "Alice Smith"
      assert is_list(result["data"]["todos"])
      assert result["data"]["todos"] != []
      assert hd(result["data"]["todos"])["title"] == "Alice's Todo"
    end

    test "retrieves user with calculation fields" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "alice@example.com"},
            "fields" => ["id", "name", "isActive"]
          },
          user(%{is_active?: true})
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["name"] == "Alice Smith"
      assert Map.has_key?(result["data"], "isActive")
    end

    test "retrieves user with self calculation" do
      record = user() |> Map.put(:self, user())

      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "alice@example.com"},
            "fields" => [
              "id",
              "name",
              %{
                "self" => %{
                  "args" => %{"prefix" => "user_"},
                  "fields" => ["id", "name", "email"]
                }
              }
            ]
          },
          record
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert is_map(result["data"]["self"])
      assert result["data"]["self"]["name"] == "Alice Smith"
      assert result["data"]["self"]["email"] == "alice@example.com"
    end

    test "returns error for non-existent email (default behavior)" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "nonexistent@example.com"},
            "fields" => ["id", "name"]
          },
          not_found(P.User)
        )

      assert result["success"] == false
      assert is_list(result["errors"])
      assert first_error(result)["type"] in ["not_found", "NotFound"]
    end

    test "requires email in getBy" do
      result =
        R.run(
          %{"action" => "get_user_by_email", "getBy" => %{}, "fields" => ["id", "name"]},
          nil
        )

      assert result["success"] == false
      assert is_list(result["errors"])
    end

    test "rejects invalid field names" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "alice@example.com"},
            "fields" => ["id", "nonExistentField"]
          },
          user()
        )

      assert result["success"] == false
      assert first_error(result)["type"] == "unknown_field"
    end

    test "rejects operator map in getBy value (filter injection, CVE 3212)" do
      result =
        R.error(%{
          "action" => "get_user_by_email",
          "getBy" => %{"email" => %{"less_than" => "b"}},
          "fields" => ["id", "name", "email"]
        })

      assert result["success"] == false
      assert first_error(result)["type"] == "invalid_get_by"
    end

    test "rejects list value in getBy value (filter injection, CVE 3212)" do
      result =
        R.error(%{
          "action" => "get_user_by_email",
          "getBy" => %{"email" => ["alice@example.com", "bob@example.com"]},
          "fields" => ["id", "name", "email"]
        })

      assert result["success"] == false
      assert first_error(result)["type"] == "invalid_get_by"
    end
  end

  describe "get_by option with multiple fields - composite lookup" do
    defp composite(status, fields),
      do: %{
        "action" => "get_todo_by_user_and_status",
        "getBy" => %{"userId" => "u1", "status" => status},
        "fields" => fields
      }

    test "retrieves todo by user_id and status" do
      assert {:ok, request} = R.parse(composite("pending", ["id", "title", "status"]))
      assert request.get_by == %{user_id: "u1", status: "pending"}

      result =
        R.run(
          composite("pending", ["id", "title", "status"]),
          todo(%{title: "Pending Todo", status: :pending})
        )

      assert result["success"] == true
      assert result["data"]["id"] == "t1"
      assert result["data"]["title"] == "Pending Todo"
      assert result["data"]["status"] == "pending"
    end

    test "retrieves different todo with different status for same user" do
      assert {:ok, request} = R.parse(composite("ongoing", ["id", "title", "status"]))
      assert request.get_by == %{user_id: "u1", status: "ongoing"}

      result =
        R.run(
          composite("ongoing", ["id", "title", "status"]),
          todo(%{id: "t2", title: "Ongoing Todo", status: :ongoing})
        )

      assert result["success"] == true
      assert result["data"]["id"] == "t2"
      assert result["data"]["title"] == "Ongoing Todo"
      assert result["data"]["status"] == "ongoing"
    end

    test "retrieves finished todo" do
      fields = ["id", "title", "status", "completed"]

      result =
        R.run(
          composite("finished", fields),
          todo(%{id: "t3", title: "Finished Todo", status: :finished, completed: true})
        )

      assert result["success"] == true
      assert result["data"]["id"] == "t3"
      assert result["data"]["title"] == "Finished Todo"
      assert result["data"]["status"] == "finished"
      assert Map.has_key?(result["data"], "completed")
    end

    test "returns error for non-existent combination (default behavior)" do
      result = R.run(composite("cancelled", ["id", "title"]), not_found(P.Todo))

      assert result["success"] == false
      assert is_list(result["errors"])
      assert first_error(result)["type"] in ["not_found", "NotFound"]
    end

    test "requires all get_by fields in getBy" do
      result =
        R.run(
          %{
            "action" => "get_todo_by_user_and_status",
            "getBy" => %{"userId" => "u1"},
            "fields" => ["id", "title"]
          },
          nil
        )

      assert result["success"] == false
      assert is_list(result["errors"])
    end

    test "requires user_id in getBy" do
      result =
        R.run(
          %{
            "action" => "get_todo_by_user_and_status",
            "getBy" => %{"status" => "pending"},
            "fields" => ["id", "title"]
          },
          nil
        )

      assert result["success"] == false
      assert is_list(result["errors"])
    end

    test "retrieves todo with relationship fields" do
      record = todo(%{status: :pending}) |> Map.put(:user, user(%{name: "Composite Test User"}))

      result =
        R.run(composite("pending", ["id", "title", %{"user" => ["id", "name", "email"]}]), record)

      assert result["success"] == true
      assert result["data"]["user"]["id"] == "u1"
      assert result["data"]["user"]["name"] == "Composite Test User"
    end

    test "retrieves todo with calculation fields" do
      record = todo(%{status: :pending, is_overdue: false, days_until_due: 1})

      result = R.run(composite("pending", ["id", "title", "isOverdue", "daysUntilDue"]), record)

      assert result["success"] == true
      assert Map.has_key?(result["data"], "isOverdue")
      assert Map.has_key?(result["data"], "daysUntilDue")
    end
  end

  describe "get actions - validation testing" do
    test "validates get_single_todo action with valid input" do
      assert {:ok, _request} =
               R.parse(
                 %{"action" => "get_single_todo", "input" => %{"filterCompleted" => true}},
                 validation_mode?: true
               )
    end

    test "validates get_single_todo action without input" do
      assert {:ok, _request} =
               R.parse(%{"action" => "get_single_todo"}, validation_mode?: true)
    end

    test "validates get_user_by_email action with valid getBy" do
      assert {:ok, _request} =
               R.parse(
                 %{"action" => "get_user_by_email", "getBy" => %{"email" => "test@example.com"}},
                 validation_mode?: true
               )
    end

    test "validates get_user_by_email fails without getBy" do
      assert {:error, reason} =
               R.parse(%{"action" => "get_user_by_email"}, validation_mode?: true)

      response = AshSurface.RuntimeParity.Rpc.Pipeline.error_response(reason)
      assert response["success"] == false
      assert is_list(response["errors"])
    end
  end

  describe "verifier - get options validation" do
    test "validates get_by fields exist on resource" do
      entry =
        Enum.find(R.entries(), &(&1.resource == P.User and &1.name == :get_user_by_email))

      assert entry != nil
      assert entry.get_by == [:email]

      for field <- entry.get_by do
        assert Ash.Resource.Info.attribute(P.User, field) != nil
      end
    end
  end

  describe "not_found_error? option" do
    test "get_by with not_found_error?: false returns null when not found" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email_nullable",
            "getBy" => %{"email" => "nonexistent_email@example.com"},
            "fields" => ["id", "name", "email"]
          },
          nil
        )

      assert result["success"] == true
      assert result["data"] == nil
    end

    test "get_by with not_found_error?: false returns record when found" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email_nullable",
            "getBy" => %{"email" => "notfound_test@example.com"},
            "fields" => ["id", "name", "email"]
          },
          user(%{email: "notfound_test@example.com"})
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["id"] == "u1"
      assert result["data"]["email"] == "notfound_test@example.com"
    end

    test "get_by with explicit not_found_error?: true returns error when not found" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email_error",
            "getBy" => %{"email" => "nonexistent_email@example.com"},
            "fields" => ["id", "name"]
          },
          not_found(P.User)
        )

      assert result["success"] == false
      assert is_list(result["errors"])
      assert first_error(result)["type"] in ["not_found", "NotFound"]
    end

    test "get_by with explicit not_found_error?: true returns record when found" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email_error",
            "getBy" => %{"email" => "notfound_test@example.com"},
            "fields" => ["id", "name", "email"]
          },
          user(%{email: "notfound_test@example.com"})
        )

      assert result["success"] == true
      assert is_map(result["data"])
      assert result["data"]["id"] == "u1"
    end

    test "get? with not_found_error?: false returns null when no records exist" do
      result = R.run(%{"action" => "get_single_todo_nullable", "fields" => ["id", "title"]}, nil)

      assert result["success"] == true
      assert result["data"] == nil
    end

    test "default behavior (no explicit not_found_error?) returns error when not found" do
      result =
        R.run(
          %{
            "action" => "get_user_by_email",
            "getBy" => %{"email" => "nonexistent_default@example.com"},
            "fields" => ["id", "name"]
          },
          not_found(P.User)
        )

      assert result["success"] == false
      assert is_list(result["errors"])
      assert first_error(result)["type"] in ["not_found", "NotFound"]
    end
  end
end
